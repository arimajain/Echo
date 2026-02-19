import Foundation
import CoreHaptics
import Combine
import SwiftUI

/// Engine for managing Layer mode tactile blending.
/// Handles texture counts, color blending, and continuous haptic playback.
@MainActor
final class LayerEngine: ObservableObject {
    
    // MARK: - Published State
    
    @Published var deepCount: Int = 0
    @Published var sharpCount: Int = 0
    @Published var rapidCount: Int = 0
    @Published var softCount: Int = 0
    
    @Published var blendedColor: Color = .white.opacity(0.3)
    @Published var glowIntensity: Double = 0.3
    
    // MARK: - Core Haptics Properties
    
    /// Own CHHapticEngine instance - created once, never recreated
    private var hapticEngine: CHHapticEngine?
    
    /// Advanced pattern players - one per active texture (for true blending)
    private var hapticPlayers: [TextureType: CHHapticAdvancedPatternPlayer] = [:]
    
    /// Fallback to shared HapticManager if dedicated engine fails
    private let hapticManager = HapticManager.shared
    
    /// Timers for looping each texture pattern
    private var loopTimers: [TextureType: Timer] = [:]
    
    // MARK: - Configuration
    
    private let maxCountPerTexture = 3
    private let maxTotalLayers = 8
    
    // Color assignments for each texture
    private let deepColor = Color.blue
    private let sharpColor = Color.yellow
    private let rapidColor = Color.purple
    private let softColor = Color.green
    
    // MARK: - Initialization
    
    init() {
        print("LayerEngine: 🚀 Initializing...")
        print("LayerEngine: 📍 Init called on thread")
        
        // Ensure shared HapticManager is prepared first
        hapticManager.prepare()
        print("LayerEngine: 🔧 HapticManager.shared prepared")
        
        setupHapticEngine()
        print("LayerEngine: 🔍 After setupHapticEngine, dedicated engine is: \(hapticEngine != nil ? "✅ Created" : "❌ Nil")")
        
        // Check shared engine availability
        if hapticManager.sharedEngine != nil {
            print("LayerEngine: ✅ Shared engine is available")
        } else {
            print("LayerEngine: ⚠️ Shared engine is also nil")
        }
        
        updateBlendedColor()
        print("LayerEngine: ✅ Initialization complete - Dedicated: \(hapticEngine != nil ? "Ready" : "Nil"), Shared: \(hapticManager.sharedEngine != nil ? "Ready" : "Nil")")
    }
    
    // MARK: - Public API
    
    /// Adds a layer of the specified texture type
    func addLayer(_ texture: TextureType) {
        print("LayerEngine: 👆 addLayer called for texture: \(texture)")
        guard totalLayers < maxTotalLayers else {
            print("LayerEngine: ⚠️ Max total layers reached (\(maxTotalLayers))")
            return
        }
        
        switch texture {
        case .deepPulse:
            if deepCount < maxCountPerTexture {
                deepCount += 1
                print("LayerEngine: ➕ Deep count: \(deepCount)")
            } else {
                print("LayerEngine: ⚠️ Deep count at max (\(maxCountPerTexture))")
            }
        case .sharpTap:
            if sharpCount < maxCountPerTexture {
                sharpCount += 1
                print("LayerEngine: ➕ Sharp count: \(sharpCount)")
            } else {
                print("LayerEngine: ⚠️ Sharp count at max (\(maxCountPerTexture))")
            }
        case .rapidTexture:
            if rapidCount < maxCountPerTexture {
                rapidCount += 1
                print("LayerEngine: ➕ Rapid count: \(rapidCount)")
            } else {
                print("LayerEngine: ⚠️ Rapid count at max (\(maxCountPerTexture))")
            }
        case .softWave:
            if softCount < maxCountPerTexture {
                softCount += 1
                print("LayerEngine: ➕ Soft count: \(softCount)")
            } else {
                print("LayerEngine: ⚠️ Soft count at max (\(maxCountPerTexture))")
            }
        default:
            print("LayerEngine: ⚠️ Unknown texture type")
            break
        }
        
        print("LayerEngine: 📊 Total layers: \(totalLayers)")
        updateBlendedColor()
        updateHapticPattern()
    }
    
    /// Removes a layer of the specified texture type
    func removeLayer(_ texture: TextureType) {
        switch texture {
        case .deepPulse:
            if deepCount > 0 {
                deepCount -= 1
            }
        case .sharpTap:
            if sharpCount > 0 {
                sharpCount -= 1
            }
        case .rapidTexture:
            if rapidCount > 0 {
                rapidCount -= 1
            }
        case .softWave:
            if softCount > 0 {
                softCount -= 1
            }
        default:
            break
        }
        
        updateBlendedColor()
        updateHapticPattern()
    }
    
