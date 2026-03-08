import Core
import Foundation
import Observation
import SwiftUI

public enum AppPhase: Equatable {
    case loading
    case setupRequired
    case running
    case unsupported(String)
}

public enum AuthConnectionState: Equatable {
    case loading
    case connected
    case retrying(reason: String)
    case setupRequired(reason: String?)
}

@MainActor
@Observable
public final class DeployBarAppStore {
    static let testNotificationTitle = "DeployBar Notifications Enabled"
    static let testNotificationBodyPrefix = "You will now receive deployment status updates."
    static let tokenHelpURL = URL(string: "https://vercel.com/account/settings/tokens")!
    static let defaultTokenPrompt = "Paste a Vercel access token to continue."

    public internal(set) var phase: AppPhase = .loading
    public internal(set) var authConnectionState: AuthConnectionState = .loading
    public internal(set) var authUser: AuthUser?
    public var tokenError: String?
    public var tokenNotice: String?
    public var isValidatingToken: Bool = false

    public internal(set) var teams: [Team] = []
    public var selectedScope: TeamScope = .personal
    public internal(set) var availableProjects: [Project] = []
    public var selectedProjectIDs: Set<String> = []

    public internal(set) var settings: AppSettings = AppSettings()
    public internal(set) var projectStatuses: [ProjectStatus] = []
    public internal(set) var aggregateStatus: AggregateStatus = .unknown
    public internal(set) var monitorCadence: PollingCadence = .idle
    public internal(set) var monitorError: String?
    public internal(set) var lastRefreshAt: Date?
    public internal(set) var isInitialRefreshInFlight: Bool = false
    public internal(set) var hasCompletedInitialRefresh: Bool = false
    public internal(set) var isShowingCachedStatuses: Bool = false
    public internal(set) var cachedStatusAge: TimeInterval?

    public internal(set) var showingLogs: Bool = false
    public internal(set) var selectedLogsProject: WatchedProject?
    public internal(set) var selectedLogsDeployment: DeploymentSnapshot?
    public internal(set) var logEvents: [DeploymentEvent] = []
    public internal(set) var isLoadingLogs: Bool = false

    public internal(set) var menuIsOpen: Bool = false

    let env: DeployBarEnvironment
    var monitorTask: Task<Void, Never>?
    var hasStarted = false
    var consecutiveTransientAuthFailures = 0

    public init(environment: DeployBarEnvironment) {
        self.env = environment
    }

    public func start() {
        guard !hasStarted else {
            return
        }
        hasStarted = true
        Task { await bootstrap() }
    }

    public var hasValidAuth: Bool {
        if case .connected = authConnectionState {
            return authUser != nil
        }
        return false
    }

    public var hasWatchedProjects: Bool {
        !settings.watchedProjects.isEmpty
    }

    public var hasConfiguredProjects: Bool {
        hasWatchedProjects
    }

    public var requiresSetup: Bool {
        if case .setupRequired = authConnectionState {
            return true
        }
        return phase == .setupRequired
    }

    public var isCachedStatusStale: Bool {
        guard let cachedStatusAge else {
            return false
        }
        return cachedStatusAge > 120
    }

    public var isAuthRetrying: Bool {
        if case .retrying = authConnectionState {
            return true
        }
        return false
    }

    public var shouldPromptForTokenInput: Bool {
        if case .setupRequired = authConnectionState {
            return true
        }
        return phase == .setupRequired
    }

    public var authStatusMessage: String? {
        switch authConnectionState {
        case .loading:
            return "Checking saved Vercel token..."
        case .connected:
            return nil
        case let .retrying(reason):
            return reason
        case let .setupRequired(reason):
            return reason
        }
    }
}
