import Core
@testable import Features
import XCTest

final class SoundDesignTests: XCTestCase {
    private let designedThemes: [SoundTheme] = [.aurora, .pulse]

    func testDesignedSoundsAreWellFormed() {
        for theme in designedThemes {
            for event in SoundEvent.allCases {
                let samples = SoundDesign.renderSamples(theme: theme, event: event)
                let label = "\(theme.rawValue)/\(event.rawValue)"

                XCTAssertFalse(samples.isEmpty, "\(label) rendered no samples")

                let duration = Double(samples.count) / SoundDesign.sampleRate
                XCTAssertTrue((0.15 ... 1.2).contains(duration), "\(label) duration \(duration)s out of range")

                let peak = samples.map(abs).max() ?? 0
                XCTAssertLessThanOrEqual(peak, 1.0, "\(label) clips (peak \(peak))")
                XCTAssertGreaterThan(peak, 0.1, "\(label) is nearly silent (peak \(peak))")

                XCTAssertFalse(samples.contains { $0.isNaN || $0.isInfinite }, "\(label) contains invalid samples")

                // Click-free at both ends.
                XCTAssertLessThan(abs(samples.first ?? 1), 0.02, "\(label) starts with a click")
                XCTAssertLessThan(abs(samples.last ?? 1), 0.01, "\(label) ends with a click")
            }
        }
    }

    func testClassicThemeHasNoRenderedSamples() {
        for event in SoundEvent.allCases {
            XCTAssertTrue(SoundDesign.renderSamples(theme: .classic, event: event).isEmpty)
        }
    }

    func testSoundsAreDistinctAcrossEventsAndThemes() {
        let auroraSuccess = SoundDesign.renderSamples(theme: .aurora, event: .success)
        let auroraFailure = SoundDesign.renderSamples(theme: .aurora, event: .failure)
        let pulseSuccess = SoundDesign.renderSamples(theme: .pulse, event: .success)

        XCTAssertNotEqual(auroraSuccess, auroraFailure, "success and failure must be distinguishable by ear")
        XCTAssertNotEqual(auroraSuccess, pulseSuccess, "themes must be distinguishable by ear")
    }

    func testLegacySettingsWithoutSoundThemeDecodeToAurora() throws {
        let legacyJSON = #"{"pollingProfile":"balanced","notificationsEnabled":true,"soundsEnabled":true}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(settings.soundTheme, .aurora)
    }

    func testSoundThemeRoundTripsThroughCoding() throws {
        var settings = AppSettings()
        settings.soundTheme = .pulse

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded.soundTheme, .pulse)
    }

    func testTransitionNotificationServicePlaysSelectedTheme() async {
        let player = InMemorySoundPlayer()
        var settings = AppSettings()
        settings.soundTheme = .pulse
        settings.soundsEnabled = true
        settings.notificationsEnabled = false

        await TransitionNotificationService.process(
            transitions: [makeTransition(stage: .success)],
            settings: settings,
            notificationRouter: InMemoryNotificationRouter(),
            soundPlayer: player
        )

        XCTAssertEqual(player.played.count, 1)
        XCTAssertEqual(player.played.first?.event, .success)
        XCTAssertEqual(player.played.first?.theme, .pulse)
    }

    func testTransitionNotificationServiceStaysSilentWhenSoundsDisabled() async {
        let player = InMemorySoundPlayer()
        var settings = AppSettings()
        settings.soundsEnabled = false
        settings.notificationsEnabled = false

        await TransitionNotificationService.process(
            transitions: [makeTransition(stage: .failure)],
            settings: settings,
            notificationRouter: InMemoryNotificationRouter(),
            soundPlayer: player
        )

        XCTAssertTrue(player.played.isEmpty)
    }

    /// Renders every designed sound to a WAV file for human audition.
    /// Skipped unless SOUND_EXPORT_DIR is set (mirrors SNAPSHOT_DIR for the UI).
    func testExportWavsForAudition() throws {
        guard let dir = ProcessInfo.processInfo.environment["SOUND_EXPORT_DIR"] else {
            throw XCTSkip("Set SOUND_EXPORT_DIR to export designed sounds as WAV files")
        }

        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        for theme in designedThemes {
            for event in SoundEvent.allCases {
                let samples = SoundDesign.renderSamples(theme: theme, event: event)
                let url = URL(fileURLWithPath: dir).appendingPathComponent("\(theme.rawValue)-\(event.rawValue).wav")
                try wavData(samples: samples, sampleRate: Int(SoundDesign.sampleRate)).write(to: url)
            }
        }
    }

    // MARK: - Helpers

    private func makeTransition(stage: SoundEvent) -> DeploymentTransition {
        let project = WatchedProject(id: "p1", name: "Project", teamId: nil, teamSlug: nil)
        let previous = DeploymentSnapshot(
            id: "dep_prev",
            projectId: "p1",
            stage: .building,
            createdAt: Date(),
            url: nil,
            commitMessage: nil
        )
        let current = DeploymentSnapshot(
            id: "dep_now",
            projectId: "p1",
            stage: stage == .success ? .ready : .failed,
            createdAt: Date(),
            url: nil,
            commitMessage: nil
        )
        return DeploymentTransition(project: project, previous: previous, current: current)
    }

    /// Minimal 16-bit PCM mono WAV encoder.
    private func wavData(samples: [Float], sampleRate: Int) -> Data {
        var pcm = Data(capacity: samples.count * 2)
        for sample in samples {
            let clamped = max(-1, min(1, sample))
            var value = Int16(clamped * Float(Int16.max)).littleEndian
            withUnsafeBytes(of: &value) { pcm.append(contentsOf: $0) }
        }

        func chunk(_ tag: String, _ payload: Data) -> Data {
            var data = Data(tag.utf8)
            var size = UInt32(payload.count).littleEndian
            withUnsafeBytes(of: &size) { data.append(contentsOf: $0) }
            data.append(payload)
            return data
        }

        var fmt = Data()
        func appendLE<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { fmt.append(contentsOf: $0) }
        }
        appendLE(UInt16(1)) // PCM
        appendLE(UInt16(1)) // mono
        appendLE(UInt32(sampleRate))
        appendLE(UInt32(sampleRate * 2)) // byte rate
        appendLE(UInt16(2)) // block align
        appendLE(UInt16(16)) // bits per sample

        var riffPayload = Data("WAVE".utf8)
        riffPayload.append(chunk("fmt ", fmt))
        riffPayload.append(chunk("data", pcm))
        return chunk("RIFF", riffPayload)
    }
}
