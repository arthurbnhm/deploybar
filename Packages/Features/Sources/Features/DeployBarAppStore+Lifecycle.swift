import Core
import Foundation
import Security

@MainActor
extension DeployBarAppStore {
    private enum StartupAuthResolution {
        case connected(AuthUser)
        case setupRequired(message: String, clearStoredToken: Bool)
        case retrying(message: String)
    }

    static var startupAuthRetryDelays: [TimeInterval] = [1, 2, 4]
    static let transientAuthFailureThreshold = 3

    func bootstrap() async {
#if !arch(arm64)
        phase = .unsupported("DeployBar V1 supports Apple Silicon only.")
        authConnectionState = .setupRequired(reason: "DeployBar V1 supports Apple Silicon only.")
        return
#endif

        let loadedSettings: AppSettings
        do {
            loadedSettings = try env.settingsStore.load()
        } catch {
            let message = userFacingAuthError(error)
            authUser = nil
            enterSetupRequiredState(authReason: message)
            tokenError = message
            return
        }

        settings = loadedSettings
        let launchAtLoginStatus = env.launchAtLogin.status()
        if settings.launchAtLogin != launchAtLoginStatus {
            settings.launchAtLogin = launchAtLoginStatus
            persistSettings()
        }
        selectedScope = settings.selectedScope

        let authResolution = await resolveStartupAuth()
        switch authResolution {
        case let .connected(user):
            consecutiveTransientAuthFailures = 0
            authUser = user
            authConnectionState = .connected
            tokenError = nil
            monitorError = nil

            do {
                try await loadTeamsAndProjects()
            } catch {
                if let reconnectMessage = reconnectMessageForHardAuthFailure(error) {
                    await handleHardAuthFailure(
                        message: reconnectMessage,
                        clearStoredToken: shouldClearStoredToken(for: error)
                    )
                    return
                }

                monitorError = "Unable to load teams and projects. DeployBar will retry in the background."
            }

            activateMonitoringIfReady()
        case let .setupRequired(message, shouldClearStoredToken):
            await handleHardAuthFailure(message: message, clearStoredToken: shouldClearStoredToken)
        case let .retrying(message):
            authUser = nil
            authConnectionState = .retrying(reason: message)
            tokenError = nil
            monitorError = message

            if !settings.watchedProjects.isEmpty {
                prepareInitialRefreshPresentation()
                phase = .running
                startMonitoringLoop(immediate: true)
            } else {
                phase = .loading
            }
        }
    }

    func activateMonitoringIfReady() {
        guard authUser != nil else {
            enterSetupRequiredState(authReason: Self.defaultTokenPrompt)
            return
        }

        guard !settings.watchedProjects.isEmpty else {
            enterSetupRequiredState()
            return
        }

        authConnectionState = .connected
        prepareInitialRefreshPresentation()
        phase = .running
        startMonitoringLoop(immediate: true)
    }

    func enterSetupRequiredState(authReason: String? = nil) {
        phase = .setupRequired
        monitorTask?.cancel()
        monitorTask = nil
        projectStatuses = []
        aggregateStatus = .unknown
        monitorCadence = .idle
        lastRefreshAt = nil
        isInitialRefreshInFlight = false
        hasCompletedInitialRefresh = false
        isShowingCachedStatuses = false
        cachedStatusAge = nil
        consecutiveTransientAuthFailures = 0

        if let authReason {
            authConnectionState = .setupRequired(reason: authReason)
        } else if authUser != nil {
            authConnectionState = .connected
        } else if case .retrying = authConnectionState {
            authConnectionState = .setupRequired(reason: nil)
        } else {
            authConnectionState = .setupRequired(reason: nil)
        }
    }

