@testable import VercelAPI
import XCTest

final class DeploymentEventsDecodingTests: XCTestCase {
    func testDecodesLegacyTextShape() throws {
        let json = #"[{"created":1739000000000,"type":"stdout","text":"Build completed"}]"#
        let events = try decodeEvents(from: json)

        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(events[0].id.hasPrefix("event-1739000000000-stdout-"))
        XCTAssertEqual(events[0].type, "stdout")
        XCTAssertEqual(events[0].text, "Build completed")
        XCTAssertEqual(events[0].created, 1739000000000)
    }

    func testDecodesPayloadTextShape() throws {
        let json = #"[{"created":"1739000000123","type":"stdout","payload":{"id":"evt_abc123","text":"Installing dependencies"}}]"#
        let events = try decodeEvents(from: json)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].id, "evt_abc123")
        XCTAssertEqual(events[0].text, "Installing dependencies")
        XCTAssertEqual(events[0].created, 1739000000123)
    }

    func testDecodesNestedPayloadInfoShape() throws {
        let json = #"[{"type":"info","payload":{"date":1739000000456,"info":{"name":"step","value":"Build"}}}]"#
        let events = try decodeEvents(from: json)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].created, 1739000000456)
        XCTAssertEqual(events[0].text, "step: Build")
    }

    func testDecodesWrappedEventsObject() throws {
        let json = #"{"events":[{"created":1739000000789,"type":"error","message":"Build failed"}]}"#
        let payload = try JSONDecoder().decode(DeploymentEventListResponse.self, from: Data(json.utf8))

        XCTAssertEqual(payload.events.count, 1)
        XCTAssertEqual(payload.events[0].text, "Build failed")
    }

    private func decodeEvents(from json: String) throws -> [DeploymentEventDTO] {
        let payload = try JSONDecoder().decode(DeploymentEventListResponse.self, from: Data(json.utf8))
        return payload.events
    }
}
