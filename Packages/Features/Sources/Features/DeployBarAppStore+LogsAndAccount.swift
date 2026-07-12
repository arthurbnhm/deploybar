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

    /// Cancels an in-flight (`queued`/`building`) deployment, then forces a refresh so the
    /// popover reflects the new state. A 403 (token lacks write scope) is surfaced as a
    /// user-facing message without clearing the stored token or dropping the auth session —
    /// only `.unauthorized`/`.invalidToken` do that (see `shouldClearStoredToken`).
    public func cancelDeployment(for status: ProjectStatus) async {
        guard let snapshot = status.snapshot, snapshot.stage == .queued || snapshot.stage == .building else {
            return
        }

        cancelingDeploymentID = snapshot.id
        defer { cancelingDeploymentID = nil }

        do {
            try await env.vercelClient.cancelDeployment(deploymentId: snapshot.id, teamId: status.project.teamId)
            monitorError = nil
        } catch {
            monitorError = error.localizedDescription
        }

        manualRefresh()
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
