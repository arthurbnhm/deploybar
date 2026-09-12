import Core
@testable import Features
import SwiftUI
import XCTest

/// Pins the Swift status-color mapping to `design/brand-tokens.json`, the
/// single source of truth the website also imports. If either side drifts,
/// this test fails instead of the two surfaces silently diverging.
final class BrandTokensTests: XCTestCase {
    private struct BrandTokens: Decodable {
        struct StatusColor: Decodable {
            let semantic: String
            let hex: String
        }

        let statusColors: [String: StatusColor]
    }

    private func loadTokens() throws -> BrandTokens {
        // DeployBarTests/BrandTokensTests.swift -> repo root -> design/brand-tokens.json
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("design/brand-tokens.json")
        return try JSONDecoder().decode(BrandTokens.self, from: Data(contentsOf: url))
    }

    func testSwiftStatusColorsMatchBrandTokens() throws {
        let tokens = try loadTokens()

        // stage -> (token key, expected semantic name, the Color the app uses)
        let expectations: [(stage: DeploymentStage, key: String, semantic: String, color: Color)] = [
            (.ready, "ready", "green", .green),
            (.building, "building", "orange", .orange),
            (.failed, "failed", "red", .red),
            (.queued, "queued", "indigo", .indigo),
            (.canceled, "canceled", "gray", .gray),
        ]

        for expectation in expectations {
            let token = try XCTUnwrap(
                tokens.statusColors[expectation.key],
                "design/brand-tokens.json is missing the \"\(expectation.key)\" status color"
            )
            XCTAssertEqual(
                token.semantic,
                expectation.semantic,
                "brand-tokens \"\(expectation.key)\" semantic drifted from the app's mapping"
            )
            XCTAssertEqual(
                expectation.stage.tint,
                expectation.color,
                "DeploymentStage.\(expectation.key).tint drifted from the documented semantic color"
            )
        }
    }

    func testBrandTokenHexValuesAreWellFormed() throws {
        let tokens = try loadTokens()
        XCTAssertEqual(tokens.statusColors.count, 5, "expected exactly the five shared statuses")

        for (key, token) in tokens.statusColors {
            XCTAssertTrue(
                token.hex.wholeMatch(of: /#[0-9A-F]{6}/) != nil,
                "\"\(key)\" hex \(token.hex) is not an uppercase #RRGGBB value"
            )
        }
    }
}
