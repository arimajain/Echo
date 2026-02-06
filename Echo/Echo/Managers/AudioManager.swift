import Foundation
import AVFoundation
import Accelerate

// MARK: - AudioManager

/// Central audio engine for Echo.
///
/// `AudioManager`:
/// - Owns a shared `AVAudioEngine` graph with a single `AVAudioPlayerNode`.
/// - Loads a bundled MP3 file (`demo_track.mp3`) and plays it in a loopable fashion.
/// - Installs a tap on the engine's `mainMixerNode` to compute **RMS loudness**
///   in real time and exposes it as a normalized ``amplitude`` property that
///   SwiftUI views can observe.
/// - Publishes a simplified ``isBassHit`` flag on strong low-end hits to drive
///   haptic and visual accents.
@MainActor
final class AudioManager: ObservableObject {

    // MARK: - Singleton

    /// Shared global instance.
    static let shared = AudioManager()

    // MARK: - Published Properties

    /// Current audio amplitude (RMS) normalized into `0.0 ... 1.0`.
    ///
    /// This is the primary value the UI should observe to animate visualizers,
    /// scale pulses, etc.
    @Published var amplitude: Float = 0.0

    /// A transient flag that flips to `true` when a bass-like hit is detected.
    ///
    /// Views can observe this to trigger one-shot effects (e.g. particle bursts
    /// or extra-strong haptic kicks). The flag auto-resets to `false` after a
    /// short debounce interval.
    @Published var isBassHit: Bool = false

    /// Whether the engine is currently playing.
    @Published private(set) var isPlaying: Bool = false

    /// Current playback time (in seconds) for the loaded track.
    ///
    /// This is used by game logic (e.g. `RhythmGameEngine`) to align visual
    /// targets with the audio timeline.
    @Published private(set) var currentTime: Double = 0.0

    /// Normalized playback progress (`0.0` at start, `1.0` at end).
    ///
    /// This is derived from ``currentTime`` and the track duration and is
    /// useful for long-form visuals that evolve across the song.
    var currentProgress: Double {
        guard trackDuration > 0 else { return 0.0 }
        let raw = currentTime / trackDuration
        return min(max(raw, 0.0), 1.0)
    }

    /// Convenience alias used by some visualizers that still refer to the
    /// older `currentAmplitude` naming.
    var currentAmplitude: Float { amplitude }

    // MARK: - Audio Engine Components

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?

    // MARK: - RMS Scaling

    /// Gain multiplier applied to the raw RMS before clamping.
    ///
    /// Typical normalized audio has RMS in the `0.01 ... 0.3` range. A modest
    /// gain helps stretch this into the `0.0 ... 1.0` visual space.
    private let amplitudeGain: Float = 5.0

    /// Threshold above which we consider a frame a \"bass hit\".
    private let bassThreshold: Float = 0.7

    /// Minimum interval between bass hits (seconds).
    private let bassHitCooldown: TimeInterval = 0.12

    private var lastBassHitDate: Date = .distantPast

    #if targetEnvironment(simulator)
    /// Simulator-only timer that feeds synthetic amplitude values into the
    /// pipeline so layout and animation can be tested without real audio.
    private var simulatorAmplitudeTimer: Timer?
    #endif

    /// Timer used to keep ``currentTime`` in sync with the audio engine.
    private var timeTimer: Timer?

    /// Duration of the loaded audio file in seconds.
    private var trackDuration: Double = 0.0

    // MARK: - Initialization

    private init() {
        configureAudioSession()
        setupEngine()
    }

    // MARK: - Setup

