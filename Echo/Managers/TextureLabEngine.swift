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
    
    /// Current beat index in pulse cycle (0 = first beat with accent, 1+ = normal beats).
    /// Published for visual feedback in Pulse mode.
    @Published var currentPulseBeat: Int = 0
    
    // MARK: - Properties
    
    private let hapticManager = HapticManager.shared
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
    
    // Pulse & Grouping state
    private var pulseIndex: Int = 0
    private var pulseCount: Int = 4  // Default grouping value
    
    // MARK: - Initialization
    
    init(pattern: PatternModel = PatternModel(stepCount: 16)) {
        self.pattern = pattern
        // Engine is already initialized in HapticManager.shared on app launch
        hapticManager.prepare()
    }
    
    // MARK: - Public API
    
    /// Sets the pattern to play
    /// If currently playing, updates pattern live without stopping playback
    func setPattern(_ newPattern: PatternModel) {
        // Update pattern immediately - timer will read new state on next tick
        pattern = newPattern
        
        // If pattern step count changed while playing, ensure currentStep is valid
        if isPlaying && currentStep >= pattern.steps.count {
            currentStep = currentStep % pattern.steps.count
        }
    }
    
    /// Sets the tempo in BPM
    /// If currently playing, updates tempo live by recreating timer with new interval
    func setTempo(_ bpm: Double) {
        let newTempo = max(20.0, min(120.0, bpm))
        let wasPlaying = isPlaying
        let savedStep = currentStep // Preserve current playhead position
        
        // If playing, we need to recreate timer with new interval
        if wasPlaying {
            playbackTimer?.invalidate()
            playbackTimer = nil
        }
        
        tempo = newTempo
        
        // If was playing, restart timer from same step position
        if wasPlaying {
            currentStep = savedStep // Restore playhead position
            let interval = stepInterval
            playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.playCurrentStep()
                }
            }
        }
    }
    
    /// Sets the shift offset in seconds
    func setShiftOffset(_ offset: TimeInterval) {
        shiftOffset = max(0.0, min(0.1, offset))
    }
    
    /// Enables or disables pattern shifting
    func setShifted(_ shifted: Bool) {
        isShifted = shifted
    }
    
    /// Starts playback
    func play() {
        guard !isPlaying else { return }
        guard pattern.hasContent else { return }
        
        // Ensure no existing timer
        playbackTimer?.invalidate()
        playbackTimer = nil
        
        isPlaying = true
        currentStep = 0
        
        // Calculate step interval based on current tempo
        let interval = stepInterval
        
        // Start timer for step-based playback
        // Only ONE timer exists - it reads pattern state on each tick
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
        guard isPlaying else { return } // Already stopped, nothing to do
        
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        currentStep = 0
        currentPulseBeat = 0
        
        // Also stop any ongoing haptic playback
        hapticManager.stopTexturePattern()
    }
    
    // MARK: - Playback Logic
    
    private func playCurrentStep() {
        guard isPlaying else { return }
        
        // Safely read current pattern state (may have changed since timer was created)
        let stepCount = pattern.steps.count
        guard stepCount > 0 else { return }
        
        // Ensure currentStep is valid (handles pattern size changes)
        if currentStep >= stepCount {
            currentStep = currentStep % stepCount
        }
        
        // Read step state at this moment (pattern may have been edited)
        let step = pattern.steps[currentStep]
        let textures = Array(step.textures).filter { $0 != .none }
        
        // Play the textures if any are active
        if !textures.isEmpty {
            // Calculate timing with optional shift
            let playTime: TimeInterval
            
            if isShifted {
                // Apply shift offset (forward or backward)
                let offset = shiftOffset * (currentStep % 2 == 0 ? 1.0 : -1.0)  // Alternate direction
                playTime = offset
            } else {
                playTime = CHHapticTimeImmediate
            }
            
            // Play all textures assigned to this step as a single combined pattern
            playCombinedTextures(textures, at: playTime)
        }
        
        // Advance to next step immediately (no delay - timer handles timing)
        advanceStep()
    }
    
    private func advanceStep() {
        // Wrap around based on current pattern size
        let stepCount = pattern.steps.count
        guard stepCount > 0 else { return }
        currentStep = (currentStep + 1) % stepCount
    }
    
    /// Plays one or more textures for a single pattern step.
    /// All textures play simultaneously at the same time for proper blending.
    private func playCombinedTextures(_ textures: [TextureType], at time: TimeInterval) {
        guard !textures.isEmpty else { return }
        
        // Global scaling: reduce intensity when multiple textures are active
        let count = textures.count
        let globalScale: Float
        switch count {
        case 1:
            globalScale = 1.0
        case 2:
            globalScale = 0.85
        case 3:
            globalScale = 0.75
        default: // 4 textures
            globalScale = 0.65
        }
        
        // Play all textures simultaneously using shared engine
        guard let engine = hapticManager.sharedEngine else { return }
        
        // Ensure engine is running
        hapticManager.prepare()
        
        // Start all patterns at the exact same time (CHHapticTimeImmediate)
        for texture in textures {
            guard let pattern = try? HapticPatternLibrary.texturePattern(for: texture, baseIntensity: globalScale) else {
                continue
            }
            
            do {
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
            } catch {
                print("TextureLabEngine: ⚠️ Failed to play \(texture) – \(error.localizedDescription)")
            }
        }
        
        let textureNames = textures.map { $0.displayName }.joined(separator: "+")
        print("🎵 HAPTIC: [Builder Step \(currentStep + 1)] - Combined: \(textureNames)")
    }
    
    // MARK: - Pulse & Grouping Mode
    
    /// Plays pulse & grouping pattern where cycle length = pulse count.
    /// The cycle resets after pulseCount beats, creating structural grouping.
    ///
    /// - Parameter texture: Texture to play
    /// - Parameter pulseCount: Number of beats in one repeating cycle (3, 4, 5, or 7)
    /// - Parameter bpm: Tempo in beats per minute
    func playPulsePattern(texture: TextureType, pulseCount: Int, bpm: Double) {
        stop()  // Stop any existing playback
        
        isPlaying = true
        
        // Store pulse count for use in playTextureWithAccent
        self.pulseCount = pulseCount
        
        // Calculate beat interval: 60 seconds / BPM
        let beatInterval = 60.0 / bpm
        
        // Reset pulse index to 0 (first beat of cycle)
        pulseIndex = 0
        currentPulseBeat = 0  // Update published state for visual feedback
        
        // Play first beat immediately with ACCENT (beat 0 = first beat of cycle)
        playTextureWithAccent(texture, isAccent: true)
        // Don't increment yet - let the timer handle the progression
        
        guard pulseCount > 1 else {
            // Only one pulse needed, continuously loop with accent
            playbackTimer = Timer.scheduledTimer(withTimeInterval: beatInterval, repeats: true) { [weak self] timer in
                Task { @MainActor [weak self] in
                    guard let self, self.isPlaying else {
                        timer.invalidate()
                        return
                    }
                    // Always accent for single pulse (it's always the first beat)
                    self.playTextureWithAccent(texture, isAccent: true)
                }
            }
            return
        }
        
        // Play remaining pulses in cycle, then loop
        playbackTimer = Timer.scheduledTimer(withTimeInterval: beatInterval, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else {
                    timer.invalidate()
                    return
                }
                
                // Move to next beat
                self.pulseIndex += 1
                
                // If we've completed the cycle, reset to start
                if self.pulseIndex >= pulseCount {
                    self.pulseIndex = 0
                }
                
                // Check if this is the first beat of the cycle (beatIndex == 0)
                let isFirstBeat = self.pulseIndex == 0
                
                // Update published state for visual feedback
                self.currentPulseBeat = self.pulseIndex
                
                // Play with accent on first beat, normal intensity on others
                self.playTextureWithAccent(texture, isAccent: isFirstBeat)
            }
        }
    }
    
    /// Plays a texture with optional accent (higher intensity for first beat of cycle).
    private func playTextureWithAccent(_ texture: TextureType, isAccent: Bool) {
        // Accent: 0.9 intensity - subtly stronger to mark cycle start
        // Normal: 0.75 intensity - slightly softer but still cohesive
        // This creates perceptible grouping without feeling like different textures
        let intensityScale: Float = isAccent ? 0.9 : 0.75
        
        guard let hapticPattern = try? HapticPatternLibrary.texturePattern(for: texture, baseIntensity: intensityScale) else {
            return
        }
        
        // Use shared engine from HapticManager
        let textureName = "Pulse Beat \(currentPulseBeat + 1)/\(pulseCount) - \(texture.displayName)\(isAccent ? " [ACCENT]" : "")"
        _ = hapticManager.playTexturePattern(hapticPattern, name: textureName)
    }
    
    deinit {
        // Clean up timer directly since deinit cannot call @MainActor methods
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
}