    /// Clears all layers
    func clearAll() {
        deepCount = 0
        sharpCount = 0
        rapidCount = 0
        softCount = 0
        updateBlendedColor()
        updateHapticPattern()
    }
    
    var totalLayers: Int {
        deepCount + sharpCount + rapidCount + softCount
    }
    
    // MARK: - Core Haptics Setup
    
    /// Creates and starts the haptic engine once
    private func setupHapticEngine() {
        print("LayerEngine: 🔧 Setting up haptic engine...")
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        print("LayerEngine: 📱 Haptics supported: \(capabilities.supportsHaptics)")
        
        guard capabilities.supportsHaptics else {
            print("LayerEngine: ⚠️ Device doesn't support haptics")
            return
        }
        
        do {
            print("LayerEngine: 🔨 Creating CHHapticEngine...")
            hapticEngine = try CHHapticEngine()
            print("LayerEngine: ✅ Engine created successfully")
            
            configureEngineCallbacks()
            print("LayerEngine: 🔧 Engine callbacks configured")
            
            try hapticEngine?.start()
            print("LayerEngine: ✅ Engine started successfully")
        } catch {
            print("LayerEngine: ❌ Failed to create/start engine – \(error.localizedDescription)")
        }
    }
    
    /// Configures engine reset and stop handlers
    private func configureEngineCallbacks() {
        hapticEngine?.stoppedHandler = { [weak self] reason in
            print("LayerEngine: Engine stopped. Reason: \(reason.rawValue)")
            Task { @MainActor in
                self?.restartEngineIfNeeded()
            }
        }
        
        hapticEngine?.resetHandler = { [weak self] in
            print("LayerEngine: Engine reset. Restarting...")
            Task { @MainActor in
                self?.restartEngineIfNeeded()
            }
        }
    }
    
    /// Restarts the engine if it was stopped or reset
    private func restartEngineIfNeeded() {
        guard let engine = hapticEngine else { return }
        do {
            try engine.start()
            // Rebuild pattern if we have active layers
            if totalLayers > 0 {
                updateHapticPattern()
            }
            print("LayerEngine: ✅ Engine restarted")
        } catch {
            print("LayerEngine: ⚠️ Failed to restart engine – \(error.localizedDescription)")
        }
    }
    
    // MARK: - Color Blending
    
    private func updateBlendedColor() {
        let total = totalLayers
        guard total > 0 else {
            blendedColor = .white.opacity(0.3)
            glowIntensity = 0.3
            return
        }
        
        // Calculate weighted average of active texture colors
        var red: Double = 0
        var green: Double = 0
        var blue: Double = 0
        var totalWeight: Double = 0
        
        // Deep Pulse (Blue: 0, 0, 1)
        if deepCount > 0 {
            let weight = Double(deepCount)
            totalWeight += weight
            blue += weight
        }
        
        // Sharp Tap (Yellow: 1, 1, 0)
        if sharpCount > 0 {
            let weight = Double(sharpCount)
            totalWeight += weight
            red += weight
            green += weight
        }
        
        // Rapid Texture (Purple: 0.5, 0, 1)
        if rapidCount > 0 {
            let weight = Double(rapidCount)
            totalWeight += weight
            red += weight * 0.5
            blue += weight
        }
        
        // Soft Wave (Green: 0, 1, 0)
        if softCount > 0 {
            let weight = Double(softCount)
            totalWeight += weight
            green += weight
        }
        
        // Normalize by total weight
        if totalWeight > 0 {
            red /= totalWeight
            green /= totalWeight
            blue /= totalWeight
        }
        
        // Cap brightness to avoid oversaturation
        let maxComponent = max(red, green, blue)
        if maxComponent > 1.0 {
            let scale = 1.0 / maxComponent
            red *= scale
            green *= scale
            blue *= scale
        }
        
        blendedColor = Color(red: red, green: green, blue: blue)
        
        // Glow intensity scales with total layers (capped)
        glowIntensity = min(0.3 + (Double(total) * 0.08), 0.7)
    }
    
    // MARK: - Haptic Pattern Building
    
