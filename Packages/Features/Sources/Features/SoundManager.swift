import AppKit
import AVFoundation
import Core
import Foundation

/// Plays DeployBar's designed alert sounds (rendered by `SoundDesign`) through
/// a small AVAudioEngine graph. The `.classic` theme bypasses the engine and
/// plays the original system sounds, preserving the pre-theme behavior.
public final class DesignedSoundPlayer: SoundPlayback, @unchecked Sendable {
    public init() {}

    public func play(_ event: SoundEvent, theme: SoundTheme) {
        Task { @MainActor in
            SoundEngine.shared.play(event, theme: theme)
        }
    }
}

@MainActor
private final class SoundEngine {
    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: SoundDesign.sampleRate, channels: 1)

    private var isGraphConfigured = false
    private var bufferCache: [String: AVAudioPCMBuffer] = [:]
    private var pendingPlays = 0

    private init() {}

    func play(_ event: SoundEvent, theme: SoundTheme) {
        if theme == .classic {
            NSSound(named: event == .success ? "Glass" : "Basso")?.play()
            return
        }

        guard let buffer = buffer(theme: theme, event: event), startEngineIfNeeded() else {
            return
        }

        pendingPlays += 1
        player.scheduleBuffer(buffer, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in
                self?.playbackDidFinish()
            }
        }
        player.play()
    }

    private func playbackDidFinish() {
        pendingPlays -= 1
        // Idle the audio unit between alerts so a background menu bar app
        // doesn't keep an active render loop for sounds that fire rarely.
        if pendingPlays <= 0 {
            pendingPlays = 0
            player.stop()
            engine.pause()
        }
    }

    private func startEngineIfNeeded() -> Bool {
        guard let format else {
            return false
        }

        if !isGraphConfigured {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            isGraphConfigured = true
        }

        if engine.isRunning {
            return true
        }

        do {
            try engine.start()
            return true
        } catch {
            // No output device / headless session: alerts stay silent, never fatal.
            return false
        }
    }

    private func buffer(theme: SoundTheme, event: SoundEvent) -> AVAudioPCMBuffer? {
        let key = "\(theme.rawValue):\(event.rawValue)"
        if let cached = bufferCache[key] {
            return cached
        }

        let samples = SoundDesign.renderSamples(theme: theme, event: event)
        guard
            !samples.isEmpty,
            let format,
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
            let channel = buffer.floatChannelData?[0]
        else {
            return nil
        }

        samples.withUnsafeBufferPointer { pointer in
            channel.update(from: pointer.baseAddress!, count: samples.count)
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)

        bufferCache[key] = buffer
        return buffer
    }
}
