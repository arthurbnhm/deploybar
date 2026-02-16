import Core
import Foundation
import Security

@MainActor
extension DeployBarAppStore {
    func bootstrap() async {
#if !arch(arm64)
        phase = .unsupported("DeployBar V1 supports Apple Silicon only.")
        return
#endif

        let startupContext: AuthBootstrapService.StartupContext
        do {
            startupContext = try AuthBootstrapService.loadStartupContext(
                settingsStore: env.settingsStore,
                tokenStore: env.tokenStore
            )
        } catch {
            enterSetupRequiredState()
            tokenError = userFacingAuthError(error)
            return
        }

        settings = startupContext.settings
        let launchAtLoginStatus = env.launchAtLogin.status()
        if settings.launchAtLogin != launchAtLoginStatus {
            settings.launchAtLogin = launchAtLoginStatus
            persistSettings()
        }
        selectedScope = settings.selectedScope

        guard !startupContext.storedToken.isEmpty else {
            enterSetupRequiredState()
            return
        }

        do {
            let user = try await env.vercelClient.validateToken()
            authUser = user
            try await loadTeamsAndProjects()
            tokenError = nil
            activateMonitoringIfReady()
        } catch {
            if AuthBootstrapService.shouldRequireTokenReconnect(for: error) {
                try? env.tokenStore.clearToken()
                authUser = nil
                enterSetupRequiredState()
                tokenError = "This Vercel token is invalid or no longer authorized."
                return
            }

            monitorError = "Unable to validate saved token at startup. DeployBar will retry in the background."
            tokenError = nil

            if !settings.watchedProjects.isEmpty {
                prepareInitialRefreshPresentation()
                phase = .running
                startMonitoringLoop(immediate: true)
            } else {
                enterSetupRequiredState()
            }
        }
    }

    func activateMonitoringIfReady() {
        guard authUser != nil, !settings.watchedProjects.isEmpty else {
            enterSetupRequiredState()
            return
        }

        prepareInitialRefreshPresentation()
        phase = .running
        startMonitoringLoop(immediate: true)
    }

    func enterSetupRequiredState() {
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
                return "Paste a Vercel access token to continue."
            case .invalidToken, .unauthorized:
                return "This Vercel token is invalid or no longer authorized."
            default:
                return deployError.localizedDescription
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSOSStatusErrorDomain {
            switch nsError.code {
            case Int(errSecAuthFailed), Int(errSecInteractionNotAllowed), Int(errSecUserCanceled):
                return "Keychain access was denied. Reopen DeployBar and choose \"Always Allow\"."
            default:
                break
            }
        }

        let description = nsError.localizedDescription
        if description.localizedCaseInsensitiveContains("operation not permitted") {
            return "Action not permitted for this scope. Try Personal scope or a token with team permissions."
        }
        return description
    }
}
