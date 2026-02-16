@testable import Features
import SwiftUI
import XCTest

@MainActor
final class DeployBarSmokeTests: XCTestCase {
    func testViewsInitialize() {
        let store = DeployBarAppStore(environment: .preview())
        _ = MenuBarContentView(store: store)
        _ = DeployBarSettingsView(store: store)
    }
}
