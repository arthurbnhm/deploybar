import Core
import Foundation

@MainActor
extension DeployBarAppStore {
    public func refreshProjectsForScopeTapped(persistSelectionChanges: Bool = false) {
        Task {
            await refreshProjectsForScope()
            if persistSelectionChanges {
                updateWatchedProjects()
            }
        }
    }

    @discardableResult
    public func updateToken(_ rawToken: String) async -> Bool {
        let previousTokenNotice = tokenNotice
        tokenError = nil
        tokenNotice = nil
        let trimmed = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            tokenError = "Paste a Vercel access token to continue."
            return false
        }

        let previousToken = (try? env.tokenStore.readToken())?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let previousAuthUser = authUser
        let previousTeams = teams
        let previousProjects = availableProjects
        let previousSelectedProjectIDs = selectedProjectIDs
        let previousSettings = settings
        let previousScope = selectedScope
        let previousPhase = phase
        let previousMonitorError = monitorError

        monitorTask?.cancel()
        monitorTask = nil

        isValidatingToken = true
        defer { isValidatingToken = false }

        do {
            try env.tokenStore.saveToken(trimmed)
            let user = try await env.vercelClient.validateToken()
            authUser = user
            try await loadTeamsAndProjects(preferredSelectedIDs: previousSelectedProjectIDs)
            tokenError = nil

            let prunedCount = previousSelectedProjectIDs.subtracting(selectedProjectIDs).count
            if prunedCount > 0 {
                tokenNotice = "Token updated. Removed \(prunedCount) project\(prunedCount == 1 ? "" : "s") you no longer have access to."
            } else if previousAuthUser?.id != user.id {
                tokenNotice = "Connected as @\(user.username)."
            } else {
                tokenNotice = "Token updated."
            }

            monitorError = nil
            activateMonitoringIfReady()
            return true
        } catch {
            if !previousToken.isEmpty {
                try? env.tokenStore.saveToken(previousToken)
            } else {
                try? env.tokenStore.clearToken()
            }

            authUser = previousAuthUser
            teams = previousTeams
            availableProjects = previousProjects
            selectedProjectIDs = previousSelectedProjectIDs
            settings = previousSettings
            selectedScope = previousScope
            phase = previousPhase
            monitorError = previousMonitorError
            tokenNotice = previousTokenNotice
            tokenError = userFacingAuthError(error)

            if previousPhase == .running {
                startMonitoringLoop(immediate: true)
            }
            return false
        }
    }

    public func refreshProjectsForScope() async {
        guard authUser != nil else {
            tokenError = "Connect your Vercel token first."
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
            tokenNotice = nil
        } catch {
            tokenError = "Unable to load projects for this scope. Try Personal scope or a token with team access."
            tokenNotice = nil
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
            tokenNotice = nil
        case .failure(.limitReached):
            tokenError = "You can watch up to 20 projects in V1."
            tokenNotice = nil
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
        tokenError = nil
        tokenNotice = nil
        activateMonitoringIfReady()
    }

    func loadTeamsAndProjects(preferredSelectedIDs: Set<String>? = nil) async throws {
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
        let candidateSelectedIDs = preferredSelectedIDs ?? Set(settings.watchedProjects.map(\.id))
        let normalizedSelectedIDs = ProjectSelectionService.visibleSelectedIDs(
            selectedIDs: candidateSelectedIDs,
            availableProjects: availableProjects
        )
        selectedProjectIDs = normalizedSelectedIDs

        let normalizedWatchedProjects = ProjectSelectionService.watchedProjects(
            availableProjects: availableProjects,
            selectedIDs: normalizedSelectedIDs,
            selectedScope: selectedScope,
            teams: teams
        )

        if settings.watchedProjects != normalizedWatchedProjects || settings.selectedScope != selectedScope {
            settings.watchedProjects = normalizedWatchedProjects
            settings.selectedScope = selectedScope
            persistSettings()
        }
    }
}
