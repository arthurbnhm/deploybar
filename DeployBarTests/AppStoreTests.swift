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

    func testCompleteOnboardingOnlyPersistsProjectsAndScope() async {
        let store = DeployBarAppStore(environment: .preview())

        store.updateNotificationsEnabled(false)
        store.updateSoundsEnabled(false)
        store.updateLaunchAtLogin(true)

        store.tokenInput = "token_123"
        await store.connectToken()
        XCTAssertNotNil(store.authUser)

        guard let firstProjectID = store.availableProjects.first?.id else {
            XCTFail("Expected preview projects to be loaded.")
            return
        }

        store.toggleProjectSelection(firstProjectID)
        await store.completeOnboarding()

        XCTAssertEqual(store.phase, .running)
        XCTAssertEqual(store.settings.watchedProjects.count, 1)
        XCTAssertFalse(store.settings.notificationsEnabled)
        XCTAssertFalse(store.settings.soundsEnabled)
        XCTAssertTrue(store.settings.launchAtLogin)
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
        let store = DeployBarAppStore(environment: .preview())
        store.settings = AppSettings(
            watchedProjects: [
                WatchedProject(id: "missing_project", name: "Missing", teamId: nil, teamSlug: nil)
            ],
            selectedScope: .personal
        )
        store.selectedScope = .personal

        try await store.loadTeamsAndProjects()

        XCTAssertTrue(store.selectedProjectIDs.isEmpty)
        XCTAssertTrue(store.settings.watchedProjects.isEmpty)
    }

    private func makeStore(
        notificationRouter: NotificationRouting,
        launchAtLogin: LaunchAtLoginControlling = InMemoryLaunchAtLoginController()
    ) -> DeployBarAppStore {
        let tokenStore = InMemoryTokenStore()
        let settingsStore = InMemorySettingsStore()
        let eventStore = InMemoryEventStore()
        let client = MockVercelClient()
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

    private func waitForCondition(
        timeout: TimeInterval = 1.0,
        condition: () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTFail("Timed out waiting for condition.")
    }
}