    /// Rebuilds haptic patterns using the EXACT same patterns as Explore/Builder modes
    private func updateHapticPattern() {
        print("LayerEngine: 🔄 updateHapticPattern called - Total layers: \(totalLayers)")
        
        // Stop all existing players and timers
        stopAllPlayers()
        
        guard totalLayers > 0 else {
            print("LayerEngine: ⚠️ No layers active, skipping pattern update")
            return
        }
        
        // Get engine (dedicated or shared)
        var engine: CHHapticEngine?
        
        if let dedicatedEngine = hapticEngine {
            print("LayerEngine: ✅ Using dedicated engine")
            engine = dedicatedEngine
        } else {
            print("LayerEngine: ⚠️ Dedicated engine is nil, trying shared HapticManager...")
            hapticManager.prepare()
            
            if let sharedEngine = hapticManager.sharedEngine {
                print("LayerEngine: ✅ Using shared HapticManager engine")
                engine = sharedEngine
            } else {
                print("LayerEngine: ⚠️ No haptic engine available (dedicated or shared)")
                print("LayerEngine: 💡 This might be because you're on a simulator. Haptics will work on a real device.")
                print("LayerEngine: 📝 Continuing to show pattern info for debugging...")
                showPatternInfo()
                return
            }
        }
        
        guard let engine = engine else {
            print("LayerEngine: ❌ Engine is still nil after fallback check")
            return
        }
        
        // Ensure engine is running
        do {
            try engine.start()
            print("LayerEngine: ✅ Engine started")
        } catch {
            print("LayerEngine: ⚠️ Failed to start engine – \(error.localizedDescription)")
            return
        }
        
        // Calculate intensity scale for each texture based on its own count
        // Count 1 = base intensity, Count 2 = stronger, Count 3 = strongest
        // Uses absolute scaling so it works even when only one texture type is active
        func intensityScaleForCount(_ count: Int) -> Float {
            switch count {
            case 1: return 1.0      // Base intensity (100%)
            case 2: return 1.3     // 30% stronger
            case 3: return 1.6     // 60% stronger
            default: return 1.0
            }
        }
        
        // Also apply global scaling when multiple different textures are active
        // This prevents overall saturation when many textures are layered
        let activeTextureTypes = (deepCount > 0 ? 1 : 0) + 
                                 (sharpCount > 0 ? 1 : 0) + 
                                 (rapidCount > 0 ? 1 : 0) + 
                                 (softCount > 0 ? 1 : 0)
        
        // When only one texture type is active, don't apply global scaling
        // This ensures count-based scaling is fully effective
        let globalScale: Float = {
            if activeTextureTypes == 1 {
                return 1.0  // No reduction when only one texture type
            }
            switch activeTextureTypes {
            case 2: return 0.85      // Slight reduction when 2 types active
            case 3: return 0.75      // More reduction when 3 types active
            case 4: return 0.65      // Most reduction when all 4 types active
            default: return 1.0
            }
        }()
        
        print("LayerEngine: 🎚️ Active texture types: \(activeTextureTypes), Global scale: \(String(format: "%.2f", globalScale))")
        
        // Play each active texture using its EXACT pattern from HapticPatternLibrary
        // Each texture plays simultaneously, preserving its distinct character
        // Intensity scales with count: more instances = stronger intensity
        let textures: [(TextureType, Int)] = [
            (.deepPulse, deepCount),
            (.sharpTap, sharpCount),
            (.rapidTexture, rapidCount),
            (.softWave, softCount)
        ]
        
        for (texture, count) in textures where count > 0 {
            // Calculate final intensity: count-based scale * global scale
            // Higher count = stronger intensity (absolute scaling)
            let countScale = intensityScaleForCount(count)
            let textureIntensityScale = countScale * globalScale
            print("LayerEngine: 🎚️ \(texture): count=\(count), countScale=\(String(format: "%.2f", countScale)), globalScale=\(String(format: "%.2f", globalScale)), final scale=\(String(format: "%.2f", textureIntensityScale))")
            
            // Use the EXACT same pattern as Explore/Builder modes, with intensity scaled by count
            guard let pattern = try? HapticPatternLibrary.texturePattern(for: texture, baseIntensity: textureIntensityScale) else {
                print("LayerEngine: ⚠️ Failed to create pattern for \(texture)")
                continue
            }
            
            let patternDuration = getPatternDuration(for: texture)
            
            // Play immediately
            do {
                let player = try engine.makeAdvancedPlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
                hapticPlayers[texture] = player
                
                // Loop continuously using timer (same approach as Explore mode)
                let timer = Timer.scheduledTimer(withTimeInterval: patternDuration, repeats: true) { [weak self] timer in
                    Task { @MainActor [weak self] in
                        guard let self = self,
                              self.count(for: texture) > 0 else {
                            timer.invalidate()
                            return
                        }
                        
                        // Get engine (dedicated or shared)
                        guard let engine = self.hapticEngine ?? self.hapticManager.sharedEngine else {
                            timer.invalidate()
                            return
                        }
                        
                        // Calculate current intensity scales (same logic as initial playback)
                        let currentActiveTypes = (self.deepCount > 0 ? 1 : 0) + 
                                                (self.sharpCount > 0 ? 1 : 0) + 
                                                (self.rapidCount > 0 ? 1 : 0) + 
                                                (self.softCount > 0 ? 1 : 0)
                        
                        let currentGlobalScale: Float = {
                            switch currentActiveTypes {
                            case 1: return 1.0
                            case 2: return 0.85
                            case 3: return 0.75
                            case 4: return 0.65
                            default: return 1.0
                            }
                        }()
                        
                        let currentCount = self.count(for: texture)
                        
                        func currentIntensityScaleForCount(_ count: Int) -> Float {
                            switch count {
                            case 1: return 1.0
                            case 2: return 1.3     // 30% stronger
                            case 3: return 1.6     // 60% stronger
                            default: return 1.0
                            }
                        }
                        
                        let currentCountScale = currentIntensityScaleForCount(currentCount)
                        let currentTextureScale = currentCountScale * currentGlobalScale
                        
                        // Replay the pattern with current intensity scale based on count
                        if let pattern = try? HapticPatternLibrary.texturePattern(for: texture, baseIntensity: currentTextureScale) {
                            do {
                                let player = try engine.makeAdvancedPlayer(with: pattern)
                                try player.start(atTime: CHHapticTimeImmediate)
                                // Replace old player
                                try self.hapticPlayers[texture]?.stop(atTime: CHHapticTimeImmediate)
                                self.hapticPlayers[texture] = player
                            } catch {
                                print("LayerEngine: ⚠️ Failed to replay \(texture) – \(error.localizedDescription)")
                            }
                        }
                    }
                }
                loopTimers[texture] = timer
                
                print("LayerEngine: ✅ Started \(texture) pattern (count: \(count))")
            } catch {
                print("LayerEngine: ❌ Failed to start player for \(texture) – \(error.localizedDescription)")
            }
        }
        
        // Debug print
        let activeTextures = [
            (deepCount, "Deep"),
            (sharpCount, "Sharp"),
            (rapidCount, "Rapid"),
            (softCount, "Soft")
        ].filter { count, _ in count > 0 }.map { count, name in "\(name) x\(count)" }.joined(separator: ", ")
        print("🎵 HAPTIC: [Layer Mode] - ✅ Playing patterns: \(activeTextures) (Total: \(totalLayers) layers)")
    }
    
