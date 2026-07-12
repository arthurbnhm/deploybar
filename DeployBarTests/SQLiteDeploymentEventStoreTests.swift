import Core
@testable import Persistence
import XCTest

final class SQLiteDeploymentEventStoreTests: XCTestCase {
    private var dbURL: URL!

    override func setUp() {
        super.setUp()
        dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
            .appendingPathExtension("sqlite")
    }

    override func tearDown() {
        removeDatabaseFiles(at: dbURL)
        dbURL = nil
        super.tearDown()
    }

    private func removeDatabaseFiles(at url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let candidate = URL(fileURLWithPath: url.path + suffix)
            if fm.fileExists(atPath: candidate.path) {
                try? fm.removeItem(at: candidate)
            }
        }
    }

    private func makeEvent(
        id: String,
        deploymentId: String = "deployment-1",
        createdAt: Date,
        level: String = "info",
        message: String = "message"
    ) -> DeploymentEvent {
        DeploymentEvent(
            id: id,
            deploymentId: deploymentId,
            createdAt: createdAt,
            level: level,
            message: message
        )
    }

    func testRoundTripOrderingAndLimit() async throws {
        let store = try SQLiteDeploymentEventStore(dbURL: dbURL)
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        let events = (0..<5).map { offset in
            makeEvent(id: "event-\(offset)", createdAt: base.addingTimeInterval(TimeInterval(offset)))
        }

        try await store.persist(events: events)

        let loaded = try await store.load(deploymentId: "deployment-1", limit: 3)

        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded.map(\.id), ["event-4", "event-3", "event-2"])

        let timestamps = loaded.map(\.createdAt)
        XCTAssertEqual(timestamps, timestamps.sorted(by: >))
    }

    func testUpsertDeduplicatesById() async throws {
        let store = try SQLiteDeploymentEventStore(dbURL: dbURL)
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

        try await store.persist(events: [
            makeEvent(id: "event-1", createdAt: createdAt, message: "first message")
        ])
        try await store.persist(events: [
            makeEvent(id: "event-1", createdAt: createdAt, message: "second message")
        ])

        let loaded = try await store.load(deploymentId: "deployment-1", limit: 10)

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.message, "second message")
    }

    func testPurgeRemovesEventsOlderThanCutoff() async throws {
        let store = try SQLiteDeploymentEventStore(dbURL: dbURL)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let eightDaysAgo = now.addingTimeInterval(-8 * 24 * 60 * 60)
        let cutoff = now.addingTimeInterval(-7 * 24 * 60 * 60)

        try await store.persist(events: [
            makeEvent(id: "recent", createdAt: now),
            makeEvent(id: "stale", createdAt: eightDaysAgo)
        ])

        try await store.purge(olderThan: cutoff)

        let loaded = try await store.load(deploymentId: "deployment-1", limit: 10)

        XCTAssertEqual(loaded.map(\.id), ["recent"])
    }

    func testLoadIsolatesEventsByDeploymentId() async throws {
        let store = try SQLiteDeploymentEventStore(dbURL: dbURL)
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

        try await store.persist(events: [
            makeEvent(id: "a-1", deploymentId: "deployment-a", createdAt: createdAt),
            makeEvent(id: "b-1", deploymentId: "deployment-b", createdAt: createdAt)
        ])

        let loadedA = try await store.load(deploymentId: "deployment-a", limit: 10)
        let loadedB = try await store.load(deploymentId: "deployment-b", limit: 10)

        XCTAssertEqual(loadedA.map(\.id), ["a-1"])
        XCTAssertEqual(loadedB.map(\.id), ["b-1"])
    }

    func testClearRemovesAllEvents() async throws {
        let store = try SQLiteDeploymentEventStore(dbURL: dbURL)
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

        try await store.persist(events: [
            makeEvent(id: "a-1", deploymentId: "deployment-a", createdAt: createdAt),
            makeEvent(id: "b-1", deploymentId: "deployment-b", createdAt: createdAt)
        ])

        try await store.clear()

        let loadedA = try await store.load(deploymentId: "deployment-a", limit: 10)
        let loadedB = try await store.load(deploymentId: "deployment-b", limit: 10)

        XCTAssertEqual(loadedA, [])
        XCTAssertEqual(loadedB, [])
    }
}
