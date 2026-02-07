import AppKit
import Core
import Foundation

public final class SystemSoundPlayer: SoundPlayback, @unchecked Sendable {
    public init() {}

    public func playSuccess() {
        Task { @MainActor in
            NSSound(named: "Glass")?.play()
        }
    }

    public func playFailure() {
        Task { @MainActor in
            NSSound(named: "Basso")?.play()
        }
    }
}
