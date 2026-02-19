import Foundation

/// A musically structured preset pattern for Builder mode.
/// Each preset demonstrates a clear rhythmic or layering concept.
struct BuilderPreset: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let pattern: [Set<TextureType>] // 16 steps
    
    /// Creates a preset with the given name, description, and 16-step pattern.
    init(name: String, description: String, pattern: [Set<TextureType>]) {
        self.name = name
        self.description = description
        // Ensure pattern is exactly 16 steps
        if pattern.count == 16 {
            self.pattern = pattern
        } else {
            // Pad or truncate to 16 steps
            var adjusted = pattern
            while adjusted.count < 16 {
                adjusted.append([])
            }
            self.pattern = Array(adjusted.prefix(16))
        }
    }
    
    /// Converts preset pattern to PatternModel
    func toPatternModel() -> PatternModel {
        var model = PatternModel(stepCount: 16)
        for (index, textures) in pattern.enumerated() {
            model.steps[index].textures = textures
        }
        return model
    }
}

/// Library of musically structured presets for Builder mode.
struct BuilderPresetLibrary {
    static let allPresets: [BuilderPreset] = [
        foundation,
        syncopation,
        layerBuild,
        callAndResponse,
        minimalPulse,
        fullTexture
    ]
    
    // MARK: - Preset Definitions
    
    /// Foundation: Downbeat anchor
    /// Deep on steps 0,4,8,12. Sharp also on 4 and 12.
    static let foundation = BuilderPreset(
        name: "Foundation",
        description: "Downbeat anchor with accent hits",
        pattern: [
            [.deepPulse],           // 0
            [],                     // 1
            [],                     // 2
            [],                     // 3
            [.deepPulse, .sharpTap], // 4
            [],                     // 5
            [],                     // 6
            [],                     // 7
            [.deepPulse],           // 8
            [],                     // 9
            [],                     // 10
            [],                     // 11
            [.deepPulse, .sharpTap], // 12
            [],                     // 13
            [],                     // 14
            []                      // 15
        ]
    )
    
    /// Syncopation: Off-beat rhythm
    /// Deep on 0,8. Rapid on 2,6,10,14. Sharp on 4.
    static let syncopation = BuilderPreset(
        name: "Syncopation",
        description: "Off-beat rhythm with shifting accents",
        pattern: [
            [.deepPulse],           // 0
            [],                     // 1
            [.rapidTexture],        // 2
            [],                     // 3
            [.sharpTap],            // 4
            [],                     // 5
            [.rapidTexture],        // 6
            [],                     // 7
            [.deepPulse],           // 8
            [],                     // 9
            [.rapidTexture],        // 10
            [],                     // 11
            [],                     // 12
            [],                     // 13
            [.rapidTexture],        // 14
            []                      // 15
        ]
    )
    
    /// Layer Build: Gradual intensity increase
    /// Steps 0-3: Deep. 4-7: Deep + Sharp. 8-11: Deep + Sharp + Rapid. 12-15: All textures.
    static let layerBuild = BuilderPreset(
        name: "Layer Build",
        description: "Gradual intensity increase through texture stacking",
        pattern: [
            [.deepPulse],                           // 0
            [.deepPulse],                           // 1
            [.deepPulse],                           // 2
            [.deepPulse],                           // 3
            [.deepPulse, .sharpTap],                // 4
            [.deepPulse, .sharpTap],                // 5
            [.deepPulse, .sharpTap],                // 6
            [.deepPulse, .sharpTap],                // 7
            [.deepPulse, .sharpTap, .rapidTexture], // 8
            [.deepPulse, .sharpTap, .rapidTexture], // 9
            [.deepPulse, .sharpTap, .rapidTexture], // 10
            [.deepPulse, .sharpTap, .rapidTexture], // 11
            [.deepPulse, .sharpTap, .rapidTexture, .softWave], // 12
            [.deepPulse, .sharpTap, .rapidTexture, .softWave], // 13
            [.deepPulse, .sharpTap, .rapidTexture, .softWave], // 14
            [.deepPulse, .sharpTap, .rapidTexture, .softWave]  // 15
        ]
    )
    
    /// Call & Response: Alternating groups
    /// 0-3: Deep. 4-7: Soft + Rapid. 8-11: Deep. 12-15: Soft + Rapid.
    static let callAndResponse = BuilderPreset(
        name: "Call & Response",
        description: "Alternating texture groups in dialogue",
        pattern: [
            [.deepPulse],                    // 0
            [.deepPulse],                    // 1
            [.deepPulse],                    // 2
            [.deepPulse],                    // 3
            [.softWave, .rapidTexture],     // 4
            [.softWave, .rapidTexture],     // 5
            [.softWave, .rapidTexture],     // 6
            [.softWave, .rapidTexture],     // 7
            [.deepPulse],                    // 8
            [.deepPulse],                    // 9
            [.deepPulse],                    // 10
            [.deepPulse],                    // 11
            [.softWave, .rapidTexture],     // 12
            [.softWave, .rapidTexture],     // 13
            [.softWave, .rapidTexture],     // 14
            [.softWave, .rapidTexture]      // 15
        ]
    )
    
    /// Minimal Pulse: Sparse structure
    /// Deep on 0 and 8. Soft on 4. Everything else empty.
    static let minimalPulse = BuilderPreset(
        name: "Minimal Pulse",
        description: "Sparse structure with breathing space",
        pattern: [
            [.deepPulse],           // 0
            [],                     // 1
            [],                     // 2
            [],                     // 3
            [.softWave],            // 4
            [],                     // 5
            [],                     // 6
            [],                     // 7
            [.deepPulse],           // 8
            [],                     // 9
            [],                     // 10
            [],                     // 11
            [],                     // 12
            [],                     // 13
            [],                     // 14
            []                      // 15
        ]
    )
    
    /// Full Texture: Dense tactile chord hits
    /// Every 4th step: All textures active. Other steps: Rapid only.
    static let fullTexture = BuilderPreset(
        name: "Full Texture",
        description: "Dense tactile chord hits with rapid fills",
        pattern: [
            [.deepPulse, .sharpTap, .rapidTexture, .softWave], // 0
            [.rapidTexture],                                    // 1
            [.rapidTexture],                                    // 2
            [.rapidTexture],                                    // 3
            [.deepPulse, .sharpTap, .rapidTexture, .softWave], // 4
            [.rapidTexture],                                    // 5
            [.rapidTexture],                                    // 6
            [.rapidTexture],                                    // 7
            [.deepPulse, .sharpTap, .rapidTexture, .softWave], // 8
            [.rapidTexture],                                    // 9
            [.rapidTexture],                                    // 10
            [.rapidTexture],                                    // 11
            [.deepPulse, .sharpTap, .rapidTexture, .softWave], // 12
            [.rapidTexture],                                    // 13
            [.rapidTexture],                                    // 14
            [.rapidTexture]                                     // 15
        ]
    )
}
