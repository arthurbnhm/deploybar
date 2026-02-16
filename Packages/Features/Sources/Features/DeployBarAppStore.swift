import Core
import Foundation
import SwiftUI

public enum AppPhase: Equatable {
    case loading
    case setupRequired
    case running
    case unsupported(String)
}

@MainActor
public final class DeployBarAppStore: ObservableObject {
    static let testNotificationTitle = "DeployBar Notifications Enabled"
    static let testNotificationBodyPrefix = "You will now receive deployment status updates."
    static let tokenHelpURL = URL(string: "https://vercel.com/account/settings/tokens")!

    @Published public internal(set) var phase: AppPhase = .loading
    @Published public internal(set) var authUser: AuthUser?
    @Published public var tokenError: String?
    @Published public var tokenNotice: String?
    @Published public var isValidatingToken: Bool = false

    @Published public internal(set) var teams: [Team] = []
    @Published public var selectedScope: TeamScope = .personal
    @Published public internal(set) var availableProjects: [Project] = []
    @Published public var selectedProjectIDs: Set<String> = []

    @Published public internal(set) var settings: AppSettings = AppSettings()
    @Published public internal(set) var projectStatuses: [ProjectStatus] = []
    @Published public internal(set) var aggregateStatus: AggregateStatus = .unknown
    @Published public internal(set) var monitorCadence: PollingCadence = .idle
    @Published public internal(set) var monitorError: String?
    @Published public internal(set) var lastRefreshAt: Date?

    @Published public internal(set) var showingLogs: Bool = false
    @Published public internal(set) var selectedLogsProject: WatchedProject?
    @Published public internal(set) var selectedLogsDeployment: DeploymentSnapshot?
    @Published public internal(set) var logEvents: [DeploymentEvent] = []
    @Published public internal(set) var isLoadingLogs: Bool = false

    @Published public internal(set) var menuIsOpen: Bool = false

    let env: DeployBarEnvironment
    var monitorTask: Task<Void, Never>?
    var hasStarted = false

    public init(environment: DeployBarEnvironment) {
        self.env = environment
    }

    deinit {
        monitorTask?.cancel()
    }

    public func start() {
        guard !hasStarted else {
            return
        }
        hasStarted = true
        Task { await bootstrap() }
    }

    public var hasValidAuth: Bool {
        authUser != nil
    }

    public var hasWatchedProjects: Bool {
        !settings.watchedProjects.isEmpty
    }

    public var requiresSetup: Bool {
        phase == .setupRequired
    }
}
