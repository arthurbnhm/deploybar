import Core
import Foundation

public struct DeploymentTransition: Sendable, Equatable {
    public let project: WatchedProject
    public let previous: DeploymentSnapshot?
    public let current: DeploymentSnapshot

    public init(project: WatchedProject, previous: DeploymentSnapshot?, current: DeploymentSnapshot) {
        self.project = project
        self.previous = previous
        self.current = current
    }
}

public struct MonitoringUpdate: Sendable {
    public let statuses: [ProjectStatus]
    public let transitions: [DeploymentTransition]
    public let aggregateStatus: AggregateStatus
    public let cadence: PollingCadence
    public let nextDelay: TimeInterval

    public init(
        statuses: [ProjectStatus],
        transitions: [DeploymentTransition],
        aggregateStatus: AggregateStatus,
        cadence: PollingCadence,
        nextDelay: TimeInterval
    ) {
        self.statuses = statuses
        self.transitions = transitions
        self.aggregateStatus = aggregateStatus
        self.cadence = cadence
        self.nextDelay = nextDelay
    }
}

public actor MonitoringEngine {
    private let client: VercelClient

    private var lastSnapshots: [String: DeploymentSnapshot] = [:]
    private var notifiedTerminalKeys: Set<String> = []
    private var lastMeaningfulChangeAt: Date = Date()
    private var burstModeUntil: Date?

    public init(client: VercelClient) {
        self.client = client
    }

    static func terminalKey(for snapshot: DeploymentSnapshot) -> String {
        "\(snapshot.id):\(snapshot.stage.rawValue)"
    }

    public func refresh(
        projects: [WatchedProject],
        profile: PollingProfile,
        menuIsOpen: Bool
    ) async throws -> MonitoringUpdate {
        let now = Date()

        guard !projects.isEmpty else {
            return MonitoringUpdate(
                statuses: [],
                transitions: [],
                aggregateStatus: .unknown,
                cadence: .idle,
                nextDelay: profile.idleInterval
            )
        }

        var statuses: [ProjectStatus] = []
        statuses.reserveCapacity(projects.count)

        var transitions: [DeploymentTransition] = []
        var changed = false

        // Fetch phase: bounded-concurrency task group (politeness cap against Vercel rate limits).
        let client = self.client
        var snapshotsByIndex: [Int: DeploymentSnapshot?] = [:]
        snapshotsByIndex.reserveCapacity(projects.count)

        try await withThrowingTaskGroup(of: (Int, DeploymentSnapshot?).self) { group in
            let maxConcurrent = 4
            var nextIndex = 0

            func addNext() {
                guard nextIndex < projects.count else {
                    return
                }
                let index = nextIndex
                let project = projects[index]
                nextIndex += 1
                group.addTask {
                    let snapshot = try await client.latestProductionDeployment(
                        projectId: project.id,
                        teamId: project.teamId
                    )
                    return (index, snapshot)
                }
            }

            for _ in 0..<min(maxConcurrent, projects.count) {
                addNext()
            }

            while let result = try await group.next() {
                snapshotsByIndex[result.0] = result.1
                addNext()
            }
        }

        // Fold phase: serial, in original project order — deterministic transition/statuses ordering.
        for (index, project) in projects.enumerated() {
            let snapshot = snapshotsByIndex[index] ?? nil

            let previous = lastSnapshots[project.id]
            if previous?.id != snapshot?.id || previous?.stage != snapshot?.stage {
                changed = true
            }

            if let snapshot {
                lastSnapshots[project.id] = snapshot

                if snapshot.stage.isTerminal {
                    let key = Self.terminalKey(for: snapshot)
                    if previous == nil {
                        // First observation for a project is baseline state: do not notify.
                        notifiedTerminalKeys.insert(key)
                    } else if !notifiedTerminalKeys.contains(key) {
                        transitions.append(
                            DeploymentTransition(project: project, previous: previous, current: snapshot)
                        )
                    }
                }
            }

            statuses.append(ProjectStatus(project: project, snapshot: snapshot, lastUpdatedAt: now))
        }

        if changed {
            lastMeaningfulChangeAt = now
            burstModeUntil = now.addingTimeInterval(profile.changeBurstWindow)
        }

        let aggregate = aggregateStatus(for: statuses)
        let cadence = computeCadence(statuses: statuses, menuIsOpen: menuIsOpen, now: now)
        let delay = delay(for: cadence, profile: profile)

        return MonitoringUpdate(
            statuses: statuses,
            transitions: transitions,
            aggregateStatus: aggregate,
            cadence: cadence,
            nextDelay: delay
        )
    }

    public func markNotified(_ transitions: [DeploymentTransition]) {
        for transition in transitions {
            notifiedTerminalKeys.insert(Self.terminalKey(for: transition.current))
        }
    }

    public func resetState() {
        lastSnapshots.removeAll()
        notifiedTerminalKeys.removeAll()
        lastMeaningfulChangeAt = Date()
        burstModeUntil = nil
    }

    private func computeCadence(
        statuses: [ProjectStatus],
        menuIsOpen: Bool,
        now: Date
    ) -> PollingCadence {
        let hasInProgress = statuses.contains {
            guard let snapshot = $0.snapshot else {
                return false
            }
            return snapshot.stage == .building || snapshot.stage == .queued
        }

        if hasInProgress {
            return .inProgress
        }

        if let burstModeUntil, now < burstModeUntil {
            return .burst
        }

        if menuIsOpen {
            return .menuOpen
        }

        let idleSeconds = now.timeIntervalSince(lastMeaningfulChangeAt)
        if idleSeconds > 600 {
            return .idle
        }

        return .active
    }

    private func delay(for cadence: PollingCadence, profile: PollingProfile) -> TimeInterval {
        switch cadence {
        case .inProgress:
            return profile.inProgressBoostInterval
        case .burst:
            return profile.changeBurstInterval
        case .menuOpen:
            return profile.menuOpenInterval
        case .active:
            return profile.activeInterval
        case .idle:
            return profile.idleInterval
        }
    }

    private func aggregateStatus(for statuses: [ProjectStatus]) -> AggregateStatus {
        if statuses.contains(where: { $0.snapshot?.stage == .failed }) {
            return .failed
        }

        if statuses.contains(where: {
            guard let stage = $0.snapshot?.stage else {
                return false
            }
            return stage == .building || stage == .queued
        }) {
            return .building
        }

        if statuses.allSatisfy({ $0.snapshot?.stage == .ready }) {
            return .healthy
        }

        return .unknown
    }
}
