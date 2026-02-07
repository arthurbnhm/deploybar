import Foundation

public enum DeploymentStage: String, Codable, Sendable {
    case queued
    case building
    case ready
    case failed
    case canceled
    case unknown

    public var isTerminal: Bool {
        switch self {
        case .ready, .failed, .canceled:
            return true
        case .queued, .building, .unknown:
            return false
        }
    }

    public var isSuccess: Bool {
        self == .ready
    }
}

public enum PollingCadence: String, Codable, Sendable {
    case inProgress
    case burst
    case menuOpen
    case active
    case idle
}

public enum PollingProfile: String, Codable, Sendable {
    case balanced
    case aggressive
    case eco

    public var menuOpenInterval: TimeInterval {
        switch self {
        case .balanced: return 6
        case .aggressive: return 4
        case .eco: return 10
        }
    }

    public var activeInterval: TimeInterval {
        switch self {
        case .balanced: return 18
        case .aggressive: return 12
        case .eco: return 30
        }
    }

    public var idleInterval: TimeInterval {
        switch self {
        case .balanced: return 90
        case .aggressive: return 45
        case .eco: return 120
        }
    }

    public var inProgressBoostInterval: TimeInterval {
        switch self {
        case .balanced: return 3
        case .aggressive: return 2
        case .eco: return 5
        }
    }

    public var changeBurstInterval: TimeInterval {
        switch self {
        case .balanced: return 4
        case .aggressive: return 2.5
        case .eco: return 5
        }
    }

    public var changeBurstWindow: TimeInterval {
        switch self {
        case .balanced, .aggressive:
            return 45
        case .eco:
            return 25
        }
    }
}

public enum TeamScope: Codable, Sendable, Equatable, Hashable {
    case personal
    case team(id: String, slug: String)

    public var teamId: String? {
        switch self {
        case .personal:
            return nil
        case let .team(id, _):
            return id
        }
    }
}

public struct AuthUser: Codable, Sendable, Equatable {
    public let id: String
    public let username: String
    public let email: String?

    public init(id: String, username: String, email: String?) {
        self.id = id
        self.username = username
        self.email = email
    }
}

public struct Team: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let slug: String
    public let name: String

    public init(id: String, slug: String, name: String) {
        self.id = id
        self.slug = slug
        self.name = name
    }
}

public struct Project: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let teamId: String?
    public let updatedAt: Date?

    public init(id: String, name: String, teamId: String?, updatedAt: Date?) {
        self.id = id
        self.name = name
        self.teamId = teamId
        self.updatedAt = updatedAt
    }
}

public struct WatchedProject: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let teamId: String?
    public let teamSlug: String?

    public init(id: String, name: String, teamId: String?, teamSlug: String?) {
        self.id = id
        self.name = name
        self.teamId = teamId
        self.teamSlug = teamSlug
    }
}

public struct DeploymentSnapshot: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let projectId: String
    public let stage: DeploymentStage
    public let createdAt: Date
    public let url: URL?
    public let commitMessage: String?

    public init(
        id: String,
        projectId: String,
        stage: DeploymentStage,
        createdAt: Date,
        url: URL?,
        commitMessage: String?
    ) {
        self.id = id
        self.projectId = projectId
        self.stage = stage
        self.createdAt = createdAt
        self.url = url
        self.commitMessage = commitMessage
    }
}

public struct DeploymentEvent: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let deploymentId: String
    public let createdAt: Date
    public let level: String
    public let message: String

    public init(id: String, deploymentId: String, createdAt: Date, level: String, message: String) {
        self.id = id
        self.deploymentId = deploymentId
        self.createdAt = createdAt
        self.level = level
        self.message = message
    }
}

public struct ProjectStatus: Sendable, Equatable, Identifiable {
    public var id: String { project.id }
    public let project: WatchedProject
    public let snapshot: DeploymentSnapshot?
    public let lastUpdatedAt: Date

    public init(project: WatchedProject, snapshot: DeploymentSnapshot?, lastUpdatedAt: Date) {
        self.project = project
        self.snapshot = snapshot
        self.lastUpdatedAt = lastUpdatedAt
    }
}

public struct AppSettings: Codable, Sendable, Equatable {
    public var pollingProfile: PollingProfile
    public var notificationsEnabled: Bool
    public var soundsEnabled: Bool
    public var launchAtLogin: Bool
    public var watchedProjects: [WatchedProject]
    public var selectedScope: TeamScope

    public init(
        pollingProfile: PollingProfile = .balanced,
        notificationsEnabled: Bool = true,
        soundsEnabled: Bool = true,
        launchAtLogin: Bool = false,
        watchedProjects: [WatchedProject] = [],
        selectedScope: TeamScope = .personal
    ) {
        self.pollingProfile = pollingProfile
        self.notificationsEnabled = notificationsEnabled
        self.soundsEnabled = soundsEnabled
        self.launchAtLogin = launchAtLogin
        self.watchedProjects = watchedProjects
        self.selectedScope = selectedScope
    }
}

public enum AggregateStatus: Sendable, Equatable {
    case healthy
    case building
    case failed
    case unknown
}