    /// Configures the shared `AVAudioSession` for playback.
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("AudioManager: ⚠️ Failed to configure audio session – \(error.localizedDescription)")
        }
    }

    /// Attaches the player node, connects it to the main mixer, installs the
    /// analysis tap, and prepares the engine.
    private func setupEngine() {
        engine.attach(playerNode)

        // Load audio file from bundle.
        guard let url = Self.locateDemoTrackURL() else {
            print("AudioManager: ⚠️ Could not find demo_track.mp3 in bundle.")
            return
        }

        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            print("AudioManager: ⚠️ Failed to open audio file – \(error.localizedDescription)")
            return
        }

        guard let file = audioFile else { return }

        // Compute track duration for progress-based visuals.
        trackDuration = Double(file.length) / file.processingFormat.sampleRate

        let format = file.processingFormat
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        #if !targetEnvironment(simulator)
        // On device we install a real-time analysis tap on the mixer.
        installTap(on: engine.mainMixerNode)
        #else
        // On Simulator we skip the tap entirely. Some configurations can behave
        // unpredictably with Core Audio taps, and for layout work we only need
        // plausible amplitude values, not real analysis.
        #endif

        engine.prepare()
    }

    /// Attempts to locate the demo track in the app bundle.
    ///
    /// - Returns: URL for `demo_track.mp3` or `DemoTrack.mp3` if available.
    private static func locateDemoTrackURL() -> URL? {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: "demo_track", withExtension: "mp3") {
            return url
        }
        // Fallback to previous casing if needed.
        if let url = bundle.url(forResource: "DemoTrack", withExtension: "mp3") {
            return url
        }
        return nil
    }

    // MARK: - Tap / Analysis

    /// Installs a tap on the provided mixer node to compute RMS amplitude.
    private func installTap(on mixerNode: AVAudioMixerNode) {
        let mixerFormat = mixerNode.outputFormat(forBus: 0)
        let formatForTap: AVAudioFormat? =
            (mixerFormat.channelCount > 0 && mixerFormat.sampleRate > 0)
            ? mixerFormat
            : nil

        mixerNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: formatForTap
        ) { [weak self] buffer, _ in
            guard let self else { return }
            self.process(buffer: buffer)
        }
    }

    /// Processes an audio buffer: computes RMS amplitude and detects bass hits.
    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameCount > 0, channelCount > 0 else { return }

        // Compute RMS across all channels using Accelerate for efficiency.
        var totalMeanSquare: Float = 0.0
        for channel in 0..<channelCount {
            var meanSquare: Float = 0.0
            vDSP_measqv(channelData[channel], 1, &meanSquare, vDSP_Length(frameCount))
            totalMeanSquare += meanSquare
        }

        let rms = sqrtf(totalMeanSquare / Float(channelCount))

        // Normalize and apply gain.
        let boosted = min(rms * amplitudeGain, 1.0)

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.amplitude = boosted
            self.updateBassHitIfNeeded(from: boosted)
        }
    }

    /// Implements a simple bass-hit detector using amplitude and a cooldown.
    private func updateBassHitIfNeeded(from amplitude: Float) {
        let now = Date()
        guard amplitude >= bassThreshold,
              now.timeIntervalSince(lastBassHitDate) >= bassHitCooldown else {
            return
        }

        lastBassHitDate = now
        isBassHit = true

        // Auto-reset after a short delay so UI can observe discrete pulses.
        let currentStamp = lastBassHitDate
        DispatchQueue.main.asyncAfter(deadline: .now() + bassHitCooldown) { [weak self] in
            guard let self, self.lastBassHitDate == currentStamp else { return }
            self.isBassHit = false
        }
    }

    // MARK: - Playback Controls

    /// Starts playback from the beginning of the demo track.
    func play() {
        guard let file = audioFile else {
            print("AudioManager: ⚠️ No audio file loaded – cannot play.")
            return
        }

        do {
            // (Re)configure session in case another app changed it.
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            print("AudioManager: ⚠️ Failed to activate audio session – \(error.localizedDescription)")
        }

        // Reset file position and schedule.
        file.framePosition = 0
        playerNode.stop()

        playerNode.scheduleFile(file, at: nil) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPlaying = false
                self.amplitude = 0.0
                self.currentTime = 0.0
                self.stopTimeTimer()
            }
        }

        // Ensure the engine (or simulator fallback) is running.
        startAudioEngine()

        playerNode.play()
        isPlaying = true
        startTimeTimer()
    }

    /// Pauses playback without tearing down the engine graph.
    func pause() {
        playerNode.pause()
        isPlaying = false
        stopTimeTimer()

        #if targetEnvironment(simulator)
        stopSimulatorAmplitudeTimer()
        #endif
    }

    /// Stops playback and resets amplitude to zero.
    func stop() {
        playerNode.stop()
        isPlaying = false
        amplitude = 0.0
        currentTime = 0.0
        isBassHit = false

        #if targetEnvironment(simulator)
        stopSimulatorAmplitudeTimer()
        #endif

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("AudioManager: ⚠️ Failed to deactivate audio session – \(error.localizedDescription)")
        }
    }

    /// Starts the audio engine or, on Simulator, a synthetic amplitude driver.
    ///
    /// On device, this simply starts `AVAudioEngine`. On the Simulator, we
    /// avoid installing any taps and instead drive ``amplitude`` with a
    /// randomized timer so UI elements can be tested without real audio.
    func startAudioEngine() {
        #if targetEnvironment(simulator)
        startSimulatorAmplitudeTimer()
        #else
        do {
            if !engine.isRunning {
                try engine.start()
            }
        } catch {
            print("AudioManager: ⚠️ Failed to start engine – \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Time Tracking

    /// Starts a display-timer that keeps `currentTime` aligned with the
    /// `AVAudioPlayerNode` playback position.
    private func startTimeTimer() {
        timeTimer?.invalidate()

        timeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0,
                                         repeats: true) { [weak self] _ in
            guard let self else { return }
            self.updateCurrentTime()
        }
    }

    /// Stops the time tracking timer.
    private func stopTimeTimer() {
        timeTimer?.invalidate()
        timeTimer = nil
    }

    /// Queries `AVAudioPlayerNode` for the current playback time and updates
    /// the published `currentTime` property.
    private func updateCurrentTime() {
        guard
            let nodeTime = playerNode.lastRenderTime,
            let playerTime = playerNode.playerTime(forNodeTime: nodeTime)
        else {
            return
        }

        let seconds = Double(playerTime.sampleTime) / playerTime.sampleRate
        currentTime = max(0.0, seconds)
    }

    // MARK: - Simulator Amplitude Fallback

    #if targetEnvironment(simulator)
    /// Starts a timer that feeds randomized amplitude values into the pipeline
    /// every 0.05 seconds so UI animations can be tested in the Simulator
    /// without touching live audio taps.
    private func startSimulatorAmplitudeTimer() {
        simulatorAmplitudeTimer?.invalidate()

        simulatorAmplitudeTimer = Timer.scheduledTimer(
            withTimeInterval: 0.05,
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }

            Task { @MainActor [weak self] in
                guard let self else { return }
                let value = Float.random(in: 0.1...0.8)
                self.amplitude = value
                self.updateBassHitIfNeeded(from: value)
            }
        }
    }

    /// Stops the simulator amplitude timer and resets the value.
    private func stopSimulatorAmplitudeTimer() {
        simulatorAmplitudeTimer?.invalidate()
        simulatorAmplitudeTimer = nil
    }
    #endif
}

