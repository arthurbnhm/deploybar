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

    func testRelativeDeploymentTimeChangesWithTimelineDate() {
        let deploymentDate = Date(timeIntervalSinceReferenceDate: 10_000)
        let locale = Locale(identifier: "en_US_POSIX")

        let recentLabel = relativeTimeLabel(
            for: deploymentDate,
            relativeTo: deploymentDate.addingTimeInterval(30),
            locale: locale
        )
        let olderLabel = relativeTimeLabel(
            for: deploymentDate,
            relativeTo: deploymentDate.addingTimeInterval(5 * 60),
            locale: locale
        )

        XCTAssertNotEqual(recentLabel, olderLabel)
    }
}
