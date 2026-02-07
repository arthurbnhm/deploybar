import Core
@testable import Features
import XCTest

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
}
