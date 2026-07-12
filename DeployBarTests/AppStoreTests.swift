import Core
@testable import Features
import XCTest

private actor NotificationSpyRouter: NotificationRouting {
    private let granted: Bool
    private var authorizationRequests = 0
    private var delivered: [(title: String, body: String)] = []

    init(granted: Bool) {
        self.granted = granted
    }

    func requestAuthorization() async -> Bool {
        authorizationRequests += 1
        return granted
    }

    func notify(title: String, body: String) async {
        delivered.append((title: title, body: body))
    }

    func notificationCount() async -> Int {
        delivered.count
    }

    func authorizationRequestCount() async -> Int {
        authorizationRequests
    }
}

private final class FailingLaunchAtLoginController: LaunchAtLoginControlling, @unchecked Sendable {
    func setEnabled(_: Bool) throws {
        throw DeployBarError.networking("Unable to update launch at login.")
    }

    func status() -> Bool {
        false
    }
}

private actor TokenPruningMockVercelClient: VercelClient {
    private var projectResponseIndex = 0

    func validateToken() async throws -> AuthUser {
        AuthUser(id: "token-aware", username: "token-user", email: nil)
    }

    func listTeams(limit _: Int, until _: Int?) async throws -> [Team] {
        [Team(id: "team_1", slug: "example-team", name: "Example Team")]
    }

    func listProjects(teamId: String?, limit _: Int, until _: String?) async throws -> [Project] {
        let first = [
            Project(id: "proj_1", name: "Website", teamId: teamId, updatedAt: Date()),
            Project(id: "proj_2", name: "API", teamId: teamId, updatedAt: Date())
        ]
        let second = [
            Project(id: "proj_1", name: "Website", teamId: teamId, updatedAt: Date())
        ]

        defer { projectResponseIndex += 1 }
        return projectResponseIndex == 0 ? first : second
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

private actor MissingTokenRefreshMockVercelClient: VercelClient {
    func validateToken() async throws -> AuthUser {
        AuthUser(id: "u1", username: "missing-token-user", email: nil)
    }

    func listTeams(limit _: Int, until _: Int?) async throws -> [Team] {
        []
    }

    func listProjects(teamId: String?, limit _: Int, until _: String?) async throws -> [Project] {
        [
            Project(id: "proj_1", name: "Website", teamId: teamId, updatedAt: Date())
        ]
    }

    func latestProductionDeployment(projectId _: String, teamId _: String?) async throws -> DeploymentSnapshot? {
        throw DeployBarError.missingToken
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

private actor FlakyStartupAuthMockVercelClient: VercelClient {
    private var remainingValidationFailures: Int

    init(remainingValidationFailures: Int) {
        self.remainingValidationFailures = remainingValidationFailures
    }

    func validateToken() async throws -> AuthUser {
        if remainingValidationFailures > 0 {
            remainingValidationFailures -= 1
            throw DeployBarError.networking("Temporary network failure")
        }

        return AuthUser(id: "u1", username: "retry-user", email: nil)
    }

    func listTeams(limit _: Int, until _: Int?) async throws -> [Team] {
        []
    }

    func listProjects(teamId: String?, limit _: Int, until _: String?) async throws -> [Project] {
        [
            Project(id: "proj_1", name: "Website", teamId: teamId, updatedAt: Date())
        ]
    }

    func latestProductionDeployment(projectId: String, teamId _: String?) async throws -> DeploymentSnapshot? {
        DeploymentSnapshot(
            id: "dep_\(projectId)",
            projectId: projectId,
            stage: .ready,
            createdAt: Date(),
            url: URL(string: "https://example.vercel.app"),
            commitMessage: "Bootstrap retry deployment"
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

private actor TransitioningMockVercelClient: VercelClient {
    private var callCount = 0

    func validateToken() async throws -> AuthUser {
        AuthUser(id: "u1", username: "transition-user", email: nil)
    }

    func listTeams(limit _: Int, until _: Int?) async throws -> [Team] { [] }

    func listProjects(teamId: String?, limit _: Int, until _: String?) async throws -> [Project] {
        [Project(id: "proj_1", name: "Website", teamId: teamId, updatedAt: Date())]
    }

    func latestProductionDeployment(projectId: String, teamId _: String?) async throws -> DeploymentSnapshot? {
        defer { callCount += 1 }
        let isBaseline = callCount == 0
        return DeploymentSnapshot(
            id: isBaseline ? "dep_build" : "dep_ready",
            projectId: projectId,
            stage: isBaseline ? .building : .ready,
            createdAt: Date(),
            url: nil,
            commitMessage: nil
        )
    }

    func deploymentEvents(deploymentId _: String, limit _: Int, since _: Int?) async throws -> [DeploymentEvent] {
        []
    }
}

private actor StaticSnapshotMockVercelClient: VercelClient {
    private let fixedCreatedAt = Date()

    func validateToken() async throws -> AuthUser {
        AuthUser(id: "u1", username: "static-user", email: nil)
    }

    func listTeams(limit _: Int, until _: Int?) async throws -> [Team] { [] }

    func listProjects(teamId: String?, limit _: Int, until _: String?) async throws -> [Project] {
        [Project(id: "proj_1", name: "Website", teamId: teamId, updatedAt: Date())]
    }

    func latestProductionDeployment(projectId: String, teamId _: String?) async throws -> DeploymentSnapshot? {
        // Every call returns a value-identical snapshot (fixed createdAt) so consecutive
        // refresh cycles observe "no change" rather than differing only by timestamp.
        DeploymentSnapshot(
            id: "dep_static",
            projectId: projectId,
            stage: .ready,
            createdAt: fixedCreatedAt,
            url: nil,
            commitMessage: nil
        )
    }

    func deploymentEvents(deploymentId _: String, limit _: Int, since _: Int?) async throws -> [DeploymentEvent] {
        []
    }
}

@MainActor
final class AppStoreTests: XCTestCase {
    func testProjectSelectionIsCappedAtTwenty() async {
        let store = DeployBarAppStore(environment: .preview())

        for idx in 0 ..< 25 {
            store.toggleProjectSelection("p\(idx)")
        }

        XCTAssertEqual(store.selectedProjectIDs.count, 20)
        XCTAssertNotNil(store.tokenError)
    }

    func testSettingsToggleSendsTestNotificationOnEachEnableTransition() async {
        let spy = NotificationSpyRouter(granted: true)
        let store = makeStore(notificationRouter: spy)

        store.updateNotificationsEnabled(false)
        store.updateNotificationsEnabled(true)
        store.updateNotificationsEnabled(true)
        store.updateNotificationsEnabled(false)
        store.updateNotificationsEnabled(true)

        await waitForNotificationCount(2, spy: spy)

        let authRequests = await spy.authorizationRequestCount()
        let notificationCount = await spy.notificationCount()
        XCTAssertEqual(authRequests, 2)
        XCTAssertEqual(notificationCount, 2)
    }

    func testTokenSetupPersistsProjectsAndScope() async {
        let store = DeployBarAppStore(environment: .preview())

        store.updateNotificationsEnabled(false)
        store.updateSoundsEnabled(false)
        store.updateLaunchAtLogin(true)

        let didConnect = await store.updateToken("token_123")
        XCTAssertTrue(didConnect)
        XCTAssertNotNil(store.authUser)

        guard let firstProjectID = store.availableProjects.first?.id else {
            XCTFail("Expected preview projects to be loaded.")
            return
        }

        store.toggleProjectSelection(firstProjectID)
        store.updateWatchedProjects()

        XCTAssertEqual(store.phase, .running)
        XCTAssertEqual(store.settings.watchedProjects.count, 1)
        XCTAssertFalse(store.settings.notificationsEnabled)
        XCTAssertFalse(store.settings.soundsEnabled)
        XCTAssertTrue(store.settings.launchAtLogin)
    }

    func testReplacingTokenPrunesUnavailableProjectsAndReturnsToSetup() async {
        let spy = NotificationSpyRouter(granted: true)
        let store = makeStore(
            notificationRouter: spy,
            client: TokenPruningMockVercelClient()
        )

        let firstConnect = await store.updateToken("token_one")
        XCTAssertTrue(firstConnect)

        store.toggleProjectSelection("proj_2")
        store.updateWatchedProjects()
        XCTAssertEqual(store.phase, .running)
        XCTAssertEqual(store.selectedProjectIDs, ["proj_2"])

        let secondConnect = await store.updateToken("token_two")
        XCTAssertTrue(secondConnect)
        XCTAssertTrue(store.selectedProjectIDs.isEmpty)
        XCTAssertTrue(store.settings.watchedProjects.isEmpty)
        XCTAssertEqual(store.phase, .setupRequired)
        XCTAssertNotNil(store.tokenNotice)
    }

    func testLaunchAtLoginFailureRollsBackSetting() async {
        let notifications = NotificationSpyRouter(granted: true)
        let store = makeStore(
            notificationRouter: notifications,
            launchAtLogin: FailingLaunchAtLoginController()
        )

        XCTAssertFalse(store.settings.launchAtLogin)
        store.updateLaunchAtLogin(true)

        XCTAssertFalse(store.settings.launchAtLogin)
        XCTAssertEqual(store.monitorError, "Unable to update launch at login.")
    }

    func testLoadTeamsAndProjectsPrunesMissingWatchedProjects() async throws {
        let staleDate = Date().addingTimeInterval(-3600)
        let store = DeployBarAppStore(environment: .preview())
        store.settings = AppSettings(
            watchedProjects: [
                WatchedProject(id: "missing_project", name: "Missing", teamId: nil, teamSlug: nil)
            ],
            selectedScope: .personal,
            cachedProjectStatuses: [
                CachedProjectStatus(
                    project: WatchedProject(id: "missing_project", name: "Missing", teamId: nil, teamSlug: nil),
                    snapshot: nil,
                    lastUpdatedAt: staleDate
                )
            ],
            statusCacheUpdatedAt: staleDate
        )
        store.selectedScope = .personal

        try await store.loadTeamsAndProjects()

        XCTAssertTrue(store.selectedProjectIDs.isEmpty)
        XCTAssertTrue(store.settings.watchedProjects.isEmpty)
        XCTAssertTrue(store.settings.cachedProjectStatuses.isEmpty)
        XCTAssertNil(store.settings.statusCacheUpdatedAt)
    }

    func testPrepareInitialRefreshPresentationHydratesCachedStatuses() {
        let staleDate = Date().addingTimeInterval(-500)
        let watched = WatchedProject(id: "proj_1", name: "Website", teamId: nil, teamSlug: nil)
        let cachedSnapshot = DeploymentSnapshot(
            id: "dep_1",
            projectId: "proj_1",
            stage: .ready,
            createdAt: staleDate,
            url: URL(string: "https://example.vercel.app"),
            commitMessage: "Cached deploy"
        )

        let store = DeployBarAppStore(environment: .preview())
        store.settings = AppSettings(
            watchedProjects: [watched],
            selectedScope: .personal,
            cachedProjectStatuses: [
                CachedProjectStatus(project: watched, snapshot: cachedSnapshot, lastUpdatedAt: staleDate)
            ],
            statusCacheUpdatedAt: staleDate
        )

        store.prepareInitialRefreshPresentation()

        XCTAssertEqual(store.projectStatuses.count, 1)
        XCTAssertEqual(store.projectStatuses.first?.project.id, watched.id)
        XCTAssertTrue(store.isInitialRefreshInFlight)
        XCTAssertFalse(store.hasCompletedInitialRefresh)
        XCTAssertTrue(store.isShowingCachedStatuses)
        XCTAssertTrue(store.isCachedStatusStale)
        XCTAssertEqual(store.aggregateStatus, .healthy)
    }

    func testPersistStatusCacheStoresStatusesAndTimestamp() {
        let refreshedAt = Date()
        let watched = WatchedProject(id: "proj_1", name: "Website", teamId: nil, teamSlug: nil)
        let snapshot = DeploymentSnapshot(
            id: "dep_1",
            projectId: watched.id,
            stage: .ready,
            createdAt: refreshedAt,
            url: URL(string: "https://example.vercel.app"),
            commitMessage: "Live deploy"
        )
        let statuses = [
            ProjectStatus(project: watched, snapshot: snapshot, lastUpdatedAt: refreshedAt)
        ]

        let store = DeployBarAppStore(environment: .preview())
        store.persistStatusCache(from: statuses, refreshedAt: refreshedAt)

        XCTAssertEqual(store.settings.cachedProjectStatuses.count, 1)
        XCTAssertEqual(store.settings.cachedProjectStatuses.first?.project.id, watched.id)
        XCTAssertEqual(store.settings.statusCacheUpdatedAt, refreshedAt)
    }

    func testDisconnectAccountClearsLocalStateAndStores() async throws {
        let tokenStore = InMemoryTokenStore()
        try tokenStore.saveToken("token_live")

        let settingsStore = InMemorySettingsStore()
        try settingsStore.save(
            AppSettings(
                watchedProjects: [
                    WatchedProject(id: "proj_1", name: "Website", teamId: nil, teamSlug: nil)
                ],
                cachedProjectStatuses: [
                    CachedProjectStatus(
                        project: WatchedProject(id: "proj_1", name: "Website", teamId: nil, teamSlug: nil),
                        snapshot: nil,
                        lastUpdatedAt: Date()
                    )
                ],
                statusCacheUpdatedAt: Date()
            )
        )

        let eventStore = InMemoryEventStore()
        try await eventStore.persist(
            events: [
                DeploymentEvent(
                    id: "event_1",
                    deploymentId: "dep_1",
                    createdAt: Date(),
                    level: "info",
                    message: "Done"
                )
            ]
        )

        let store = makeStore(
            notificationRouter: NotificationSpyRouter(granted: true),
            tokenStore: tokenStore,
            settingsStore: settingsStore,
            eventStore: eventStore
        )
        store.authUser = AuthUser(id: "u1", username: "user", email: nil)
        store.teams = [Team(id: "team_1", slug: "team", name: "Team")]
        store.availableProjects = [Project(id: "proj_1", name: "Website", teamId: nil, updatedAt: nil)]
        store.selectedProjectIDs = ["proj_1"]
        store.settings = try settingsStore.load()

        await store.disconnectAccount()

        XCTAssertNil(try tokenStore.readToken())
        XCTAssertEqual(try settingsStore.load(), AppSettings())
        let remainingEvents = try await eventStore.load(deploymentId: "dep_1", limit: 10)
        XCTAssertTrue(remainingEvents.isEmpty)
        XCTAssertNil(store.authUser)
        XCTAssertTrue(store.selectedProjectIDs.isEmpty)
        XCTAssertEqual(store.phase, .setupRequired)
        XCTAssertNotNil(store.tokenNotice)
    }

    func testMonitoringMissingTokenRetriesBeforeSetupAndDoesNotClearStoredToken() async throws {
        let tokenStore = InMemoryTokenStore()
        let store = makeStore(
            notificationRouter: NotificationSpyRouter(granted: true),
            client: MissingTokenRefreshMockVercelClient(),
            tokenStore: tokenStore
        )

        let didConnect = await store.updateToken("token_live")
        XCTAssertTrue(didConnect)

        store.toggleProjectSelection("proj_1")
        store.updateWatchedProjects()
        XCTAssertEqual(store.phase, .running)
        store.monitorTask?.cancel()
        store.monitorTask = nil

        _ = await store.performRefreshCycle()
        XCTAssertEqual(store.phase, .running)
        XCTAssertTrue(store.isAuthRetrying)
        XCTAssertNil(store.tokenError)
        XCTAssertEqual(try tokenStore.readToken(), "token_live")

        _ = await store.performRefreshCycle()
        XCTAssertEqual(store.phase, .running)
        XCTAssertTrue(store.isAuthRetrying)

        _ = await store.performRefreshCycle()
        XCTAssertEqual(store.phase, .setupRequired)
        XCTAssertEqual(store.tokenError, "Saved token is unavailable. Reconnect your Vercel token.")
        XCTAssertEqual(try tokenStore.readToken(), "token_live")
    }

    func testPurgeFailureDoesNotBlockNotificationDelivery() async throws {
        let spy = NotificationSpyRouter(granted: true)
        let eventStore = InMemoryEventStore()
        let store = makeStore(
            notificationRouter: spy,
            client: TransitioningMockVercelClient(),
            eventStore: eventStore
        )

        let didConnect = await store.updateToken("token_live")
        XCTAssertTrue(didConnect)

        store.toggleProjectSelection("proj_1")
        store.updateWatchedProjects()
        XCTAssertEqual(store.phase, .running)
        store.monitorTask?.cancel()
        store.monitorTask = nil

        // Baseline observation: building. No transition yet.
        _ = await store.performRefreshCycle()

        await eventStore.setPurgeError(DeployBarError.networking("purge boom"))

        // building -> ready: a transition that must be delivered even though purge will throw.
        _ = await store.performRefreshCycle()

        await waitForNotificationCount(1, spy: spy)
        let notificationCount = await spy.notificationCount()
        XCTAssertEqual(notificationCount, 1)
    }

    func testConsecutiveRefreshCyclesThrottlePurgeToOncePerHour() async throws {
        let spy = NotificationSpyRouter(granted: true)
        let eventStore = InMemoryEventStore()
        let store = makeStore(
            notificationRouter: spy,
            eventStore: eventStore
        )

        let didConnect = await store.updateToken("token_live")
        XCTAssertTrue(didConnect)

        store.toggleProjectSelection("proj_1")
        store.updateWatchedProjects()
        XCTAssertEqual(store.phase, .running)
        store.monitorTask?.cancel()
        store.monitorTask = nil

        _ = await store.performRefreshCycle()
        _ = await store.performRefreshCycle()

        let purgeCallCount = await eventStore.purgeCallCount
        XCTAssertEqual(purgeCallCount, 1)
    }

    func testIdenticalRefreshCyclesWithinSixtySecondsWriteSettingsOnce() async throws {
        let spy = NotificationSpyRouter(granted: true)
        let settingsStore = InMemorySettingsStore()
        let store = makeStore(
            notificationRouter: spy,
            client: StaticSnapshotMockVercelClient(),
            settingsStore: settingsStore
        )

        let didConnect = await store.updateToken("token_live")
        XCTAssertTrue(didConnect)

        store.toggleProjectSelection("proj_1")
        store.updateWatchedProjects()
        XCTAssertEqual(store.phase, .running)
        store.monitorTask?.cancel()
        store.monitorTask = nil

        let saveCountBeforeRefreshes = settingsStore.saveCount

        _ = await store.performRefreshCycle()
        _ = await store.performRefreshCycle()

        XCTAssertEqual(settingsStore.saveCount - saveCountBeforeRefreshes, 1)
    }

    func testBootstrapRetriesTransientValidationBeforeConnecting() async throws {
        let tokenStore = InMemoryTokenStore()
        try tokenStore.saveToken("token_live")

        let settingsStore = InMemorySettingsStore()
        try settingsStore.save(
            AppSettings(
                watchedProjects: [
                    WatchedProject(id: "proj_1", name: "Website", teamId: nil, teamSlug: nil)
                ],
                selectedScope: .personal
            )
        )

        let originalRetryDelays = DeployBarAppStore.startupAuthRetryDelays
        DeployBarAppStore.startupAuthRetryDelays = [0.01]
        defer { DeployBarAppStore.startupAuthRetryDelays = originalRetryDelays }

        let store = makeStore(
            notificationRouter: NotificationSpyRouter(granted: true),
            client: FlakyStartupAuthMockVercelClient(remainingValidationFailures: 1),
            tokenStore: tokenStore,
            settingsStore: settingsStore
        )

        await store.bootstrap()

        XCTAssertNotNil(store.authUser)
        XCTAssertFalse(store.isAuthRetrying)
        XCTAssertEqual(store.phase, .running)
        XCTAssertEqual(store.authConnectionState, .connected)

        store.enterSetupRequiredState()
    }

    private func makeStore(
        notificationRouter: NotificationRouting,
        launchAtLogin: LaunchAtLoginControlling = InMemoryLaunchAtLoginController(),
        client: VercelClient = MockVercelClient(),
        tokenStore: SecureTokenStore = InMemoryTokenStore(),
        settingsStore: SettingsStore = InMemorySettingsStore(),
        eventStore: DeploymentEventStore = InMemoryEventStore()
    ) -> DeployBarAppStore {
        let sound = InMemorySoundPlayer()
        let engine = MonitoringEngine(client: client)

        let environment = DeployBarEnvironment(
            tokenStore: tokenStore,
            settingsStore: settingsStore,
            eventStore: eventStore,
            vercelClient: client,
            notificationRouter: notificationRouter,
            soundPlayer: sound,
            launchAtLogin: launchAtLogin,
            monitoringEngine: engine
        )

        return DeployBarAppStore(environment: environment)
    }

    private func waitForNotificationCount(_ expected: Int, spy: NotificationSpyRouter) async {
        let timeout = Date().addingTimeInterval(1.0)

        while Date() < timeout {
            if await spy.notificationCount() >= expected {
                return
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTFail("Timed out waiting for \(expected) notifications.")
    }
}
