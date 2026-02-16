import Core
import Foundation

@MainActor
extension DeployBarAppStore {
    public func connectTokenTapped(onFinish: (() -> Void)? = nil) {
        Task {
            await connectToken()
            onFinish?()
        }
    }

    public func refreshProjectsForScopeTapped(persistSelectionChanges: Bool = false) {
        Task {
            await refreshProjectsForScope()
            if persistSelectionChanges {
                updateWatchedProjects()
            }
        }
    }

    public func completeOnboardingTapped(onFinish: (() -> Void)? = nil) {
        Task {
            await completeOnboarding()
            onFinish?()
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
            let projects = try await env.vercelClient.listProjects(teamId: selectedScope.teamId, limit: 100, until: nil)
            availableProjects = ProjectSelectionService.sortedProjects(projects)
            selectedProjectIDs = ProjectSelectionService.visibleSelectedIDs(
                selectedIDs: selectedProjectIDs,
                availableProjects: availableProjects
            )
            tokenError = nil
        } catch {
            tokenError = "Unable to load projects for this scope. Try Personal scope or a token with team access."
        }
    }

    public func toggleProjectSelection(_ projectID: String) {
        switch ProjectSelectionService.toggledSelection(
            current: selectedProjectIDs,
            projectID: projectID,
            limit: 20
        ) {
        case let .success(updatedSelection):
            selectedProjectIDs = updatedSelection
            tokenError = nil
        case .failure(.limitReached):
            tokenError = "You can watch up to 20 projects in V1."
        }
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

        settings.watchedProjects = ProjectSelectionService.watchedProjects(
            availableProjects: availableProjects,
            selectedIDs: selectedProjectIDs,
            selectedScope: selectedScope,
            teams: teams
        )
        settings.selectedScope = selectedScope

        do {
            try env.settingsStore.save(settings)
            tokenError = nil
            phase = .running
            startMonitoringLoop(immediate: true)
        } catch {
            tokenError = userFacingOnboardingError(error)
        }
    }

    public func updateWatchedProjects() {
        settings.watchedProjects = ProjectSelectionService.watchedProjects(
            availableProjects: availableProjects,
            selectedIDs: selectedProjectIDs,
            selectedScope: selectedScope,
            teams: teams
        )
        settings.selectedScope = selectedScope

        persistSettings()

        if phase == .running {
            startMonitoringLoop(immediate: true)
        }
    }

    func loadTeamsAndProjects() async throws {
        let fetchedTeams = try await env.vercelClient.listTeams(limit: 100, until: nil)
        teams = fetchedTeams.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

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

        availableProjects = ProjectSelectionService.sortedProjects(projects)
        selectedProjectIDs = ProjectSelectionService.visibleSelectedIDs(
            selectedIDs: Set(settings.watchedProjects.map(\.id)),
            availableProjects: availableProjects
        )
    }
}
