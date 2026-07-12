@testable import Features
import XCTest

/// Covers only the pure version-comparison logic in `UpdateChecker`. No test here performs
/// a real network call — `UpdateChecker.checkForUpdate(currentVersion:session:)` is exercised
/// indirectly through `isNewer`/`parseVersion`, which is all it delegates decision-making to.
final class UpdateCheckerTests: XCTestCase {
    // MARK: - Newer

    func testNewerPatchVersionIsDetected() {
        XCTAssertTrue(UpdateChecker.isNewer(remote: "0.1.1", current: "0.1.0"))
    }

    func testNewerMinorVersionIsDetected() {
        XCTAssertTrue(UpdateChecker.isNewer(remote: "0.2.0", current: "0.1.9"))
    }

    func testNewerMajorVersionIsDetected() {
        XCTAssertTrue(UpdateChecker.isNewer(remote: "1.0.0", current: "0.9.9"))
    }

    func testLeadingVPrefixIsTolerated() {
        XCTAssertTrue(UpdateChecker.isNewer(remote: "v0.2.0", current: "0.1.0"))
    }

    func testLongerRemoteVersionIsNewerWhenTrailingComponentNonZero() {
        XCTAssertTrue(UpdateChecker.isNewer(remote: "0.2.0.1", current: "0.2.0"))
    }

    // MARK: - Equal

    func testEqualVersionsAreNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer(remote: "0.1.0", current: "0.1.0"))
    }

    func testEqualVersionsWithVPrefixAreNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer(remote: "v0.1.0", current: "0.1.0"))
    }

    func testShorterRemoteVersionIsZeroPaddedForComparison() {
        // "0.2" == "0.2.0", so it is not newer than "0.2.0".
        XCTAssertFalse(UpdateChecker.isNewer(remote: "0.2", current: "0.2.0"))
    }

    // MARK: - Older

    func testOlderPatchVersionIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer(remote: "0.1.0", current: "0.2.0"))
    }

    func testOlderMajorVersionIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer(remote: "0.9.9", current: "1.0.0"))
    }

    // MARK: - Malformed

    func testMalformedRemoteVersionIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer(remote: "not-a-version", current: "0.1.0"))
    }

    func testMalformedCurrentVersionIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer(remote: "0.2.0", current: "garbage"))
    }

    func testEmptyRemoteVersionIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer(remote: "", current: "0.1.0"))
    }

    func testEmptyCurrentVersionIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer(remote: "0.1.0", current: ""))
    }

    func testPrereleaseSuffixIsTreatedAsMalformed() {
        // "0.1.0-beta" has a non-numeric final component, so it fails closed.
        XCTAssertFalse(UpdateChecker.isNewer(remote: "0.1.0-beta", current: "0.1.0"))
    }

    // MARK: - parseVersion

    func testParseVersionStripsLeadingV() {
        XCTAssertEqual(UpdateChecker.parseVersion("v1.2.3"), [1, 2, 3])
    }

    func testParseVersionStripsLeadingUppercaseV() {
        XCTAssertEqual(UpdateChecker.parseVersion("V1.2.3"), [1, 2, 3])
    }

    func testParseVersionAcceptsBareNumbers() {
        XCTAssertEqual(UpdateChecker.parseVersion("0.1.0"), [0, 1, 0])
    }

    func testParseVersionRejectsNonNumericComponents() {
        XCTAssertNil(UpdateChecker.parseVersion("abc"))
    }

    func testParseVersionRejectsEmptyString() {
        XCTAssertNil(UpdateChecker.parseVersion(""))
    }

    func testParseVersionRejectsBareV() {
        XCTAssertNil(UpdateChecker.parseVersion("v"))
    }
}
