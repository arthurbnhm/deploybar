import Core
import Foundation

@MainActor
extension DeployBarAppStore {
    public func refreshProjectsForScopeTapped(persistSelectionChanges: Bool = false) {
        let session = sessionGeneration
        Task {
            let refreshed = await refreshProjectsForScope()
            if refreshed, isCurrentSession(session), persistSelectionChanges {
                updateWatchedProjects()
            }
        }
    }

    @discardableResult
    public func updateToken(_ rawToken: String) async -> Bool {
        guard !isDisconnecting, !isValidatingToken else { return false }
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
        let previousAuthConnectionState = authConnectionState

        let session = invalidateSession()

        isValidatingToken = true
        defer { if session == sessionGeneration { isValidatingToken = false } }

        do {
            try env.tokenStore.saveToken(trimmed)
            let user = try await env.vercelClient.validateToken()
            guard isCurrentSession(session) else { return false }
            await env.monitoringEngine.resetState()
            guard isCurrentSession(session) else { return false }
            authUser = user
            authConnectionState = .connected
            try await loadTeamsAndProjects(preferredSelectedIDs: previousSelectedProjectIDs)
            guard isCurrentSession(session) else { return false }
            if previousAuthUser?.id != user.id {
                await drainLogWrites()
                guard isCurrentSession(session) else { return false }
                try await env.eventStore.clear()
                guard isCurrentSession(session) else { return false }
            }
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
            guard isCurrentSession(session) else { return false }
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
            authConnectionState = previousAuthConnectionState
            tokenNotice = previousTokenNotice
            tokenError = userFacingAuthError(error)

            if previousPhase == .running {
                startMonitoringLoop(immediate: true)
            }
            return false
        }
    }

    @discardableResult
    public func refreshProjectsForScope() async -> Bool {
        guard !isDisconnecting, !isValidatingToken else { return false }
        let session = sessionGeneration
        let scope = selectedScope
        guard authUser != nil else {
            tokenError = "Connect your Vercel token first."
            return false
        }

        do {
            let projects = try await env.vercelClient.listProjects(teamId: scope.teamId, limit: 100, until: nil)
            guard isCurrentSession(session), selectedScope == scope else { return false }
            availableProjects = ProjectSelectionService.sortedProjects(projects)
            selectedProjectIDs = ProjectSelectionService.visibleSelectedIDs(
                selectedIDs: selectedProjectIDs,
                availableProjects: availableProjects
            )
            tokenError = nil
            tokenNotice = nil
            return true
        } catch {
            guard isCurrentSession(session), selectedScope == scope else { return false }
            tokenError = "Unable to load projects for this scope. Try Personal scope or a token with team access."
            tokenNotice = nil
            return false
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
        guard !isDisconnecting, !isValidatingToken else { return }
        settings.watchedProjects = ProjectSelectionService.watchedProjects(
            availableProjects: availableProjects,
            selectedIDs: selectedProjectIDs,
            selectedScope: selectedScope,
            teams: teams
        )
        settings.selectedScope = selectedScope
        _ = pruneCachedStatusesToWatchedProjects()

        persistSettings()
        tokenError = nil
        tokenNotice = nil
        activateMonitoringIfReady()
    }

    func loadTeamsAndProjects(preferredSelectedIDs: Set<String>? = nil) async throws {
        let session = sessionGeneration
        let fetchedTeams = try await env.vercelClient.listTeams(limit: 100, until: nil)
        guard isCurrentSession(session) else { throw CancellationError() }
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
            guard isCurrentSession(session) else { throw CancellationError() }
            if case .team = selectedScope {
                selectedScope = .personal
                projects = try await env.vercelClient.listProjects(teamId: nil, limit: 100, until: nil)
            } else {
                throw error
            }
        }

        guard isCurrentSession(session) else { throw CancellationError() }
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

        let settingsChanged = settings.watchedProjects != normalizedWatchedProjects || settings.selectedScope != selectedScope

        if settingsChanged {
            settings.watchedProjects = normalizedWatchedProjects
            settings.selectedScope = selectedScope
        }

        let cacheChanged = pruneCachedStatusesToWatchedProjects()

        if settingsChanged || cacheChanged {
            persistSettings()
        }
    }

    @discardableResult
    func pruneCachedStatusesToWatchedProjects() -> Bool {
        let watchedProjectIDs = Set(settings.watchedProjects.map(\.id))
        let filteredCachedStatuses = settings.cachedProjectStatuses.filter { cached in
            watchedProjectIDs.contains(cached.project.id)
        }
        let didChangeCachedStatuses = filteredCachedStatuses != settings.cachedProjectStatuses
        settings.cachedProjectStatuses = filteredCachedStatuses

        var didChangeCacheTimestamp = false
        if settings.cachedProjectStatuses.isEmpty {
            didChangeCacheTimestamp = settings.statusCacheUpdatedAt != nil
            settings.statusCacheUpdatedAt = nil
        }

        let filteredProjectStatuses = projectStatuses.filter { status in
            watchedProjectIDs.contains(status.project.id)
        }
        let didChangeInMemoryStatuses = filteredProjectStatuses != projectStatuses
        projectStatuses = filteredProjectStatuses

        return didChangeCachedStatuses || didChangeCacheTimestamp || didChangeInMemoryStatuses
    }
}
