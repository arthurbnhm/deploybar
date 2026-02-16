import Core
import Foundation

@MainActor
extension DeployBarAppStore {
    public func openLogsTapped(for status: ProjectStatus) {
        Task {
            await openLogs(for: status)
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
}
