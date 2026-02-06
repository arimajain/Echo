import Foundation
import CoreHaptics

// MARK: - HapticManager

/// Centralized Core Haptics controller for Echo.
///
/// `HapticManager` owns a single `CHHapticEngine` instance, exposes a small
/// set of high-level APIs for dynamic beat-driven vibration, and gracefully
/// falls back to console logging when haptics are unavailable (Simulator,
/// certain iPad models, or older devices).
///
/// The manager:
/// - Checks hardware capabilities via ``supportsHaptics``.
/// - Starts and maintains a `CHHapticEngine`, recovering from resets.
/// - Provides:
///   - ``playDynamicVibration(frequency:intensity:)`` for real-time mapping
///     from audio features (frequency / amplitude) into haptic texture.
///   - ``playComplexPattern()`` for a layered \"thud + fizz\" subwoofer feel.
///
/// All public APIs are safe to call from the main thread only.
@MainActor
final class HapticManager: ObservableObject {

    // MARK: - Singleton

    /// Shared global instance.
    static let shared = HapticManager()

    // MARK: - Engine State

    /// Core Haptics engine backing all haptic playback.
    private var engine: CHHapticEngine?

    /// Advanced player used for continuous \"texture\" patterns in the Texture Lab.
    private var texturePlayer: CHHapticAdvancedPatternPlayer?

    /// Whether the current device supports Core Haptics.
    ///
    /// - Note: This will be `false` on the Simulator and some iPad models.
    let supportsHaptics: Bool

    // MARK: - Initialization

    /// Private to enforce singleton usage.
    private init() {
        #if targetEnvironment(simulator)
        // Simulator never supports Core Haptics.
        self.supportsHaptics = false
        print("HapticManager: Running in Simulator – haptics will be simulated via console logs.")
        #else
        self.supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        #endif

        guard supportsHaptics else {
            // On unsupported hardware we simply no-op all play requests.
            return
        }

        do {
            engine = try CHHapticEngine()
            configureEngineCallbacks()
            try engine?.start()
            print("HapticManager: Engine started.")
        } catch {
            print("HapticManager: ⚠️ Failed to start haptic engine – \(error.localizedDescription)")
            engine = nil
        }
    }

    // MARK: - Public API

    /// Prepares the underlying haptic engine so the first play call is as
    /// responsive as possible. Safe to call multiple times.
    func prepare() {
        _ = prepareEngineIfNeeded() || true
    }

