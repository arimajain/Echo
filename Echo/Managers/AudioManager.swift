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

    /// Global intensity multiplier applied to both haptics and visuals.
    ///
    /// Controlled from the UI (0.5x → 2.0x) to make it easy to test how
    /// distinguishable different patterns feel on different devices.
    @Published var intensityMultiplier: Float = 1.0

    /// Convenience alias used by some visualizers that still refer to the
    /// older `currentAmplitude` naming. This returns the *scaled* amplitude.
    var currentAmplitude: Float {
        let scaled = amplitude * intensityMultiplier
        return max(0.0, min(scaled, 1.0))
    }

    /// Latest structured rhythm event detected from the audio stream.
    ///
    /// Downstream systems (haptics, visuals, rhythm games) should observe this
    /// instead of poking directly at raw waveform data.
    @Published private(set) var lastRhythmEvent: RhythmEvent?

    /// Frequency bands normalized to `0.0 ... 1.0` for visualizers.
    ///
    /// 24 bands evenly distributed across the frequency spectrum:
    /// - Band 0: Lowest frequencies (~20-200 Hz)
    /// - Band 23: Highest frequencies (~8kHz+)
    ///
    /// Updated in real-time during playback. Values are smoothed and normalized
    /// from raw FFT magnitude data.
    @Published private(set) var frequencyBands: [Float] = Array(repeating: 0.0, count: 24)

    /// Currently selected track.
    @Published private(set) var currentTrack: Track?

    /// Available tracks in the library.
    let availableTracks: [Track] = Track.library

    // MARK: - Audio Engine Components

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private var isTapInstalled: Bool = false

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
    
    /// Simulator-only timer that feeds synthetic frequency band values.
    private var simulatorFrequencyBandsTimer: Timer?
    #endif

    /// Timer used to keep ``currentTime`` in sync with the audio engine.
    private var timeTimer: Timer?

    /// Duration of the loaded audio file in seconds.
    private var trackDuration: Double = 0.0

    // MARK: - Frequency Analysis (FFT)

    /// Fixed FFT size for analysis. Must be a power of two.
    /// Increased to 4096 to match buffer size and improve frequency resolution.
    private let fftSize: Int = 4096
    private var fftWindow: [Float] = []
    private var fftInput: [Float] = []
    private var fftReal: [Float] = []
    private var fftImag: [Float] = []
    private var fftMagnitudes: [Float] = []
    private var fftSetup: FFTSetup?
    private var fftLog2n: vDSP_Length = 0
    private var fftInitialized: Bool = false

    /// Frequency band index ranges (in FFT bin indices).
    private var lowBandRange: ClosedRange<Int> = 0...0      // ~20–150 Hz
    private var midBandRange: ClosedRange<Int> = 0...0      // ~150–2500 Hz
    private var highBandRange: ClosedRange<Int> = 0...0     // 2500+ Hz

    /// Frequency band ranges for EchoLineSurface visualization (24 bands).
    /// Computed during FFT setup based on sample rate.
    private var visualizerBandRanges: [ClosedRange<Int>] = []
    
    /// Rolling reference for normalization to prevent compression.
    /// Tracks the maximum energy seen in recent frames for each band.
    private var bandMaxHistory: [Float] = Array(repeating: 0.0, count: 24)
    private var bandMaxDecay: Float = 0.995  // Slow decay to maintain reference

    /// Simple spike detection state for each band.
    private var lastLowEnergy: Float = 0.0
    private var lastMidEnergy: Float = 0.0
    private var lastHighEnergy: Float = 0.0

    /// Relative jump required to treat a band as a "spike".
    private let bandSpikeRatio: Float = 1.6

    /// Absolute floor to avoid triggering on pure noise.
    private let bandMinEnergy: Float = 1e-4

    /// Minimum interval between emitted rhythm events per band.
    private let bandCooldown: TimeInterval = 0.08
    private var lastKickEventTime: Date = .distantPast
    private var lastSnareEventTime: Date = .distantPast
    private var lastHihatEventTime: Date = .distantPast

    // Debug counters
    private var bufferCount: Int = 0
    private var fftProcessCount: Int = 0

    // MARK: - Initialization

    private init() {
        configureAudioSession()
        setupEngine()
        // Load the first track by default.
        if let firstTrack = availableTracks.first {
            loadTrack(firstTrack)
        }
    }

    // MARK: - Setup

    /// Configures the shared `AVAudioSession` for playback.
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            print("AudioManager: ✅ Audio session configured")
        } catch {
            print("AudioManager: ⚠️ Failed to configure audio session – \(error.localizedDescription)")
        }
    }

    /// Attaches the player node to the engine.
    ///
    /// Note: Connections and engine preparation happen in `loadTrack()` after
    /// a file is loaded, since we need the file's format to make connections.
    private func setupEngine() {
        engine.attach(playerNode)
        print("AudioManager: ✅ Player node attached")
    }

    /// Loads a track from the bundle and prepares it for playback.
    ///
    /// - Parameter track: The track to load.
    func loadTrack(_ track: Track) {
        let wasPlaying = isPlaying
        let wasEngineRunning = engine.isRunning

        // Stop playback and engine if running.
        if wasPlaying {
            playerNode.stop()
        }
        if wasEngineRunning {
            engine.stop()
        }

        // Remove existing tap before reconnecting
        if isTapInstalled {
            engine.mainMixerNode.removeTap(onBus: 0)
            isTapInstalled = false
            print("AudioManager: ✅ Removed existing tap")
        }

        // Locate the file in the bundle.
        guard let url = Bundle.main.url(forResource: track.filename, withExtension: "mp3") else {
            print("AudioManager: ⚠️ Could not find \(track.filename).mp3 in bundle.")
            currentTrack = nil
            audioFile = nil
            return
        }

        do {
            audioFile = try AVAudioFile(forReading: url)
            print("AudioManager: ✅ Loaded audio file: \(track.filename).mp3")
        } catch {
            print("AudioManager: ⚠️ Failed to open audio file – \(error.localizedDescription)")
            currentTrack = nil
            audioFile = nil
            return
        }

        guard let file = audioFile else {
            currentTrack = nil
            return
        }

        currentTrack = track

        // Compute track duration for progress-based visuals.
        trackDuration = Double(file.length) / file.processingFormat.sampleRate
        print("AudioManager: ✅ Track duration: \(String(format: "%.2f", trackDuration))s, sample rate: \(file.processingFormat.sampleRate)Hz")

        // Reconnect the player node with the new file's format.
        // AVAudioEngine will replace any existing connection automatically.
        let format = file.processingFormat
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        print("AudioManager: ✅ Connected playerNode to mainMixerNode, format: \(format)")

        // Prepare the engine after connections are made.
        engine.prepare()
        print("AudioManager: ✅ Engine prepared")

        // Restart engine if it was running.
        if wasEngineRunning {
            do {
                try engine.start()
                print("AudioManager: ✅ Engine started")
                // Install tap AFTER engine is started
                installTapIfNeeded()
            } catch {
                print("AudioManager: ⚠️ Failed to restart engine – \(error.localizedDescription)")
            }
        }

        // If we were playing, restart playback.
        if wasPlaying {
            play()
        }
    }

    /// Switches to a different track, stopping current playback if active.
    ///
    /// - Parameter track: The track to switch to.
    func switchTrack(_ track: Track) {
        stop()
        loadTrack(track)
    }

    // MARK: - Tap / Analysis

    /// Installs a tap on the mainMixerNode if not already installed.
    private func installTapIfNeeded() {
        guard !isTapInstalled else {
            print("AudioManager: ℹ️ Tap already installed")
            return
        }
        
        guard engine.isRunning else {
            print("AudioManager: ⚠️ Cannot install tap - engine not running")
            return
        }
        
        #if targetEnvironment(simulator)
        // In simulator, try to install tap but also start synthetic data generator
        print("AudioManager: ℹ️ Simulator - attempting tap installation, will use synthetic data if needed")
        installTap(on: engine.mainMixerNode)
        startSimulatorFrequencyBandsTimer()
        #else
        installTap(on: engine.mainMixerNode)
        #endif
    }

    /// Installs a tap on the provided mixer node to compute RMS amplitude.
    private func installTap(on mixerNode: AVAudioMixerNode) {
        let mixerFormat = mixerNode.outputFormat(forBus: 0)
        print("AudioManager: 📊 Mixer format - sampleRate: \(mixerFormat.sampleRate), channels: \(mixerFormat.channelCount)")
        
        let formatForTap: AVAudioFormat? =
            (mixerFormat.channelCount > 0 && mixerFormat.sampleRate > 0)
            ? mixerFormat
            : nil

        guard let tapFormat = formatForTap else {
            print("AudioManager: ⚠️ Invalid format for tap")
            return
        }

        mixerNode.installTap(
            onBus: 0,
            bufferSize: 4096,  // Increased buffer size for better FFT analysis
            format: tapFormat
        ) { [weak self] buffer, time in
            guard let self else { return }
            self.process(buffer: buffer)
        }
        
        isTapInstalled = true
        print("AudioManager: ✅ Tap installed on mainMixerNode, bufferSize: 4096")
    }

    /// Processes an audio buffer: computes RMS amplitude and detects rhythm events.
    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else {
            print("AudioManager: ⚠️ Buffer has no float channel data")
            return
        }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameCount > 0, channelCount > 0 else {
            print("AudioManager: ⚠️ Invalid buffer: frameCount=\(frameCount), channelCount=\(channelCount)")
            return
        }

        bufferCount += 1
        
        // Debug: Print buffer info occasionally
        if bufferCount % 100 == 0 {
            print("AudioManager: 📊 Buffer #\(bufferCount) - frames: \(frameCount), channels: \(channelCount), sampleRate: \(buffer.format.sampleRate)")
        }

        // Lazily configure FFT on first buffer.
        if !fftInitialized {
            setupFFTIfNeeded(sampleRate: buffer.format.sampleRate)
        }

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

        // Debug: Print amplitude occasionally
        if bufferCount % 100 == 0 {
            print("AudioManager: 📊 RMS: \(String(format: "%.4f", rms)), boosted: \(String(format: "%.4f", boosted))")
        }

        // --- Frequency-domain analysis for rhythm classification -------------
        var detectedEvent: (RhythmType, Float)?
        var visualizerBands: [Float] = Array(repeating: 0.0, count: 24)

        if fftInitialized,
           frameCount >= fftSize {

            // Use the first channel for analysis.
            let firstChannel = channelData[0]

            // Check if channel has non-zero data
            var maxSample: Float = 0.0
            vDSP_maxmgv(firstChannel, 1, &maxSample, vDSP_Length(min(frameCount, fftSize)))
            
            if bufferCount % 100 == 0 {
                print("AudioManager: 📊 Max sample value: \(String(format: "%.4f", maxSample))")
            }

            // Downmix first channel into a fixed-size FFT input buffer.
            // If buffer is larger than fftSize, take the most recent fftSize samples
            // (this gives us the latest audio data for better real-time response)
            let samplesToCopy = min(frameCount, fftSize)
            let sourceOffset = max(0, frameCount - fftSize)  // Take from end of buffer if larger
            
            fftInput.withUnsafeMutableBufferPointer { inputPtr in
                guard let base = inputPtr.baseAddress else { return }
                // Zero out the buffer first
                memset(base, 0, fftSize * MemoryLayout<Float>.size)
                // Copy actual samples from the end of the buffer (most recent)
                let sourcePtr = firstChannel.advanced(by: sourceOffset)
                memcpy(base, sourcePtr, samplesToCopy * MemoryLayout<Float>.size)
            }

            // Apply Hann window to reduce spectral leakage.
            vDSP.multiply(fftWindow, fftInput, result: &fftInput)

            // Real-input FFT using vDSP_fft_zrip.
            if let fftSetup {
                fftInput.withUnsafeBufferPointer { inputPtr in
                    guard let inputBase = inputPtr.baseAddress else { return }

                    fftReal.withUnsafeMutableBufferPointer { realPtr in
                        fftImag.withUnsafeMutableBufferPointer { imagPtr in
                            guard let realBase = realPtr.baseAddress,
                                  let imagBase = imagPtr.baseAddress else { return }

                            var splitComplex = DSPSplitComplex(realp: realBase, imagp: imagBase)

                            // Convert real time-domain samples into split-complex form.
                            inputBase.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                            }

                            // In-place FFT.
                            vDSP_fft_zrip(fftSetup,
                                          &splitComplex,
                                          1,
                                          fftLog2n,
                                          FFTDirection(FFT_FORWARD))

                            // Magnitude squared (energy per bin).
                            vDSP_zvmags(&splitComplex,
                                        1,
                                        &fftMagnitudes,
                                        1,
                                        vDSP_Length(fftSize / 2))
                        }
                    }
                }

                // Check FFT magnitudes
                var maxMagnitude: Float = 0.0
                vDSP_maxmgv(&fftMagnitudes, 1, &maxMagnitude, vDSP_Length(fftSize / 2))
                
                fftProcessCount += 1
                if fftProcessCount % 100 == 0 {
                    print("AudioManager: 📊 FFT #\(fftProcessCount) - max magnitude: \(String(format: "%.6f", maxMagnitude))")
                }

                // Aggregate energy in each band.
                let lowEnergy = bandEnergy(in: lowBandRange)
                let midEnergy = bandEnergy(in: midBandRange)
                let highEnergy = bandEnergy(in: highBandRange)

                // Compute 24 frequency bands for EchoLineSurface.
                if !visualizerBandRanges.isEmpty && visualizerBandRanges.count == 24 {
                    for (index, range) in visualizerBandRanges.enumerated() {
                        guard index < 24 else { break }
                        let energy = bandEnergy(in: range)
                        visualizerBands[index] = energy
                        
                        // Update rolling max for this band (for normalization reference)
                        if energy > bandMaxHistory[index] {
                            bandMaxHistory[index] = energy
                        } else {
                            // Decay the max slowly to adapt to changing levels
                            bandMaxHistory[index] *= bandMaxDecay
                        }
                    }
                    
                    // Normalize each band using its own rolling max reference
                    // This prevents one loud band from compressing all others
                    for i in 0..<visualizerBands.count {
                        let ref = max(bandMaxHistory[i], 1e-6)  // Avoid division by zero
                        let normalized = visualizerBands[i] / ref
                        
                        // Apply power curve for better visibility (less aggressive than sqrt)
                        // Use pow(x, 0.7) to enhance mid-range values
                        let curved = powf(min(normalized, 1.0), 0.7)
                        
                        // Boost the result to make changes more visible
                        let boosted = curved * 1.5
                        
                        // Clamp to 0-1 range
                        visualizerBands[i] = min(max(boosted, 0.0), 1.0)
                    }
                    
                    if fftProcessCount % 100 == 0 {
                        let bandStr = visualizerBands.prefix(8).map { String(format: "%.3f", $0) }.joined(separator: ", ")
                        let maxStr = bandMaxHistory.prefix(8).map { String(format: "%.6f", $0) }.joined(separator: ", ")
                        print("AudioManager: 📊 Normalized bands (first 8): [\(bandStr)...]")
                        print("AudioManager: 📊 Max history (first 8): [\(maxStr)...]")
                    }
                } else {
                    visualizerBands = Array(repeating: 0.0, count: 24)
                    if fftProcessCount % 100 == 0 {
                        print("AudioManager: ⚠️ Visualizer band ranges not initialized")
                    }
                }

                let now = Date()

                // Basic spike detection per band (kick / snare / hihat).
                if isSpike(current: lowEnergy,
                           previous: lastLowEnergy,
                           lastEventTime: lastKickEventTime,
                           now: now) {
                    lastKickEventTime = now
                    detectedEvent = (.kick, normalizedIntensity(from: lowEnergy,
                                                                total: lowEnergy + midEnergy + highEnergy))
                } else if isSpike(current: midEnergy,
                                  previous: lastMidEnergy,
                                  lastEventTime: lastSnareEventTime,
                                  now: now) {
                    lastSnareEventTime = now
                    detectedEvent = (.snare, normalizedIntensity(from: midEnergy,
                                                                 total: lowEnergy + midEnergy + highEnergy))
                } else if isSpike(current: highEnergy,
                                  previous: lastHighEnergy,
                                  lastEventTime: lastHihatEventTime,
                                  now: now) {
                    lastHihatEventTime = now
                    detectedEvent = (.hihat, normalizedIntensity(from: highEnergy,
                                                                 total: lowEnergy + midEnergy + highEnergy))
                }

                // Update history for next-frame comparisons.
                lastLowEnergy = lowEnergy
                lastMidEnergy = midEnergy
                lastHighEnergy = highEnergy
            }
        } else {
            if bufferCount % 100 == 0 {
                print("AudioManager: ⚠️ FFT not initialized or frameCount too small: fftInitialized=\(fftInitialized), frameCount=\(frameCount), fftSize=\(fftSize)")
            }
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.amplitude = boosted
            self.updateBassHitIfNeeded(from: boosted)

            if let (type, intensity) = detectedEvent {
                self.emitRhythmEvent(type: type, intensity: intensity)
            }
            
            // Update frequency bands for visualizers.
            if !visualizerBands.isEmpty {
                self.frequencyBands = visualizerBands
            }
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

        // Emit a structured rhythm event for downstream consumers.
        // For now, we treat strong bass hits as `kick` events; more nuanced
        // classification (snare / hihat / build / drop) can be layered on top
        // in later steps as the detector becomes beat-aware.
        emitRhythmEvent(type: .kick, intensity: amplitude)

        // Auto-reset after a short delay so UI can observe discrete pulses.
        let currentStamp = lastBassHitDate
        DispatchQueue.main.asyncAfter(deadline: .now() + bassHitCooldown) { [weak self] in
            guard let self, self.lastBassHitDate == currentStamp else { return }
            self.isBassHit = false
        }
    }

    /// Records a new `RhythmEvent` at the current playback time.
    private func emitRhythmEvent(type: RhythmType, intensity: Float) {
        let event = RhythmEvent(
            timestamp: currentTime,
            type: type,
            intensity: max(0.0, min(intensity, 1.0))
        )
        lastRhythmEvent = event
    }

    // MARK: - FFT Helpers

    /// Lazily configures the FFT and band index ranges.
    private func setupFFTIfNeeded(sampleRate: Double) {
        guard !fftInitialized else { return }

        print("AudioManager: 🔧 Setting up FFT with sampleRate: \(sampleRate)Hz")

        fftWindow = vDSP.window(ofType: Float.self,
                                usingSequence: .hanningDenormalized,
                                count: fftSize,
                                isHalfWindow: false)
        fftInput = Array(repeating: 0, count: fftSize)
        fftReal = Array(repeating: 0, count: fftSize / 2)
        fftImag = Array(repeating: 0, count: fftSize / 2)
        fftMagnitudes = Array(repeating: 0, count: fftSize / 2)
        fftLog2n = vDSP_Length(log2(Float(fftSize)))
        fftSetup = vDSP_create_fftsetup(fftLog2n, FFTRadix(kFFTRadix2))

        guard fftSetup != nil else {
            print("AudioManager: ⚠️ Failed to create FFT setup")
            return
        }

        // Map frequency bands to FFT bin indices.
        let nyquist = sampleRate / 2.0
        let binResolution = nyquist / Double(fftSize / 2)

        print("AudioManager: 🔧 Nyquist: \(String(format: "%.1f", nyquist))Hz, bin resolution: \(String(format: "%.2f", binResolution))Hz")

        func bandRange(minHz: Double, maxHz: Double) -> ClosedRange<Int> {
            let start = max(0, Int(minHz / binResolution))
            let end = min(fftSize / 2 - 1, Int(maxHz / binResolution))
            return max(start, 0)...max(end, start)
        }

        // Kick: ~20–150 Hz
        lowBandRange = bandRange(minHz: 20, maxHz: 150)
        // Snare: ~150–2500 Hz
        midBandRange = bandRange(minHz: 150, maxHz: 2500)
        // Hihat: 2500 Hz to Nyquist
        highBandRange = bandRange(minHz: 2500, maxHz: nyquist)

        print("AudioManager: 🔧 Rhythm bands - Low: \(lowBandRange), Mid: \(midBandRange), High: \(highBandRange)")

        // Compute 24 evenly-spaced frequency bands for EchoLineSurface.
        // Frequency range: ~20 Hz to Nyquist (typically ~22kHz)
        let minFreq: Double = 20.0
        let maxFreq: Double = nyquist
        let numBands = 24
        let freqStep = (maxFreq - minFreq) / Double(numBands)
        
        visualizerBandRanges = (0..<numBands).map { bandIndex in
            let bandMin = minFreq + Double(bandIndex) * freqStep
            let bandMax = minFreq + Double(bandIndex + 1) * freqStep
            let range = bandRange(minHz: bandMin, maxHz: bandMax)
            if bandIndex < 3 || bandIndex >= numBands - 3 {
                print("AudioManager: 🔧 Band \(bandIndex): \(String(format: "%.1f", bandMin))-\(String(format: "%.1f", bandMax))Hz -> bins \(range)")
            }
            return range
        }
        print("AudioManager: 🔧 Created \(numBands) visualizer bands")

        fftInitialized = (fftSetup != nil)
        print("AudioManager: ✅ FFT initialized: \(fftInitialized)")
    }

    /// Returns mean energy in the given FFT bin range.
    /// Uses sum to preserve energy levels across different band sizes.
    private func bandEnergy(in range: ClosedRange<Int>) -> Float {
        guard fftMagnitudes.indices.contains(range.lowerBound),
              fftMagnitudes.indices.contains(range.upperBound),
              range.lowerBound <= range.upperBound else {
            return 0
        }
        let slice = fftMagnitudes[range]
        // Use sum to preserve energy, then normalize by band width for consistency
        let sum = vDSP.sum(slice)
        let bandWidth = Float(range.upperBound - range.lowerBound + 1)
        return sum / max(bandWidth, 1.0)
    }

    /// Lightweight spike detector for a single band.
    private func isSpike(current: Float,
                         previous: Float,
                         lastEventTime: Date,
                         now: Date) -> Bool {
        guard current > bandMinEnergy else { return false }
        guard current > previous * bandSpikeRatio else { return false }
        guard now.timeIntervalSince(lastEventTime) >= bandCooldown else { return false }
        return true
    }

    /// Normalizes band energy into an event intensity `0...1`.
    private func normalizedIntensity(from bandEnergy: Float, total: Float) -> Float {
        guard total > 0 else { return 0.0 }
        // Emphasize relative contribution of this band.
        let share = bandEnergy / total
        return max(0.0, min(share * 2.0, 1.0))
    }

    // MARK: - Playback Controls

    /// Starts playback from the beginning of the demo track.
    /// Note: AVAudioPlayerNode doesn't support resume - always restarts from beginning.
    func play() {
        #if targetEnvironment(simulator)
        // In the Simulator we allow running without a real audio file and just
        // drive the visuals from the synthetic amplitude timer.
        if audioFile == nil {
            print("AudioManager: ℹ️ Simulator mode – no audio file, using synthetic amplitude only.")
            startAudioEngine()
            Task { @MainActor in
                self.isPlaying = true
            }
            startTimeTimer()
            return
        }
        #endif

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

        // Always reset and reschedule - AVAudioPlayerNode doesn't support resume
        // Stop any existing playback first
        playerNode.stop()
        
        // Reset file position and schedule.
        file.framePosition = 0
        currentTime = 0.0

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
        
        // Install tap if not already installed
        installTapIfNeeded()

        // Update state on main thread BEFORE playing to ensure UI updates immediately
        Task { @MainActor in
            self.isPlaying = true
        }
        
        playerNode.play()
        startTimeTimer()
        print("AudioManager: ✅ Playback started")
    }

    /// Pauses playback without tearing down the engine graph.
    func pause() {
        // Update state on main thread BEFORE pausing to ensure UI updates immediately
        Task { @MainActor in
            self.isPlaying = false
        }
        
        playerNode.pause()
        stopTimeTimer()

        #if targetEnvironment(simulator)
        stopSimulatorAmplitudeTimer()
        stopSimulatorFrequencyBandsTimer()
        #endif
        
        print("AudioManager: ⏸️ Playback paused")
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
        stopSimulatorFrequencyBandsTimer()
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
        // 1. Always start the engine (so we can hear the audio)
        do {
            if !engine.isRunning {
                try engine.start()
                print("AudioManager: ✅ Engine started in startAudioEngine()")
                // Install tap after engine starts
                installTapIfNeeded()
            } else {
                print("AudioManager: ℹ️ Engine already running")
            }
        } catch {
            print("AudioManager: ⚠️ Failed to start engine – \(error.localizedDescription)")
        }

        // 2. If on Simulator, ALSO start the fake data timer (since we have no tap)
        #if targetEnvironment(simulator)
        startSimulatorAmplitudeTimer()
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
    
    /// Starts a timer that feeds synthetic frequency band values for simulator testing.
    private func startSimulatorFrequencyBandsTimer() {
        simulatorFrequencyBandsTimer?.invalidate()
        
            var time: Float = 0.0
            
            simulatorFrequencyBandsTimer = Timer.scheduledTimer(
                withTimeInterval: 1.0 / 60.0,  // 60fps
                repeats: true
            ) { [weak self] _ in
                guard let self else { return }
                
                time += 0.016  // ~60fps
                
                // Generate synthetic frequency bands with varying patterns (24 bands)
                var bands: [Float] = []
                for i in 0..<24 {
                    // Create different patterns for each band
                    let baseFreq = Float(i) * 0.08 + 0.1
                    let variation = sin(time * baseFreq * 2.0) * 0.5 + 0.5
                    // Add some randomness and different patterns per band
                    let pattern = sin(time * (1.0 + Float(i) * 0.15)) * 0.3 + 0.7
                    let value = variation * pattern * Float.random(in: 0.7...1.0)
                    bands.append(min(max(value, 0.0), 1.0))
                }
                
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.frequencyBands = bands
                }
            }
        
        print("AudioManager: ✅ Simulator frequency bands timer started")
    }
    
    /// Stops the simulator frequency bands timer.
    private func stopSimulatorFrequencyBandsTimer() {
        simulatorFrequencyBandsTimer?.invalidate()
        simulatorFrequencyBandsTimer = nil
    }
    #endif
}
