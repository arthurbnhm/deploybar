import Core
@testable import VercelAPI
import XCTest

final class DeploymentStageMapperTests: XCTestCase {
    func testReadyStateMapsToReady() {
        XCTAssertEqual(DeploymentStageMapper.map(state: "READY", readyState: "READY"), .ready)
    }

    func testFailedStateMapsToFailed() {
        XCTAssertEqual(DeploymentStageMapper.map(state: "ERROR", readyState: "ERROR"), .failed)
    }

    func testCanceledStateMapsToCanceled() {
        XCTAssertEqual(DeploymentStageMapper.map(state: "CANCELED", readyState: "CANCELED"), .canceled)
    }

    func testBuildingStateMapsToBuilding() {
        XCTAssertEqual(DeploymentStageMapper.map(state: "BUILDING", readyState: "BUILDING"), .building)
    }

    func testUnknownStateMapsToUnknown() {
        XCTAssertEqual(DeploymentStageMapper.map(state: nil, readyState: nil), .unknown)
    }
}
