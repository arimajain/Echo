import Foundation
import CoreHaptics
import Combine
import UIKit

/// Engine for managing Texture Lab pattern playback with precise timing.
@MainActor
final class TextureLabEngine: ObservableObject {
    
    // MARK: - Published State
    
    @Published var isPlaying: Bool = false
    @Published var currentStep: Int = 0
    
    // MARK: - Properties
    
    private let hapticManager = HapticManager.shared
    private var engine: CHHapticEngine?
    private var playbackTimer: Timer?
    private var pattern: PatternModel
    private var tempo: Double = 120.0  // BPM
    
    /// Calculates the step interval based on current tempo and pattern length
    private var stepInterval: TimeInterval {
        // For 4/4 time: 4 beats per measure
        // Each step is 1/4 of a beat (assuming 16 steps = 4 beats)
        let beatsPerMeasure = 4.0
        let stepsPerMeasure = Double(pattern.stepCount)
        let beatsPerStep = beatsPerMeasure / stepsPerMeasure
        return 60.0 / tempo * beatsPerStep
    }
    
    // MARK: - Playback State
    
    private var isShifted: Bool = false
    private var shiftOffset: TimeInterval = 0.045  // 45ms default
    private var density: Int = 1
    
    // MARK: - Initialization
    
    init(pattern: PatternModel = PatternModel(stepCount: 16)) {
        self.pattern = pattern
        setupEngine()
    }
    
    // MARK: - Engine Setup
    
    private func setupEngine() {
        guard hapticManager.supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("TextureLabEngine: ⚠️ Failed to start engine – \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public API
    
    /// Sets the pattern to play
    func setPattern(_ newPattern: PatternModel) {
        let wasPlaying = isPlaying
        stop()
        pattern = newPattern
        if wasPlaying {
            play()
        }
    }
    
    /// Sets the tempo in BPM
    func setTempo(_ bpm: Double) {
        tempo = max(40.0, min(200.0, bpm))
        // Note: For pattern builder mode, tempo change will take effect on next play
    }
    
    /// Sets the shift offset in seconds
    func setShiftOffset(_ offset: TimeInterval) {
        shiftOffset = max(0.0, min(0.1, offset))
    }
    
    /// Enables or disables pattern shifting
    func setShifted(_ shifted: Bool) {
        isShifted = shifted
    }
    
    /// Sets the density (pulses per measure)
    func setDensity(_ newDensity: Int) {
        density = max(1, min(8, newDensity))
    }
    
    /// Starts playback
    func play() {
        guard !isPlaying else { return }
        guard pattern.hasContent else { return }
        
        isPlaying = true
        currentStep = 0
        
        // Calculate step interval based on current tempo
        let interval = stepInterval
        
        // Start timer for step-based playback
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.playCurrentStep()
            }
        }
        
        // Play first step immediately
        playCurrentStep()
    }
    
    /// Stops playback
    func stop() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        currentStep = 0
    }
    
    // MARK: - Playback Logic
    
    private func playCurrentStep() {
        guard isPlaying else { return }
        guard currentStep < pattern.steps.count else {
            // Loop back to start
            currentStep = 0
            return
        }
        
        let step = pattern.steps[currentStep]
        
        // Skip if texture is none
        guard step.texture != .none else {
            advanceStep()
            return
        }
        
        // Calculate timing with optional shift
        let playTime: TimeInterval
        
        if isShifted {
            // Apply shift offset (forward or backward)
            let offset = shiftOffset * (currentStep % 2 == 0 ? 1.0 : -1.0)  // Alternate direction
            playTime = offset
        } else {
            playTime = CHHapticTimeImmediate
        }
        
        // Play the texture
        playTexture(step.texture, at: playTime)
        
        advanceStep()
    }
    
    private func advanceStep() {
        currentStep = (currentStep + 1) % pattern.steps.count
    }
    
    private func playTexture(_ texture: TextureType, at time: TimeInterval) {
        guard let hapticPattern = try? HapticPatternLibrary.texturePattern(for: texture, baseIntensity: 1.0) else {
            return
        }
        
        guard let engine = engine else {
            setupEngine()
            return
        }
        
        do {
            let player = try engine.makePlayer(with: hapticPattern)
            try player.start(atTime: time)
        } catch {
            print("TextureLabEngine: ⚠️ Failed to play texture – \(error.localizedDescription)")
        }
    }
    
    // MARK: - Pulse & Grouping Mode
    
    /// Plays a single texture at the specified interval (for pulse & grouping mode)
    func playPulsePattern(texture: TextureType, pulseCount: Int, interval: TimeInterval) {
        stop()  // Stop any existing playback
        
        isPlaying = true
        var pulseIndex = 0
        
        // Play first pulse immediately
        playTexture(texture, at: CHHapticTimeImmediate)
        pulseIndex = 1
        
        guard pulseIndex < pulseCount else {
            // Only one pulse needed
            stop()
            return
        }
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self else {
                    timer.invalidate()
                    return
                }
                
                self.playTexture(texture, at: CHHapticTimeImmediate)
                pulseIndex += 1
                
                if pulseIndex >= pulseCount {
                    timer.invalidate()
                    self.stop()
                }
            }
        }
    }
    
    // MARK: - Density Mode
    
    /// Plays density-based pattern (pulses per measure)
    func playDensityPattern(texture: TextureType, density: Int, measureDuration: TimeInterval) {
        stop()  // Stop any existing playback
        
        isPlaying = true
        let pulseInterval = measureDuration / Double(density)
        var pulseCount = 0
        
        // Play first pulse immediately
        playTexture(texture, at: CHHapticTimeImmediate)
        pulseCount = 1
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: pulseInterval, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self else {
                    timer.invalidate()
                    return
                }
                
                self.playTexture(texture, at: CHHapticTimeImmediate)
                pulseCount += 1
                
                if pulseCount >= density {
                    pulseCount = 0  // Reset for next measure
                }
            }
        }
    }
    
    deinit {
        // Clean up timer directly since deinit cannot call @MainActor methods
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
}
