import Core
import Foundation
import Persistence
import VercelAPI

public struct DeployBarEnvironment {
    public let tokenStore: SecureTokenStore
    public let settingsStore: SettingsStore
    public let eventStore: DeploymentEventStore
    public let vercelClient: VercelClient
    public let notificationRouter: NotificationRouting
    public let soundPlayer: SoundPlayback
    public let launchAtLogin: LaunchAtLoginControlling
    public let monitoringEngine: MonitoringEngine

    public init(
        tokenStore: SecureTokenStore,
        settingsStore: SettingsStore,
        eventStore: DeploymentEventStore,
        vercelClient: VercelClient,
        notificationRouter: NotificationRouting,
        soundPlayer: SoundPlayback,
        launchAtLogin: LaunchAtLoginControlling,
        monitoringEngine: MonitoringEngine
    ) {
        self.tokenStore = tokenStore
        self.settingsStore = settingsStore
        self.eventStore = eventStore
        self.vercelClient = vercelClient
        self.notificationRouter = notificationRouter
        self.soundPlayer = soundPlayer
        self.launchAtLogin = launchAtLogin
        self.monitoringEngine = monitoringEngine
    }

    public static func live() throws -> DeployBarEnvironment {
        let tokenStore = KeychainTokenStore()
        let settingsStore = try JSONSettingsStore()
        let eventStore = try SQLiteDeploymentEventStore()

        let vercelClient = VercelAPIClient(tokenProvider: {
            try tokenStore.readToken()
        })

        let notificationRouter = MacNotificationRouter()
        let soundPlayer = SystemSoundPlayer()
        let launchAtLogin = LaunchAtLoginManager()
        let monitoringEngine = MonitoringEngine(client: vercelClient)

        return DeployBarEnvironment(
            tokenStore: tokenStore,
            settingsStore: settingsStore,
            eventStore: eventStore,
            vercelClient: vercelClient,
            notificationRouter: notificationRouter,
            soundPlayer: soundPlayer,
            launchAtLogin: launchAtLogin,
            monitoringEngine: monitoringEngine
        )
    }
}
