import Core
@testable import Features
import XCTest

private actor StubVercelClient: VercelClient {
    var snapshotsByProject: [String: [DeploymentSnapshot]]
    var indexByProject: [String: Int] = [:]

    init(snapshotsByProject: [String: [DeploymentSnapshot]]) {
        self.snapshotsByProject = snapshotsByProject
    }

    func validateToken() async throws -> AuthUser {
        AuthUser(id: "u1", username: "test", email: nil)
    }

    func listTeams(limit _: Int, until _: Int?) async throws -> [Team] { [] }

    func listProjects(teamId _: String?, limit _: Int, until _: String?) async throws -> [Project] { [] }

    func latestProductionDeployment(projectId: String, teamId _: String?) async throws -> DeploymentSnapshot? {
        guard let snapshots = snapshotsByProject[projectId], !snapshots.isEmpty else {
            return nil
        }

        let idx = indexByProject[projectId, default: 0]
        let safeIdx = min(idx, snapshots.count - 1)
        indexByProject[projectId] = idx + 1
        return snapshots[safeIdx]
    }

    func deploymentEvents(deploymentId _: String, limit _: Int, since _: Int?) async throws -> [DeploymentEvent] { [] }
}

/// Tracks in-flight call concurrency to prove the engine bounds and parallelizes fetches.
private actor ConcurrencyTrackingClient: VercelClient {
    private(set) var maxInFlight = 0
    private var currentInFlight = 0
    private let delayNanos: UInt64

    init(delayNanos: UInt64 = 20_000_000) {
        self.delayNanos = delayNanos
    }

    func validateToken() async throws -> AuthUser {
        AuthUser(id: "u1", username: "test", email: nil)
    }

    func listTeams(limit _: Int, until _: Int?) async throws -> [Team] { [] }

    func listProjects(teamId _: String?, limit _: Int, until _: String?) async throws -> [Project] { [] }

    func latestProductionDeployment(projectId: String, teamId _: String?) async throws -> DeploymentSnapshot? {
        currentInFlight += 1
        maxInFlight = max(maxInFlight, currentInFlight)
        try? await Task.sleep(nanoseconds: delayNanos)
        currentInFlight -= 1
        return DeploymentSnapshot(
            id: "dep_\(projectId)",
            projectId: projectId,
            stage: .ready,
            createdAt: Date(),
            url: nil,
            commitMessage: nil
        )
    }

    func deploymentEvents(deploymentId _: String, limit _: Int, since _: Int?) async throws -> [DeploymentEvent] { [] }
}

final class MonitoringEngineTests: XCTestCase {
    func testInitialTerminalSnapshotDoesNotEmitTransition() async throws {
        let first = DeploymentSnapshot(
            id: "dep_1",
            projectId: "p1",
            stage: .ready,
            createdAt: Date(),
            url: nil,
            commitMessage: nil
        )

        let client = StubVercelClient(snapshotsByProject: ["p1": [first, first]])
        let engine = MonitoringEngine(client: client)
        let watched = [WatchedProject(id: "p1", name: "Project", teamId: nil, teamSlug: nil)]

        let firstUpdate = try await engine.refresh(projects: watched, profile: .balanced, menuIsOpen: false)
        let secondUpdate = try await engine.refresh(projects: watched, profile: .balanced, menuIsOpen: false)

        XCTAssertEqual(firstUpdate.transitions.count, 0)
        XCTAssertEqual(secondUpdate.transitions.count, 0)
        XCTAssertEqual(firstUpdate.aggregateStatus, .healthy)
    }

    func testTransitionEmitsWhenProjectMovesFromNonTerminalToTerminal() async throws {
        let building = DeploymentSnapshot(
            id: "dep_build",
            projectId: "p_move",
            stage: .building,
            createdAt: Date(),
            url: nil,
            commitMessage: nil
        )
        let ready = DeploymentSnapshot(
            id: "dep_ready",
            projectId: "p_move",
            stage: .ready,
            createdAt: Date(),
            url: nil,
            commitMessage: nil
        )

        let client = StubVercelClient(snapshotsByProject: ["p_move": [building, ready]])
        let engine = MonitoringEngine(client: client)
        let watched = [WatchedProject(id: "p_move", name: "Project", teamId: nil, teamSlug: nil)]

        let firstUpdate = try await engine.refresh(projects: watched, profile: .balanced, menuIsOpen: false)
        let secondUpdate = try await engine.refresh(projects: watched, profile: .balanced, menuIsOpen: false)

        XCTAssertEqual(firstUpdate.transitions.count, 0)
        XCTAssertEqual(secondUpdate.transitions.count, 1)
    }

    func testUnconfirmedTransitionReEmitsUntilMarkedNotified() async throws {
        let building = DeploymentSnapshot(
            id: "dep_confirm_build",
            projectId: "p_confirm",
            stage: .building,
            createdAt: Date(),
            url: nil,
            commitMessage: nil
        )
        let ready = DeploymentSnapshot(
            id: "dep_confirm_ready",
            projectId: "p_confirm",
            stage: .ready,
            createdAt: Date(),
            url: nil,
            commitMessage: nil
        )

        let client = StubVercelClient(snapshotsByProject: ["p_confirm": [building, ready]])
        let engine = MonitoringEngine(client: client)
        let watched = [WatchedProject(id: "p_confirm", name: "Project", teamId: nil, teamSlug: nil)]

        _ = try await engine.refresh(projects: watched, profile: .balanced, menuIsOpen: false)
        let secondUpdate = try await engine.refresh(projects: watched, profile: .balanced, menuIsOpen: false)
        XCTAssertEqual(secondUpdate.transitions.count, 1)

        // Do NOT call markNotified: simulate a refresh cycle that was cancelled after
        // detecting the transition but before delivery was confirmed. The transition
        // must be emitted again on the next cycle rather than silently dropped.
        let thirdUpdate = try await engine.refresh(projects: watched, profile: .balanced, menuIsOpen: false)
        XCTAssertEqual(thirdUpdate.transitions.count, 1)

        await engine.markNotified(secondUpdate.transitions)

        let fourthUpdate = try await engine.refresh(projects: watched, profile: .balanced, menuIsOpen: false)
        XCTAssertEqual(fourthUpdate.transitions.count, 0)
    }