    func prepareInitialRefreshPresentation() {
        isInitialRefreshInFlight = true
        hasCompletedInitialRefresh = false

        let watchedProjectIDs = Set(settings.watchedProjects.map(\.id))
        let hydratedStatuses = settings.cachedProjectStatuses
            .filter { watchedProjectIDs.contains($0.project.id) }
            .map { cached in
                ProjectStatus(
                    project: cached.project,
                    snapshot: cached.snapshot,
                    lastUpdatedAt: cached.lastUpdatedAt
                )
            }

        projectStatuses = sortedProjectStatuses(hydratedStatuses)
        aggregateStatus = aggregateStatus(for: projectStatuses)
        isShowingCachedStatuses = !projectStatuses.isEmpty

        if let cachedAt = settings.statusCacheUpdatedAt {
            cachedStatusAge = max(0, Date().timeIntervalSince(cachedAt))
        } else {
            cachedStatusAge = nil
        }
    }

    func sortedProjectStatuses(_ statuses: [ProjectStatus]) -> [ProjectStatus] {
        statuses.sorted { lhs, rhs in
            switch (lhs.snapshot?.createdAt, rhs.snapshot?.createdAt) {
            case let (leftDate?, rightDate?):
                if leftDate != rightDate {
                    return leftDate > rightDate
                }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                break
            }

            return lhs.project.name.localizedCaseInsensitiveCompare(rhs.project.name) == .orderedAscending
        }
    }

    func aggregateStatus(for statuses: [ProjectStatus]) -> AggregateStatus {
        guard !statuses.isEmpty else {
            return .unknown
        }

        if statuses.contains(where: { $0.snapshot?.stage == .failed }) {
            return .failed
        }

        if statuses.contains(where: { stage in
            let snapshotStage = stage.snapshot?.stage
            return snapshotStage == .building || snapshotStage == .queued
        }) {
            return .building
        }

        if statuses.allSatisfy({ $0.snapshot?.stage == .ready }) {
            return .healthy
        }

        return .unknown
    }

    func triggerNotificationTestIfJustEnabled(wasEnabled: Bool, isEnabled: Bool) {
        guard isEnabled, !wasEnabled else {
            return
        }

        Task {
            await self.sendTestNotificationIfAuthorized()
        }
    }

    func sendTestNotificationIfAuthorized() async {
        let granted = await env.notificationRouter.requestAuthorization()
        guard granted else { return }

        let uniqueMarker = String(UUID().uuidString.prefix(8))
        await env.notificationRouter.notify(
            title: Self.testNotificationTitle,
            body: "\(Self.testNotificationBodyPrefix) Test ref: \(uniqueMarker)."
        )
    }

    func persistSettings() {
        do {
            try env.settingsStore.save(settings)
        } catch {
            monitorError = error.localizedDescription
        }
    }

    func userFacingAuthError(_ error: Error) -> String {
        if let deployError = error as? DeployBarError {
            switch deployError {
            case .missingToken:
                return Self.defaultTokenPrompt
            case .invalidToken, .unauthorized:
                return "This Vercel token is invalid or no longer authorized."
            default:
                break
            }
        }

        if isTransientKeychainAccessError(error) {
            return "Keychain is temporarily unavailable. DeployBar will retry automatically."
        }

        let nsError = error as NSError
        let description = nsError.localizedDescription
        if description.localizedCaseInsensitiveContains("operation not permitted") {
            return "Action not permitted for this scope. Try Personal scope or a token with team permissions."
        }
        return description
    }

