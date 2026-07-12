import Foundation

public protocol VercelClient: Sendable {
    func validateToken() async throws -> AuthUser
    func listTeams(limit: Int, until: Int?) async throws -> [Team]
    func listProjects(teamId: String?, limit: Int, until: String?) async throws -> [Project]
    func latestProductionDeployment(projectId: String, teamId: String?) async throws -> DeploymentSnapshot?
    func deploymentEvents(deploymentId: String, limit: Int, since: Int?) async throws -> [DeploymentEvent]
    func cancelDeployment(deploymentId: String, teamId: String?) async throws
}

public protocol SecureTokenStore: Sendable {
    func saveToken(_ token: String) throws
    func readToken() throws -> String?
    func clearToken() throws
}

public protocol SettingsStore: Sendable {
    func load() throws -> AppSettings
    func save(_ settings: AppSettings) throws
    func clear() throws
}

public protocol DeploymentEventStore: Sendable {
    func persist(events: [DeploymentEvent]) async throws
    func load(deploymentId: String, limit: Int) async throws -> [DeploymentEvent]
    func purge(olderThan cutoff: Date) async throws
    func clear() async throws
}

public protocol NotificationRouting: Sendable {
    func requestAuthorization() async -> Bool
    func notify(title: String, body: String) async
}

public protocol SoundPlayback: Sendable {
    func playSuccess()
    func playFailure()
}

public protocol LaunchAtLoginControlling: Sendable {
    func setEnabled(_ enabled: Bool) throws
    func status() -> Bool
}
