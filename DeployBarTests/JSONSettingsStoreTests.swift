import Core
@testable import Persistence
import XCTest

final class JSONSettingsStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
            .appendingPathExtension("json")
    }

    override func tearDown() {
        let fm = FileManager.default
        let corruptURL = URL(fileURLWithPath: fileURL.path + ".corrupt")
        for url in [fileURL, corruptURL] {
            if let url, fm.fileExists(atPath: url.path) {
                try? fm.removeItem(at: url)
            }
        }
        fileURL = nil
        super.tearDown()
    }

    func testMissingFileReturnsDefaults() throws {
        let store = try JSONSettingsStore(fileURL: fileURL)

        let loaded = try store.load()

        XCTAssertEqual(loaded, AppSettings())
    }

    func testRoundTripPreservesMutatedFields() throws {
        let store = try JSONSettingsStore(fileURL: fileURL)

        var settings = AppSettings()
        settings.soundsEnabled = false
        settings.watchedProjects = [
            WatchedProject(id: "proj-1", name: "My Project", teamId: "team-1", teamSlug: "my-team")
        ]

        try store.save(settings)

        let reloadedStore = try JSONSettingsStore(fileURL: fileURL)
        let loaded = try reloadedStore.load()

        XCTAssertEqual(loaded, settings)
    }

    func testCorruptFileRecoversToDefaultsWithSidecar() throws {
        try Data("not json".utf8).write(to: fileURL)

        let store = try JSONSettingsStore(fileURL: fileURL)
        let loaded = try store.load()

        XCTAssertEqual(loaded, AppSettings())

        let corruptURL = URL(fileURLWithPath: fileURL.path + ".corrupt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: corruptURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