    /// Plays a single beat-aligned vibration whose **texture** is determined
    /// by audio frequency and amplitude.
    ///
    /// - Parameters:
    ///   - frequency: A normalized spectral centroid (`0.0 ... 1.0`).
    ///     - `0.0` → low/bass → dull, heavy rumble.
    ///     - `1.0` → high/treble → crisp, sharp click.
    ///   - intensity: A normalized loudness / amplitude (`0.0 ... 1.0`).
    ///
    /// Internally this maps:
    /// - `frequency` → `CHHapticEventParameterID.hapticSharpness`
    /// - `intensity` → `CHHapticEventParameterID.hapticIntensity`
    ///
    /// The event type is `.hapticTransient` so it feels like a clear beat hit.
    func playDynamicVibration(frequency: Float, intensity: Float) {
        guard prepareEngineIfNeeded() else {
            simulateHaptic()
            return
        }

        // Map frequency to sharpness — keep a small floor so even bass hits
        // feel present, not completely mushy.
        let clampedFrequency = Self.clamp(frequency)
        let sharpnessValue: Float = max(0.1, clampedFrequency)

        let clampedIntensity = Self.clamp(intensity)

        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness,
                                                    value: sharpnessValue)
        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity,
                                                    value: clampedIntensity)

        let event = CHHapticEvent(eventType: .hapticTransient,
                                  parameters: [sharpnessParam, intensityParam],
                                  relativeTime: 0)

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("HapticManager: ⚠️ Failed to play dynamic vibration – \(error.localizedDescription)")
        }
    }

    /// Plays one of the educational \"texture\" examples used in the Texture Lab.
    ///
    /// - Parameter type: The high-level texture category to render.
    func playTexture(type: TextureType) {
        guard prepareEngineIfNeeded() else {
            simulateHaptic()
            return
        }

        // Stop any existing continuous texture playback before starting anew.
        stopTexture()

        switch type {
        case .smooth:
            playSmoothTexture()
        case .rough:
            playRoughTexture()
        case .sharp:
            playSharpTexture()
        }
    }

    /// Stops any in-progress continuous texture playback.
    func stopTexture() {
        guard let texturePlayer else { return }
        do {
            try texturePlayer.stop(atTime: CHHapticTimeImmediate)
        } catch {
            print("HapticManager: ⚠️ Failed to stop texture player – \(error.localizedDescription)")
        }
        self.texturePlayer = nil
    }

    /// Plays a short, layered \"thud + fizz\" pattern that approximates the feel
    /// of a subwoofer cone moving air:
    ///
    /// 1. A **strong, dull thud** (low sharpness, high intensity) at `t = 0`.
    /// 2. A **faint, crisp fizz** (high sharpness, low intensity) at `t = 0.01 s`.
    ///
    /// This slight temporal offset gives the sensation of weight followed by
    /// high-frequency texture — similar to how real-world bass often feels.
    func playComplexPattern() {
        guard prepareEngineIfNeeded() else {
            simulateHaptic()
            return
        }

        // Thud: heavy, dull, immediate.
        let thudIntensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                                   value: 1.0)
        let thudSharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                                   value: 0.15)
        let thud = CHHapticEvent(eventType: .hapticTransient,
                                 parameters: [thudIntensity, thudSharpness],
                                 relativeTime: 0.0)

        // Fizz: light, crisp, trailing just behind the thud.
        let fizzIntensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                                   value: 0.35)
        let fizzSharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                                   value: 0.9)
        let fizz = CHHapticEvent(eventType: .hapticTransient,
                                 parameters: [fizzIntensity, fizzSharpness],
                                 relativeTime: 0.01)

        do {
            let pattern = try CHHapticPattern(events: [thud, fizz], parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("HapticManager: ⚠️ Failed to play complex pattern – \(error.localizedDescription)")
        }
    }

    // MARK: - Engine Management

    /// Ensures the engine exists and is running before attempting playback.
    ///
    /// - Returns: `true` if haptics can be played, `false` otherwise.
    private func prepareEngineIfNeeded() -> Bool {
        guard supportsHaptics else {
            return false
        }

        if engine == nil {
            do {
                engine = try CHHapticEngine()
                configureEngineCallbacks()
            } catch {
                print("HapticManager: ⚠️ Failed to recreate engine – \(error.localizedDescription)")
                return false
            }
        }

        do {
            // `CHHapticEngine` does not expose an `isRunning` flag; it's safe
            // to simply call `start()` and let Core Haptics no-op if the
            // engine is already running.
            try engine?.start()
            return true
        } catch {
            print("HapticManager: ⚠️ Failed to start engine – \(error.localizedDescription)")
            return false
        }
    }

    /// Sets up handlers for engine stop/reset so we can recover gracefully
    /// when the app goes to the background or the audio session changes.
    private func configureEngineCallbacks() {
        engine?.stoppedHandler = { reason in
            print("HapticManager: Engine stopped. Reason: \(reason.rawValue)")
        }

        engine?.resetHandler = { [weak self] in
            guard let self else { return }
            print("HapticManager: Engine reset. Attempting restart…")
            do {
                try self.engine?.start()
                print("HapticManager: Engine restarted after reset.")
            } catch {
                print("HapticManager: ⚠️ Failed to restart engine – \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    /// Prints a simulated haptic message for unsupported hardware / Simulator.
    private func simulateHaptic() {
        print("Haptic simulated")
    }

    /// Clamps a normalized `Float` into the `0.0 ... 1.0` range.
    private static func clamp(_ value: Float) -> Float {
        max(0.0, min(1.0, value))
    }

    // MARK: - Texture Implementations

    /// Smooth, continuous vibration (sine-like).
    ///
    /// - Event: `.hapticContinuous`
    /// - Intensity: 0.6
    /// - Sharpness: 0.2
    private func playSmoothTexture() {
        do {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                                   value: 0.6)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                                   value: 0.2)

            // Use a reasonably long duration; the user will typically release
            // the button before this naturally ends.
            let duration: TimeInterval = 2.0
            let event = CHHapticEvent(eventType: .hapticContinuous,
                                      parameters: [intensity, sharpness],
                                      relativeTime: 0,
                                      duration: duration)

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            texturePlayer = try engine?.makeAdvancedPlayer(with: pattern)
            try texturePlayer?.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("HapticManager: ⚠️ Failed to play smooth texture – \(error.localizedDescription)")
        }
    }

    /// Rough, gritty continuous vibration (distortion-like).
    ///
    /// - Event: `.hapticContinuous`
    /// - Intensity: 0.8
    /// - Sharpness: 1.0
    /// - Modulation: Rapid intensity jitter via `CHHapticParameterCurve`.
    private func playRoughTexture() {
        do {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                                   value: 0.8)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                                   value: 1.0)

            let duration: TimeInterval = 1.5
            let event = CHHapticEvent(eventType: .hapticContinuous,
                                      parameters: [intensity, sharpness],
                                      relativeTime: 0,
                                      duration: duration)

            // Build a jittery intensity curve to simulate grit / distortion.
            var controlPoints: [CHHapticParameterCurve.ControlPoint] = []
            let steps = 24
            for step in 0...steps {
                let t = Double(step) / Double(steps) * duration
                // Fast, noisy modulation around 0.8 ± 0.2.
                let jitter = sin(2 * Double.pi * 8 * t) * 0.2
                let value = Float(0.8 + jitter)
                controlPoints.append(.init(relativeTime: t, value: value))
            }

            let curve = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: controlPoints,
                relativeTime: 0
            )

            let pattern = try CHHapticPattern(
                events: [event],
                parameterCurves: [curve]
            )

            texturePlayer = try engine?.makeAdvancedPlayer(with: pattern)
            try texturePlayer?.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("HapticManager: ⚠️ Failed to play rough texture – \(error.localizedDescription)")
        }
    }

    /// Sharp, percussive tap (kick-drum-like).
    ///
    /// - Event: `.hapticTransient`
    /// - Intensity: 1.0
    /// - Sharpness: 0.8
    private func playSharpTexture() {
        guard let engine = engine else { return }

        do {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                                   value: 1.0)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                                   value: 0.8)

            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: 0
            )

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("HapticManager: ⚠️ Failed to play sharp texture – \(error.localizedDescription)")
        }
    }
}

