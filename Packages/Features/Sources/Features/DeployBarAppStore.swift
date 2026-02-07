import Core
import Foundation
import SwiftUI

public enum AppPhase: Equatable {
    case loading
    case onboarding
    case running
    case unsupported(String)
}

@MainActor
public final class DeployBarAppStore: ObservableObject {
    @Published public private(set) var phase: AppPhase = .loading
    @Published public private(set) var authUser: AuthUser?
    @Published public var tokenInput: String = ""
    @Published public var tokenError: String?
    @Published public var isValidatingToken: Bool = false

    @Published public private(set) var teams: [Team] = []
    @Published public var selectedScope: TeamScope = .personal
    @Published public private(set) var availableProjects: [Project] = []
    @Published public var selectedProjectIDs: Set<String> = []
    @Published public var onboardingSoundsEnabled: Bool = true
    @Published public var onboardingLaunchAtLogin: Bool = false
    @Published public var onboardingNotificationsEnabled: Bool = true

    @Published public private(set) var settings: AppSettings = AppSettings()
    @Published public private(set) var projectStatuses: [ProjectStatus] = []
    @Published public private(set) var aggregateStatus: AggregateStatus = .unknown
    @Published public private(set) var monitorCadence: PollingCadence = .idle
    @Published public private(set) var monitorError: String?
    @Published public private(set) var lastRefreshAt: Date?

    @Published public private(set) var showingLogs: Bool = false
    @Published public private(set) var selectedLogsProject: WatchedProject?
    @Published public private(set) var selectedLogsDeployment: DeploymentSnapshot?
    @Published public private(set) var logEvents: [DeploymentEvent] = []
    @Published public private(set) var isLoadingLogs: Bool = false

    @Published public private(set) var menuIsOpen: Bool = false

    private let env: DeployBarEnvironment
    private var monitorTask: Task<Void, Never>?
    private var hasStarted = false

    public init(environment: DeployBarEnvironment) {
        self.env = environment
    }

    deinit {
        monitorTask?.cancel()
    }

    public func start() {
        guard !hasStarted else {
            return
        }
        hasStarted = true
        Task {
            await bootstrap()
        }
    }

    public func setMenuOpen(_ open: Bool) {
        let wasOpen = menuIsOpen
        menuIsOpen = open

        guard phase == .running else {
            return
        }

        // Opening the menu should force a near-real-time refresh path.
        if open, !wasOpen {
            startMonitoringLoop(immediate: true)
        }
    }

    public func connectToken() async {
        tokenError = nil
        let trimmed = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            tokenError = "Paste a Vercel access token to continue."
            return
        }

        isValidatingToken = true
        defer { isValidatingToken = false }

