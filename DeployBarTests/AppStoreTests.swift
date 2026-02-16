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

    private func makeStore(notificationRouter: NotificationRouting) -> DeployBarAppStore {
        let tokenStore = InMemoryTokenStore()
        let settingsStore = InMemorySettingsStore()
        let eventStore = InMemoryEventStore()
        let client = MockVercelClient()
        let launch = InMemoryLaunchAtLoginController()
        let sound = InMemorySoundPlayer()
        let engine = MonitoringEngine(client: client)

        let environment = DeployBarEnvironment(
            tokenStore: tokenStore,
            settingsStore: settingsStore,
            eventStore: eventStore,
            vercelClient: client,
            notificationRouter: notificationRouter,
            soundPlayer: sound,
            launchAtLogin: launch,
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