    /// Gets pattern duration for a texture (same as Explore mode)
    private func getPatternDuration(for texture: TextureType) -> TimeInterval {
        switch texture {
        case .deepPulse: return 0.25
        case .sharpTap: return 0.06
        case .rapidTexture: return 0.15
        case .softWave: return 0.6  // Updated to match new duration
        default: return 0.3
        }
    }
    
    /// Shows pattern info even when haptics aren't available (for simulator debugging)
    private func showPatternInfo() {
        let activeTextures = [
            (deepCount, "Deep", 0.25),
            (sharpCount, "Sharp", 0.06),
            (rapidCount, "Rapid", 0.15),
            (softCount, "Soft", 0.6)
        ].filter { count, _, _ in count > 0 }
        
        let textureList = activeTextures.map { count, name, _ in "\(name) x\(count)" }.joined(separator: ", ")
        
        print("🎵 HAPTIC: [Layer Mode] - 📋 Patterns would play: \(textureList) (Total: \(totalLayers) layers)")
        print("🎵 HAPTIC: [Layer Mode] - 📋 Each texture uses its EXACT pattern from HapticPatternLibrary")
        for (count, name, duration) in activeTextures {
            print("🎵 HAPTIC: [Layer Mode] - 📋   \(name) x\(count): duration=\(duration)s (looping)")
        }
    }
    
    
    /// Stops all haptic players and timers
    private func stopAllPlayers() {
        // Stop all players
        for (_, player) in hapticPlayers {
            do {
                try player.stop(atTime: CHHapticTimeImmediate)
            } catch {
                // Ignore stop errors
            }
        }
        hapticPlayers.removeAll()
        
        // Invalidate all timers
        for (_, timer) in loopTimers {
            timer.invalidate()
        }
        loopTimers.removeAll()
    }
    
    deinit {
        // Deinit runs in nonisolated context
        // We can't call @MainActor methods here, so we'll let the system clean up
        // The haptic engine and player will be deallocated automatically
    }
}

// MARK: - Helper Extension

extension LayerEngine {
    func count(for texture: TextureType) -> Int {
        switch texture {
        case .deepPulse: return deepCount
        case .sharpTap: return sharpCount
        case .rapidTexture: return rapidCount
        case .softWave: return softCount
        default: return 0
        }
    }
}