    func testNewlyAddedProjectTerminalBaselineDoesNotEmitTransition() async throws {
        let p1Building = DeploymentSnapshot(
            id: "dep_p1_build",
            projectId: "p1",
            stage: .building,
            createdAt: Date(),
            url: nil,
            commitMessage: nil
        )
        let p2Ready = DeploymentSnapshot(
            id: "dep_p2_ready",
            projectId: "p2",
            stage: .ready,
            createdAt: Date(),
            url: nil,
            commitMessage: nil
        )

        let client = StubVercelClient(
            snapshotsByProject: [
                "p1": [p1Building, p1Building],
                "p2": [p2Ready]
            ]
        )
        let engine = MonitoringEngine(client: client)

        let firstWatched = [WatchedProject(id: "p1", name: "Project 1", teamId: nil, teamSlug: nil)]
        let secondWatched = [
            WatchedProject(id: "p1", name: "Project 1", teamId: nil, teamSlug: nil),
            WatchedProject(id: "p2", name: "Project 2", teamId: nil, teamSlug: nil)
        ]

        let firstUpdate = try await engine.refresh(projects: firstWatched, profile: .balanced, menuIsOpen: false)
        let secondUpdate = try await engine.refresh(projects: secondWatched, profile: .balanced, menuIsOpen: false)

        XCTAssertEqual(firstUpdate.transitions.count, 0)
        XCTAssertEqual(secondUpdate.transitions.count, 0)
    }

    func testInProgressUsesBoostInterval() async throws {
        let building = DeploymentSnapshot(
            id: "dep_2",
            projectId: "p2",
            stage: .building,
            createdAt: Date(),
            url: nil,
            commitMessage: nil
        )

        let client = StubVercelClient(snapshotsByProject: ["p2": [building]])
        let engine = MonitoringEngine(client: client)
        let watched = [WatchedProject(id: "p2", name: "Build", teamId: nil, teamSlug: nil)]

        let update = try await engine.refresh(projects: watched, profile: .balanced, menuIsOpen: false)
        XCTAssertEqual(update.cadence, .inProgress)
        XCTAssertEqual(update.nextDelay, PollingProfile.balanced.inProgressBoostInterval)
        XCTAssertEqual(update.aggregateStatus, .building)
    }

    func testSnapshotChangeEntersBurstCadence() async throws {
        let queued = DeploymentSnapshot(
            id: "dep_3",
            projectId: "p3",
            stage: .queued,
            createdAt: Date(),
            url: nil,
            commitMessage: nil
        )
        let ready = DeploymentSnapshot(
            id: "dep_4",
            projectId: "p3",
            stage: .ready,
            createdAt: Date(),
            url: nil,
            commitMessage: nil
        )

        let client = StubVercelClient(snapshotsByProject: ["p3": [queued, ready]])
        let engine = MonitoringEngine(client: client)
        let watched = [WatchedProject(id: "p3", name: "Build", teamId: nil, teamSlug: nil)]

        _ = try await engine.refresh(projects: watched, profile: .balanced, menuIsOpen: false)
        let update = try await engine.refresh(projects: watched, profile: .balanced, menuIsOpen: false)

        XCTAssertEqual(update.cadence, .burst)
        XCTAssertEqual(update.nextDelay, PollingProfile.balanced.changeBurstInterval)
    }

    func testFirstObservationDoesNotEnterBurstCadence() async throws {
        let first = DeploymentSnapshot(
            id: "dep_baseline",
            projectId: "p_baseline",
            stage: .ready,
            createdAt: Date(),
            url: nil,
            commitMessage: nil
        )
        let second = DeploymentSnapshot(
            id: "dep_updated",
            projectId: "p_baseline",
            stage: .ready,
            createdAt: Date(),
            url: nil,
            commitMessage: nil
        )

        let client = StubVercelClient(snapshotsByProject: ["p_baseline": [first, second]])
        let engine = MonitoringEngine(client: client)
        let watched = [WatchedProject(id: "p_baseline", name: "Project", teamId: nil, teamSlug: nil)]

        let firstUpdate = try await engine.refresh(projects: watched, profile: .balanced, menuIsOpen: false)
        XCTAssertNotEqual(firstUpdate.cadence, .burst)

        let secondUpdate = try await engine.refresh(projects: watched, profile: .balanced, menuIsOpen: false)
        XCTAssertEqual(secondUpdate.cadence, .burst)
    }

    func testFetchesConcurrentlyWithinBoundAndPreservesOrder() async throws {
        let client = ConcurrencyTrackingClient()
        let engine = MonitoringEngine(client: client)
        let watched = (1...6).map {
            WatchedProject(id: "p\($0)", name: "Project \($0)", teamId: nil, teamSlug: nil)
        }

        let update = try await engine.refresh(projects: watched, profile: .balanced, menuIsOpen: false)

        let maxInFlight = await client.maxInFlight
        XCTAssertGreaterThan(maxInFlight, 1)
        XCTAssertLessThanOrEqual(maxInFlight, 4)
        XCTAssertEqual(update.statuses.map(\.project.id), watched.map(\.id))
    }
}
