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

    public func clearLocalData() {
        Task {
            monitorTask?.cancel()
            monitorTask = nil
            phase = .onboarding

            do {
                try env.settingsStore.clear()
                try await env.eventStore.clear()
                await env.monitoringEngine.resetState()

                settings = AppSettings()
                selectedScope = settings.selectedScope
                teams = []
                availableProjects = []
                selectedProjectIDs = []
                projectStatuses = []
                aggregateStatus = .unknown
                monitorCadence = .idle
                lastRefreshAt = nil
                tokenError = nil
                monitorError = nil
                closeLogs()

                if authUser != nil {
                    try? await loadTeamsAndProjects()
                }
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
}
