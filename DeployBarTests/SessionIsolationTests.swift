import Core
import Foundation
@testable import Features
import XCTest

private actor SuspendedVercelClient: VercelClient {
    enum Failure: Error { case timedOut, rejected }
    var delayedLogCall = 1
    var logCalls = 0
    var logContinuations: [Int: CheckedContinuation<[DeploymentEvent], Error>] = [:]
    var authContinuation: CheckedContinuation<AuthUser, Error>?
    var projectContinuation: CheckedContinuation<[Project], Error>?
    var suspendAuth = false
    var suspendProjects = false

    func configure(logCall: Int = 1, auth: Bool = false, projects: Bool = false) {
        delayedLogCall = logCall
        suspendAuth = auth
        suspendProjects = projects
    }

    func validateToken() async throws -> AuthUser {
        if suspendAuth {
            return try await withCheckedThrowingContinuation { authContinuation = $0 }
        }
        return AuthUser(id: "audit-user", username: "audit", email: nil)
    }
    func listTeams(limit _: Int, until _: Int?) async throws -> [Team] { [] }
    func listProjects(teamId _: String?, limit _: Int, until _: String?) async throws -> [Project] {
        if suspendProjects {
            return try await withCheckedThrowingContinuation { projectContinuation = $0 }
        }
        return []
    }
    func latestProductionDeployment(projectId _: String, teamId _: String?) async throws -> DeploymentSnapshot? { nil }
    func cancelDeployment(deploymentId _: String, teamId _: String?) async throws {}
    func deploymentEvents(deploymentId _: String, limit _: Int, since _: Int?) async throws -> [DeploymentEvent] {
        logCalls += 1
        let call = logCalls
        if call >= delayedLogCall {
            return try await withCheckedThrowingContinuation { logContinuations[call] = $0 }
        }
        return []
    }

    func waitForLog(_ call: Int) async throws {
        for _ in 0..<1_000 {
            if logContinuations[call] != nil { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        throw Failure.timedOut
    }
    func waitForAuth() async throws {
        for _ in 0..<1_000 {
            if authContinuation != nil { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        throw Failure.timedOut
    }
    func waitForProjects() async throws {
        for _ in 0..<1_000 {
            if projectContinuation != nil { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        throw Failure.timedOut
    }
    func finishLog(_ call: Int, deploymentID: String = "audit-deploy") {
        logContinuations.removeValue(forKey: call)?.resume(returning: [
            DeploymentEvent(id: "event-\(call)", deploymentId: deploymentID, createdAt: Date(), level: "info", message: "Synthetic private log")
        ])
    }
    func finishAuth(rejected: Bool) {
        if rejected {
            authContinuation?.resume(throwing: Failure.rejected)
        } else {
            authContinuation?.resume(returning: AuthUser(id: "new-user", username: "new", email: nil))
        }
        authContinuation = nil
    }
    func finishProjects() {
        projectContinuation?.resume(returning: [Project(id: "old-project", name: "Old", teamId: nil, updatedAt: nil)])
        projectContinuation = nil
    }
}

private actor SuspendedEventStore: DeploymentEventStore {
    var pending: CheckedContinuation<Void, Never>?
    var events: [DeploymentEvent] = []
    var clearCount = 0

    func persist(events: [DeploymentEvent]) async throws {
        await withCheckedContinuation { pending = $0 }
        self.events.append(contentsOf: events)
    }
    func load(deploymentId: String, limit: Int) async throws -> [DeploymentEvent] {
        Array(events.filter { $0.deploymentId == deploymentId }.prefix(limit))
    }
    func purge(olderThan _: Date) async throws {}
    func clear() async throws { clearCount += 1; events = [] }
    func waitForWrite() async throws {
        for _ in 0..<1_000 {
            if pending != nil { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        throw SuspendedVercelClient.Failure.timedOut
    }
    func finishWrite() { pending?.resume(); pending = nil }
}

@MainActor
final class SessionIsolationTests: XCTestCase {
    private func makeStore(client: SuspendedVercelClient, eventStore: DeploymentEventStore? = nil) -> DeployBarAppStore {
        let base = DeployBarEnvironment.preview()
        return DeployBarAppStore(environment: DeployBarEnvironment(
            tokenStore: base.tokenStore, settingsStore: base.settingsStore, eventStore: eventStore ?? base.eventStore,
            vercelClient: client, notificationRouter: base.notificationRouter, soundPlayer: base.soundPlayer,
            launchAtLogin: base.launchAtLogin, monitoringEngine: MonitoringEngine(client: client)
        ))
    }

    private func status(id: String = "audit-deploy", stage: DeploymentStage = .ready) -> ProjectStatus {
        ProjectStatus(
            project: WatchedProject(id: "audit-project", name: "Audit", teamId: nil, teamSlug: nil),
            snapshot: DeploymentSnapshot(id: id, projectId: "audit-project", stage: stage, createdAt: Date(), url: nil, commitMessage: nil),
            lastUpdatedAt: Date()
        )
    }

    private func assertDisconnected(_ store: DeployBarAppStore) async throws {
        XCTAssertNil(store.authUser)
        XCTAssertNil(store.selectedLogsProject)
        XCTAssertFalse(store.isLoadingLogs)
        XCTAssertFalse(store.isTailingLogs)
        XCTAssertTrue(store.logEvents.isEmpty)
        XCTAssertNil(try store.env.tokenStore.readToken())
        XCTAssertEqual(try store.env.settingsStore.load(), AppSettings())
        let cached = try await store.env.eventStore.load(deploymentId: "audit-deploy", limit: 300)
        XCTAssertTrue(cached.isEmpty)
    }

    func testDelayedInitialLogsCannotRepopulateAfterDisconnect() async throws {
        let client = SuspendedVercelClient()
        let store = makeStore(client: client)
        let opening = Task { await store.openLogs(for: status()) }
        try await client.waitForLog(1)
        await store.disconnectAccount()
        await client.finishLog(1)
        await opening.value
        try await assertDisconnected(store)
    }

    func testClosingLogsRejectsAnOutstandingResponse() async throws {
        let client = SuspendedVercelClient()
        let store = makeStore(client: client)
        let opening = Task { await store.openLogs(for: status(stage: .building)) }
        try await client.waitForLog(1)
        store.closeLogs()
        await client.finishLog(1)
        await opening.value
        XCTAssertTrue(store.logEvents.isEmpty)
        XCTAssertFalse(store.isLoadingLogs)
        XCTAssertFalse(store.isTailingLogs)
    }

    func testSwitchingLogsKeepsTheNewestSelection() async throws {
        let client = SuspendedVercelClient()
        let store = makeStore(client: client)
        let first = Task { await store.openLogs(for: status()) }
        try await client.waitForLog(1)
        let second = Task { await store.openLogs(for: status(id: "new-deploy")) }
        try await client.waitForLog(2)
        await client.finishLog(2, deploymentID: "new-deploy")
        await second.value
        await client.finishLog(1)
        await first.value
        XCTAssertEqual(store.selectedLogsDeployment?.id, "new-deploy")
        XCTAssertEqual(store.logEvents.map(\.deploymentId), ["new-deploy"])
    }

    func testDelayedTailCannotRepopulateAfterDisconnect() async throws {
        let client = SuspendedVercelClient()
        await client.configure(logCall: 2)
        let store = makeStore(client: client)
        store.logsTailInterval = 0.001
        await store.openLogs(for: status(stage: .building))
        try await client.waitForLog(2)
        let tail = store.logsTailTask
        await store.disconnectAccount()
        await client.finishLog(2)
        await tail?.value
        try await assertDisconnected(store)
    }

    func testDelayedCatchUpCannotRepopulateAfterDisconnect() async throws {
        let client = SuspendedVercelClient()
        await client.configure(logCall: 3)
        let store = makeStore(client: client)
        store.logsTailInterval = 0.001
        store.projectStatuses = [status(stage: .ready)]
        await store.openLogs(for: status(stage: .building))
        try await client.waitForLog(3)
        let tail = store.logsTailTask
        await store.disconnectAccount()
        await client.finishLog(3)
        await tail?.value
        try await assertDisconnected(store)
    }

    func testDelayedTokenSuccessCannotReconnectAfterDisconnect() async throws {
        try await checkDelayedToken(rejected: false)
    }

    func testDelayedTokenFailureCannotRestorePreviousTokenAfterDisconnect() async throws {
        try await checkDelayedToken(rejected: true)
    }

    private func checkDelayedToken(rejected: Bool) async throws {
        let client = SuspendedVercelClient()
        await client.configure(auth: true)
        let store = makeStore(client: client)
        try store.env.tokenStore.saveToken("synthetic-old-token")
        let updating = Task { await store.updateToken("synthetic-new-token") }
        try await client.waitForAuth()
        await store.disconnectAccount()
        await client.finishAuth(rejected: rejected)
        let connected = await updating.value
        XCTAssertFalse(connected)
        XCTAssertFalse(store.isValidatingToken)
        try await assertDisconnected(store)
    }

    func testDelayedProjectsCannotRestoreSettingsAfterDisconnect() async throws {
        let client = SuspendedVercelClient()
        await client.configure(projects: true)
        let store = makeStore(client: client)
        store.authUser = AuthUser(id: "old-user", username: "old", email: nil)
        let loading = Task { await store.refreshProjectsForScope() }
        try await client.waitForProjects()
        await store.disconnectAccount()
        await client.finishProjects()
        let refreshed = await loading.value
        XCTAssertFalse(refreshed)
        XCTAssertTrue(store.availableProjects.isEmpty)
        try await assertDisconnected(store)
    }

    func testDelayedBootstrapCannotReconnectAfterDisconnect() async throws {
        let client = SuspendedVercelClient()
        await client.configure(auth: true)
        let store = makeStore(client: client)
        try store.env.tokenStore.saveToken("synthetic-token")
        let starting = Task { await store.bootstrap() }
        try await client.waitForAuth()
        await store.disconnectAccount()
        await client.finishAuth(rejected: false)
        await starting.value
        try await assertDisconnected(store)
    }

    func testDisconnectWaitsForAnAdmittedDatabaseWriteBeforeClearing() async throws {
        let client = SuspendedVercelClient()
        let database = SuspendedEventStore()
        let store = makeStore(client: client, eventStore: database)
        let opening = Task { await store.openLogs(for: status()) }
        try await client.waitForLog(1)
        await client.finishLog(1)
        try await database.waitForWrite()
        let disconnecting = Task { await store.disconnectAccount() }
        for _ in 0..<1_000 {
            if store.isDisconnecting { break }
            try await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertTrue(store.isDisconnecting)
        let clearsBeforeWrite = await database.clearCount
        XCTAssertEqual(clearsBeforeWrite, 0)
        await database.finishWrite()
        await opening.value
        await disconnecting.value
        try await assertDisconnected(store)
    }

    func testTokenReplacementInvalidatesOutstandingLogs() async throws {
        let client = SuspendedVercelClient()
        let store = makeStore(client: client)
        store.authUser = AuthUser(id: "old-user", username: "old", email: nil)
        let opening = Task { await store.openLogs(for: status()) }
        try await client.waitForLog(1)
        let connected = await store.updateToken("synthetic-replacement-token")
        XCTAssertTrue(connected)
        await client.finishLog(1)
        await opening.value
        XCTAssertEqual(store.authUser?.id, "audit-user")
        XCTAssertTrue(store.logEvents.isEmpty)
        let cached = try await store.env.eventStore.load(deploymentId: "audit-deploy", limit: 300)
        XCTAssertTrue(cached.isEmpty)
        await store.disconnectAccount()
    }

    func testStartingTailEndsTheInitialLoadingIndicator() async throws {
        let client = SuspendedVercelClient()
        await client.configure(logCall: 2)
        let store = makeStore(client: client)
        await store.openLogs(for: status(stage: .building))
        XCTAssertFalse(store.isLoadingLogs)
        XCTAssertTrue(store.isTailingLogs)
        store.closeLogs()
    }

    func testStartupFailureHasNoDemoStoreAndCanRetry() async throws {
        var attempts = 0
        let startup = DeployBarStartup {
            attempts += 1
            if attempts == 1 { throw SuspendedVercelClient.Failure.rejected }
            return DeployBarEnvironment.preview()
        }
        XCTAssertNil(startup.store)
        XCTAssertNotNil(startup.errorMessage)
        startup.retry()
        XCTAssertNotNil(startup.store)
        XCTAssertNil(startup.errorMessage)
        XCTAssertEqual(attempts, 2)
        await startup.store?.disconnectAccount()
    }
}
