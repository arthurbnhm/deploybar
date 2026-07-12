import Core
import Foundation

@MainActor
extension DeployBarAppStore {
    public func openLogs(for status: ProjectStatus) async {
        guard let snapshot = status.snapshot else {
            monitorError = "No deployment available yet for this project."
            return
        }

        selectedLogsProject = status.project
        selectedLogsDeployment = snapshot
        isLoadingLogs = true

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

    /// Resolves a project by id against the live `projectStatuses` (not the
    /// notified deployment id) and opens its current logs. A notification's
    /// deployment may no longer be the project's latest by the time it's
    /// clicked, so this intentionally shows the current state rather than
    /// pinning to the stale notified deployment.
    @discardableResult
    public func openLogsForProject(id: String) async -> Bool {
        guard let status = projectStatuses.first(where: { $0.project.id == id }) else {
            return false
        }

        await openLogs(for: status)
        return true
    }

    public func closeLogs() {
        selectedLogsProject = nil
        selectedLogsDeployment = nil
        logEvents = []
    }

    public func disconnectAccount() async {
        monitorTask?.cancel()
        monitorTask = nil

        var cleanupErrors: [String] = []
        do {
            try env.tokenStore.clearToken()
        } catch {
            cleanupErrors.append(error.localizedDescription)
        }

        do {
            try env.settingsStore.clear()
        } catch {
            cleanupErrors.append(error.localizedDescription)
        }

        do {
            try await env.eventStore.clear()
        } catch {
            cleanupErrors.append(error.localizedDescription)
        }

        await env.monitoringEngine.resetState()

        authUser = nil
        teams = []
        availableProjects = []
        selectedProjectIDs = []
        selectedScope = .personal
        settings = AppSettings()
        tokenError = nil
        tokenNotice = cleanupErrors.isEmpty
            ? "Disconnected from Vercel and cleared local DeployBar data."
            : "Disconnected from Vercel, but some local data could not be cleared."
        monitorError = cleanupErrors.first
        closeLogs()
        enterSetupRequiredState(authReason: Self.defaultTokenPrompt)
    }
}