    private func resolveStartupAuth() async -> StartupAuthResolution {
        for attempt in 0 ... Self.startupAuthRetryDelays.count {
            do {
                let storedToken = try env.tokenStore.readToken()?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                guard !storedToken.isEmpty else {
                    return .setupRequired(message: Self.defaultTokenPrompt, clearStoredToken: false)
                }

                let user = try await env.vercelClient.validateToken()
                return .connected(user)
            } catch {
                if let reconnectMessage = reconnectMessageForHardAuthFailure(error) {
                    return .setupRequired(
                        message: reconnectMessage,
                        clearStoredToken: shouldClearStoredToken(for: error)
                    )
                }

                let retryReason = startupRetryReason(for: error)
                authConnectionState = .retrying(reason: retryReason)

                if attempt < Self.startupAuthRetryDelays.count {
                    let delay = Self.startupAuthRetryDelays[attempt]
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                return .retrying(message: "Unable to validate saved token right now. DeployBar will keep retrying in the background.")
            }
        }

        return .retrying(message: "Unable to validate saved token right now. DeployBar will keep retrying in the background.")
    }

    func reconnectMessageForHardAuthFailure(_ error: Error) -> String? {
        guard let deployError = error as? DeployBarError else {
            return nil
        }

        switch deployError {
        case .unauthorized, .invalidToken:
            return "This Vercel token is invalid or no longer authorized."
        case .missingToken:
            return Self.defaultTokenPrompt
        case .forbiddenAction, .rateLimited, .networking, .persistence, .unsupportedArchitecture:
            return nil
        }
    }

    func shouldClearStoredToken(for error: Error) -> Bool {
        guard let deployError = error as? DeployBarError else {
            return false
        }

        switch deployError {
        case .unauthorized, .invalidToken:
            return true
        case .missingToken, .forbiddenAction, .rateLimited, .networking, .persistence, .unsupportedArchitecture:
            return false
        }
    }

    func isTransientKeychainAccessError(_ error: Error) -> Bool {
        if let status = keychainOSStatus(from: error) {
            return status == errSecInteractionNotAllowed || status == errSecAuthFailed || status == errSecUserCanceled
        }

        if let deployError = error as? DeployBarError,
           case let .persistence(message) = deployError
        {
            let lowered = message.lowercased()
            return lowered.contains("keychain") || lowered.contains("unable to read token")
        }

        return false
    }

    func keychainOSStatus(from error: Error) -> OSStatus? {
        let nsError = error as NSError
        if nsError.domain == NSOSStatusErrorDomain {
            return OSStatus(nsError.code)
        }

        guard let deployError = error as? DeployBarError,
              case let .persistence(message) = deployError
        else {
            return nil
        }

        guard let start = message.lastIndex(of: "("),
              let end = message.lastIndex(of: ")"),
              start < end
        else {
            return nil
        }

        let rawCode = message[message.index(after: start) ..< end]
        guard let code = Int(rawCode) else {
            return nil
        }

        return OSStatus(code)
    }

    func startupRetryReason(for error: Error) -> String {
        if isTransientKeychainAccessError(error) {
            return "Reconnecting to your saved token in Keychain..."
        }

        if let deployError = error as? DeployBarError {
            switch deployError {
            case .networking:
                return "Unable to reach Vercel. Retrying saved token..."
            case .rateLimited:
                return "Rate limited while checking token. Retrying shortly..."
            default:
                break
            }
        }

        return "Retrying saved token validation..."
    }

    func monitoringRetryReason(for error: Error) -> String {
        if isTransientKeychainAccessError(error) {
            return "Reconnecting to your saved token in Keychain..."
        }

        if let deployError = error as? DeployBarError {
            switch deployError {
            case .missingToken:
                return "Reconnecting to your saved token..."
            default:
                break
            }
        }

        return "Retrying Vercel authentication in the background..."
    }

    func registerTransientAuthFailure(reason: String, escalateMessage: String) -> TimeInterval {
        consecutiveTransientAuthFailures += 1
        authConnectionState = .retrying(reason: reason)
        monitorCadence = .idle
        tokenError = nil

        if consecutiveTransientAuthFailures >= Self.transientAuthFailureThreshold {
            authUser = nil
            enterSetupRequiredState(authReason: escalateMessage)
            tokenError = escalateMessage
            monitorError = escalateMessage
            return settings.pollingProfile.idleInterval
        }

        monitorError = reason
        return 2
    }

    func clearTransientAuthFailuresIfNeeded() {
        if consecutiveTransientAuthFailures > 0 {
            consecutiveTransientAuthFailures = 0
        }
    }

    func handleHardAuthFailure(message: String, clearStoredToken: Bool) async {
        if clearStoredToken {
            try? env.tokenStore.clearToken()
        }

        await env.monitoringEngine.resetState()
        authUser = nil
        tokenNotice = nil
        tokenError = message
        monitorError = message
        enterSetupRequiredState(authReason: message)
    }
}