        do {
            try env.tokenStore.saveToken(trimmed)
            let user = try await env.vercelClient.validateToken()
            authUser = user
            try await loadTeamsAndProjects()
            tokenError = nil
            phase = .onboarding
        } catch {
            tokenError = userFacingOnboardingError(error)
            try? env.tokenStore.clearToken()
        }
    }

    public func refreshProjectsForScope() async {
        guard authUser != nil else {
            return
        }

        do {
            let teamId = selectedScope.teamId
            let projects = try await env.vercelClient.listProjects(teamId: teamId, limit: 100, until: nil)
            availableProjects = projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            tokenError = nil

            let visibleIDs = Set(availableProjects.map(\.id))
            selectedProjectIDs = selectedProjectIDs.intersection(visibleIDs)
        } catch {
            tokenError = "Unable to load projects for this scope. Try Personal scope or a token with team access."
        }
    }

    public func toggleProjectSelection(_ projectID: String) {
        if selectedProjectIDs.contains(projectID) {
            selectedProjectIDs.remove(projectID)
            return
        }

        guard selectedProjectIDs.count < 20 else {
            tokenError = "You can watch up to 20 projects in V1."
            return
        }

        selectedProjectIDs.insert(projectID)
        tokenError = nil
    }

    public func completeOnboarding() async {
        guard authUser != nil else {
            tokenError = "Connect your token first."
            return
        }

        guard !selectedProjectIDs.isEmpty else {
            tokenError = "Select at least one project to watch."
            return
        }

        let selectedProjects = availableProjects.filter { selectedProjectIDs.contains($0.id) }
        let teamSlug = slugForSelectedScope()

        let watched = selectedProjects.map {
            WatchedProject(
                id: $0.id,
                name: $0.name,
                teamId: selectedScope.teamId,
                teamSlug: teamSlug
            )
        }

        settings.watchedProjects = watched
        settings.selectedScope = selectedScope
        settings.notificationsEnabled = onboardingNotificationsEnabled
        settings.soundsEnabled = onboardingSoundsEnabled
        settings.launchAtLogin = onboardingLaunchAtLogin

        do {
            try env.settingsStore.save(settings)
            do {
                try env.launchAtLogin.setEnabled(onboardingLaunchAtLogin)
            } catch {
                monitorError = "Launch at login could not be updated right now. You can retry in Settings."
            }

            if onboardingNotificationsEnabled {
                _ = await env.notificationRouter.requestAuthorization()
            }

            tokenError = nil
            phase = .running
            startMonitoringLoop(immediate: true)
        } catch {
            tokenError = userFacingOnboardingError(error)
        }
    }

    public func updateWatchedProjects() {
        let selectedProjects = availableProjects.filter { selectedProjectIDs.contains($0.id) }
        let teamSlug = slugForSelectedScope()

        settings.watchedProjects = selectedProjects.map {
            WatchedProject(
                id: $0.id,
                name: $0.name,
                teamId: selectedScope.teamId,
                teamSlug: teamSlug
            )
        }

        settings.selectedScope = selectedScope
        persistSettings()

        if phase == .running {
            startMonitoringLoop(immediate: true)
        }
    }

    public func manualRefresh() {
        guard phase == .running else {
            return
        }
        startMonitoringLoop(immediate: true)
    }

    public func updatePollingProfile(_ profile: PollingProfile) {
        settings.pollingProfile = profile
        persistSettings()
        if phase == .running {
            startMonitoringLoop(immediate: true)
        }
    }

    public func updateNotificationsEnabled(_ enabled: Bool) {
        settings.notificationsEnabled = enabled
        persistSettings()

        if enabled {
            Task {
                _ = await env.notificationRouter.requestAuthorization()
            }
        }
    }

    public func updateSoundsEnabled(_ enabled: Bool) {
        settings.soundsEnabled = enabled
        persistSettings()
    }

    public func updateLaunchAtLogin(_ enabled: Bool) {
        settings.launchAtLogin = enabled
        persistSettings()

        do {
            try env.launchAtLogin.setEnabled(enabled)
        } catch {
            monitorError = error.localizedDescription
        }
    }

    public func openLogs(for status: ProjectStatus) async {
        guard let snapshot = status.snapshot else {
            monitorError = "No deployment available yet for this project."
            return
        }

        selectedLogsProject = status.project
        selectedLogsDeployment = snapshot
        isLoadingLogs = true
        showingLogs = true

        defer {
            isLoadingLogs = false
        }

        do {
            let freshEvents = try await env.vercelClient.deploymentEvents(
                deploymentId: snapshot.id,
                limit: 250,
                since: nil
            )

            if !freshEvents.isEmpty {
                try await env.eventStore.persist(events: freshEvents)
            }

            logEvents = try await env.eventStore.load(deploymentId: snapshot.id, limit: 300)
        } catch {
            monitorError = error.localizedDescription
            if let cached = try? await env.eventStore.load(deploymentId: snapshot.id, limit: 300) {
                logEvents = cached
            } else {
                logEvents = []
            }
        }
    }

    public func closeLogs() {
        showingLogs = false
        selectedLogsProject = nil
        selectedLogsDeployment = nil
        logEvents = []
    }

    public func clearLocalData() {
        Task {
            monitorTask?.cancel()
            do {
                try env.settingsStore.clear()
                try await env.eventStore.clear()
                settings = AppSettings()
                projectStatuses = []
                aggregateStatus = .unknown
                monitorCadence = .idle
            } catch {
                monitorError = error.localizedDescription
            }
        }
    }

    public func signOut() {
        monitorTask?.cancel()

        Task {
            do {
                try env.tokenStore.clearToken()
                try env.settingsStore.clear()
                try await env.eventStore.clear()
                await env.monitoringEngine.resetState()

                authUser = nil
                settings = AppSettings()
                availableProjects = []
                selectedProjectIDs = []
                projectStatuses = []
                aggregateStatus = .unknown
                monitorCadence = .idle
                tokenInput = ""
                closeLogs()
                phase = .onboarding
            } catch {
                monitorError = error.localizedDescription
            }
        }
    }

    public var canFinishOnboarding: Bool {
        authUser != nil && !selectedProjectIDs.isEmpty
    }

    private func bootstrap() async {
#if !arch(arm64)
        phase = .unsupported("DeployBar V1 supports Apple Silicon only.")
        return
#endif

        do {
            settings = try env.settingsStore.load()
            onboardingSoundsEnabled = settings.soundsEnabled
            onboardingLaunchAtLogin = settings.launchAtLogin
            onboardingNotificationsEnabled = settings.notificationsEnabled
            selectedScope = settings.selectedScope

            if let token = try env.tokenStore.readToken(), !token.isEmpty {
                let user = try await env.vercelClient.validateToken()
                authUser = user
                try await loadTeamsAndProjects()
                tokenError = nil

                if !settings.watchedProjects.isEmpty {
                    phase = .running
                    startMonitoringLoop(immediate: true)
                    return
                }
            }

            phase = .onboarding
        } catch {
            phase = .onboarding
            tokenError = userFacingOnboardingError(error)
        }
    }

    private func loadTeamsAndProjects() async throws {
        let fetchedTeams = try await env.vercelClient.listTeams(limit: 100, until: nil)
        teams = fetchedTeams.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        if case let .team(id, slug) = selectedScope,
           !fetchedTeams.contains(where: { $0.id == id && $0.slug == slug })
        {
            selectedScope = .personal
        }

        let projects: [Project]
        do {
            projects = try await env.vercelClient.listProjects(teamId: selectedScope.teamId, limit: 100, until: nil)
        } catch {
            if case .team = selectedScope {
                selectedScope = .personal
                projects = try await env.vercelClient.listProjects(teamId: nil, limit: 100, until: nil)
            } else {
                throw error
            }
        }

        availableProjects = projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let watchedIDs = Set(settings.watchedProjects.map(\.id))
        selectedProjectIDs = watchedIDs.intersection(Set(availableProjects.map(\.id)))
    }

    private func startMonitoringLoop(immediate: Bool) {
        monitorTask?.cancel()

        guard !settings.watchedProjects.isEmpty else {
            projectStatuses = []
            aggregateStatus = .unknown
            monitorCadence = .idle
            return
        }

        monitorTask = Task { [weak self] in
            guard let self else { return }

            var nextDelay: TimeInterval = immediate ? 0 : self.settings.pollingProfile.activeInterval

            while !Task.isCancelled {
                if nextDelay > 0 {
                    let nanos = UInt64(nextDelay * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: nanos)
                }

                if Task.isCancelled {
                    break
                }

                nextDelay = await self.performRefreshCycle()
            }
        }
    }

    private func performRefreshCycle() async -> TimeInterval {
        do {
            let update = try await env.monitoringEngine.refresh(
                projects: settings.watchedProjects,
                profile: settings.pollingProfile,
                menuIsOpen: menuIsOpen
            )

            projectStatuses = update.statuses.sorted { lhs, rhs in
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
            aggregateStatus = update.aggregateStatus
            monitorCadence = update.cadence
            monitorError = nil
            lastRefreshAt = Date()

            try await env.eventStore.purge(olderThan: Date().addingTimeInterval(-7 * 24 * 60 * 60))
            await handleTransitions(update.transitions)

            return update.nextDelay
        } catch let error as DeployBarError {
            switch error {
            case let .rateLimited(resetAt):
                monitorError = error.localizedDescription
                monitorCadence = .idle
                return max(3, resetAt.timeIntervalSinceNow)
            case .unauthorized:
                monitorError = "Token revoked or unauthorized. Reconnect your Vercel token."
                monitorCadence = .idle
                phase = .onboarding
                return settings.pollingProfile.idleInterval
            default:
                monitorError = error.localizedDescription
                return settings.pollingProfile.activeInterval
            }
        } catch is CancellationError {
            // Expected when a refresh cycle is superseded by a new task.
            return settings.pollingProfile.activeInterval
        } catch {
            monitorError = error.localizedDescription
            return settings.pollingProfile.activeInterval
        }
    }

    private func handleTransitions(_ transitions: [DeploymentTransition]) async {
        guard !transitions.isEmpty else {
            return
        }

        for transition in transitions {
            switch transition.current.stage {
            case .ready:
                if settings.notificationsEnabled {
                    await env.notificationRouter.notify(
                        title: "DeployBar: Success",
                        body: "\(transition.project.name) deployed successfully."
                    )
                }
                if settings.soundsEnabled {
                    env.soundPlayer.playSuccess()
                }

            case .failed:
                if settings.notificationsEnabled {
                    await env.notificationRouter.notify(
                        title: "DeployBar: Failed",
                        body: "\(transition.project.name) deployment failed."
                    )
                }
                if settings.soundsEnabled {
                    env.soundPlayer.playFailure()
                }

            default:
                continue
            }
        }
    }

    private func slugForSelectedScope() -> String? {
        switch selectedScope {
        case .personal:
            return nil
        case let .team(id, _):
            return teams.first(where: { $0.id == id })?.slug
        }
    }

    private func persistSettings() {
        do {
            try env.settingsStore.save(settings)
        } catch {
            monitorError = error.localizedDescription
        }
    }

    private func userFacingOnboardingError(_ error: Error) -> String {
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

        let description = (error as NSError).localizedDescription
        if description.localizedCaseInsensitiveContains("operation not permitted") {
            return "Action not permitted for this scope. Try Personal scope or a token with team permissions."
        }
        return description
    }
}
