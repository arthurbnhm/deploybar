import Core
import Foundation

/// Deterministic DSP renderers for DeployBar's designed alert sounds.
///
/// The sounds are synthesized at runtime instead of shipped as audio assets:
/// the app bundle is assembled by `scripts/install_app.sh` from the bare
/// SwiftPM binary, so a resource bundle would be easy to lose in packaging.
/// Rendering in code keeps the binary self-contained and makes the sound
/// design unit-testable sample-by-sample.
public enum SoundDesign {
    public static let sampleRate: Double = 44_100

    /// Mono samples for a theme/event pair, peak-normalized and click-free at
    /// both ends. `.classic` returns no samples — it plays the original
    /// system sounds instead (see `DesignedSoundPlayer`).
    public static func renderSamples(theme: SoundTheme, event: SoundEvent) -> [Float] {
        switch (theme, event) {
        case (.aurora, .success):
            // Glassy struck-bar chime, rising a fifth: E5 -> B5.
            return mix(
                layers: [
                    struckBar(frequency: 659.26, startTime: 0.00, duration: 0.55, amplitude: 0.62),
                    struckBar(frequency: 987.77, startTime: 0.11, duration: 0.60, amplitude: 0.55),
                ],
                targetPeak: 0.34
            )

        case (.aurora, .failure):
            // Same instrument falling a tritone (D5 -> Ab4), with a quiet low
            // Ab3 undertone that grounds the second note without harshness.
            return mix(
                layers: [
                    struckBar(frequency: 587.33, startTime: 0.00, duration: 0.55, amplitude: 0.55),
                    struckBar(frequency: 415.30, startTime: 0.13, duration: 0.72, amplitude: 0.60),
                    struckBar(frequency: 207.65, startTime: 0.13, duration: 0.72, amplitude: 0.20),
                ],
                targetPeak: 0.31
            )

        case (.pulse, .success):
            // Minimal electronic "up": a tiny high ping into a rising octave
            // sweep, answered by a short pure blip.
            return mix(
                layers: [
                    partialTone(frequency: 2637.02, startTime: 0, duration: 0.05, attack: 0.002, decayTau: 0.012, amplitude: 0.18),
                    chirp(from: 660, to: 1320, startTime: 0.01, duration: 0.14, amplitude: 0.55, thirdHarmonic: 0.0),
                    partialTone(frequency: 1174.66, startTime: 0.15, duration: 0.14, attack: 0.003, decayTau: 0.045, amplitude: 0.50),
                ],
                targetPeak: 0.32
            )

        case (.pulse, .failure):
            // Minimal electronic "down": a falling octave sweep with a hint of
            // edge, over a soft sub-thump.
            return mix(
                layers: [
                    chirp(from: 440, to: 220, startTime: 0, duration: 0.20, amplitude: 0.55, thirdHarmonic: 0.18),
                    partialTone(frequency: 87.31, startTime: 0.02, duration: 0.20, attack: 0.006, decayTau: 0.060, amplitude: 0.55),
                ],
                targetPeak: 0.30
            )

        case (.classic, _):
            return []
        }
    }

    // MARK: - Instruments

    private struct Layer {
        let startTime: Double
        let samples: [Float]
    }

    /// A struck idiophone (marimba/celesta-like) voice: an inharmonic partial
    /// stack where higher partials are quieter and decay faster.
    private static func struckBar(
        frequency: Double,
        startTime: Double,
        duration: Double,
        amplitude: Double
    ) -> [Layer] {
        let partials: [(ratio: Double, amplitude: Double, decayTau: Double)] = [
            (1.00, 1.00, 0.160),
            (2.76, 0.30, 0.070),
            (5.40, 0.10, 0.032),
        ]

        return partials.map { partial in
            Layer(
                startTime: startTime,
                samples: renderTone(
                    frequency: frequency * partial.ratio,
                    duration: duration,
                    attack: 0.004,
                    decayTau: partial.decayTau,
                    amplitude: amplitude * partial.amplitude
                )
            )
        }
    }

    private static func partialTone(
        frequency: Double,
        startTime: Double,
        duration: Double,
        attack: Double,
        decayTau: Double,
        amplitude: Double
    ) -> [Layer] {
        [
            Layer(
                startTime: startTime,
                samples: renderTone(
                    frequency: frequency,
                    duration: duration,
                    attack: attack,
                    decayTau: decayTau,
                    amplitude: amplitude
                )
            )
        ]
    }

    /// An exponential frequency sweep under a Hann envelope (click-free at
    /// both ends by construction). `thirdHarmonic` adds a controlled amount of
    /// edge for the failure variant.
    private static func chirp(
        from startFrequency: Double,
        to endFrequency: Double,
        startTime: Double,
        duration: Double,
        amplitude: Double,
        thirdHarmonic: Double
    ) -> [Layer] {
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var phase = 0.0
        let ratio = endFrequency / startFrequency

        for index in 0 ..< count {
            let progress = Double(index) / Double(count)
            let frequency = startFrequency * pow(ratio, progress)
            phase += 2 * .pi * frequency / sampleRate

            let hann = sin(.pi * progress) * sin(.pi * progress)
            let value = (sin(phase) + thirdHarmonic * sin(3 * phase)) * hann * amplitude
            samples[index] = Float(value)
        }

        return [Layer(startTime: startTime, samples: samples)]
    }

    /// A sine with a fast exponential attack and exponential decay.
    private static func renderTone(
        frequency: Double,
        duration: Double,
        attack: Double,
        decayTau: Double,
        amplitude: Double
    ) -> [Float] {
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        let angularStep = 2 * .pi * frequency / sampleRate

        for index in 0 ..< count {
            let time = Double(index) / sampleRate
            let envelope = (1 - exp(-time / attack)) * exp(-time / decayTau)
            samples[index] = Float(sin(angularStep * Double(index)) * envelope * amplitude)
        }

        return samples
    }

    // MARK: - Mixdown

    private static func mix(layers nested: [[Layer]], targetPeak: Double) -> [Float] {
        let layers = nested.flatMap { $0 }
        let totalCount = layers
            .map { Int($0.startTime * sampleRate) + $0.samples.count }
            .max() ?? 0

        var output = [Float](repeating: 0, count: totalCount)
        for layer in layers {
            let offset = Int(layer.startTime * sampleRate)
            for (index, sample) in layer.samples.enumerated() {
                output[offset + index] += sample
            }
        }

        // Normalize to the target peak so themes sit at a consistent loudness.
        let peak = output.map(abs).max() ?? 0
        if peak > 0 {
            let scale = Float(targetPeak) / peak
            for index in output.indices {
                output[index] *= scale
            }
        }

        // Guarantee a click-free ending regardless of where the decays landed.
        let fadeCount = min(Int(0.010 * sampleRate), output.count)
        for index in 0 ..< fadeCount {
            let position = output.count - fadeCount + index
            output[position] *= Float(1 - Double(index) / Double(fadeCount))
        }

        return output
    }
}

public extension SoundTheme {
    var displayName: String {
        switch self {
        case .aurora: "Aurora"
        case .pulse: "Pulse"
        case .classic: "Classic"
        }
    }
}
