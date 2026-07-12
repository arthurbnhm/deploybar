import Core
import Foundation

final class InMemoryTokenStore: SecureTokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?

    func saveToken(_ token: String) throws {
        lock.lock()
        self.token = token
        lock.unlock()
    }

    func readToken() throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return token
    }

    func clearToken() throws {
        lock.lock()
        token = nil
        lock.unlock()
    }
}

final class InMemorySettingsStore: SettingsStore, @unchecked Sendable {
    private let lock = NSLock()
    private var settings = AppSettings()

    func load() throws -> AppSettings {
        lock.lock()
        defer { lock.unlock() }
        return settings
    }

    func save(_ settings: AppSettings) throws {
        lock.lock()
        self.settings = settings
        lock.unlock()
    }

    func clear() throws {
        lock.lock()
        settings = AppSettings()
        lock.unlock()
    }
}

actor InMemoryEventStore: DeploymentEventStore {
    private var byDeployment: [String: [DeploymentEvent]] = [:]
    private var purgeError: Error?
    private(set) var purgeCallCount = 0

    func persist(events: [DeploymentEvent]) async throws {
        for event in events {
            byDeployment[event.deploymentId, default: []].append(event)
        }
    }

    func load(deploymentId: String, limit: Int) async throws -> [DeploymentEvent] {
        Array(byDeployment[deploymentId, default: []].suffix(limit))
    }

    func purge(olderThan cutoff: Date) async throws {
        purgeCallCount += 1
        if let purgeError {
            throw purgeError
        }
        byDeployment = byDeployment.mapValues {
            $0.filter { $0.createdAt >= cutoff }
        }
    }

    func clear() async throws {
        byDeployment.removeAll()
    }

    func setPurgeError(_ error: Error?) {
        purgeError = error
    }
}

actor InMemoryNotificationRouter: NotificationRouting {
    func requestAuthorization() async -> Bool { true }
    func notify(title _: String, body _: String, userInfo _: [String: String]) async {}
}

final class InMemorySoundPlayer: SoundPlayback, @unchecked Sendable {
    func playSuccess() {}
    func playFailure() {}
}

final class InMemoryLaunchAtLoginController: LaunchAtLoginControlling, @unchecked Sendable {
    private var enabled = false

    func setEnabled(_ enabled: Bool) throws {
        self.enabled = enabled
    }

    func status() -> Bool {
        enabled
    }
}

actor MockVercelClient: VercelClient {
    func validateToken() async throws -> AuthUser {
        AuthUser(id: "local", username: "preview-user", email: nil)
    }

    func listTeams(limit _: Int, until _: Int?) async throws -> [Team] {
        [Team(id: "team_1", slug: "example-team", name: "Example Team")]
    }

    func listProjects(teamId: String?, limit _: Int, until _: String?) async throws -> [Project] {
        [
            Project(id: "proj_1", name: "Website", teamId: teamId, updatedAt: Date()),
            Project(id: "proj_2", name: "API", teamId: teamId, updatedAt: Date())
        ]
    }

    func latestProductionDeployment(projectId: String, teamId _: String?) async throws -> DeploymentSnapshot? {
        DeploymentSnapshot(
            id: "dep_\(projectId)",
            projectId: projectId,
            stage: .ready,
            createdAt: Date(),
            url: URL(string: "https://example.vercel.app"),
            commitMessage: "Preview deployment"
        )
    }

    func deploymentEvents(deploymentId: String, limit _: Int, since _: Int?) async throws -> [DeploymentEvent] {
        [
            DeploymentEvent(
                id: "\(deploymentId)-1",
                deploymentId: deploymentId,
                createdAt: Date(),
                level: "info",
                message: "Build completed"
            )
        ]
    }
}

public extension DeployBarEnvironment {
    static func preview() -> DeployBarEnvironment {
        let tokenStore = InMemoryTokenStore()
        let settingsStore = InMemorySettingsStore()
        let eventStore = InMemoryEventStore()
        let client = MockVercelClient()
        let launch = InMemoryLaunchAtLoginController()
        let notification = InMemoryNotificationRouter()
        let sound = InMemorySoundPlayer()

        return DeployBarEnvironment(
            tokenStore: tokenStore,
            settingsStore: settingsStore,
            eventStore: eventStore,
            vercelClient: client,
            notificationRouter: notification,
            soundPlayer: sound,
            launchAtLogin: launch,
            monitoringEngine: MonitoringEngine(client: client)
        )
    }
}
