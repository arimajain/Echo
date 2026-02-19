import Foundation

/// Represents a single step in a pattern grid.
///
/// Each step can hold 0-4 textures (one per quadrant) which will be
/// blended together when the step is triggered.
struct PatternStep: Identifiable, Equatable {
    let id: Int
    
    /// Textures assigned to this step (Set ensures uniqueness, order doesn't matter).
    /// Empty set means step is "off".
    var textures: Set<TextureType>
    
    init(id: Int, textures: Set<TextureType> = []) {
        self.id = id
        // Filter out .none if somehow included
        self.textures = textures.filter { $0 != .none }
    }
    
    /// Whether the step has any active textures.
    var isEmpty: Bool {
        textures.isEmpty
    }
    
    /// Toggles a texture in this step.
    mutating func toggle(_ texture: TextureType) {
        guard texture != .none else { return }
        if textures.contains(texture) {
            textures.remove(texture)
        } else {
            // Max 4 textures (one per quadrant)
            if textures.count < 4 {
                textures.insert(texture)
            }
        }
    }
}

/// Model for storing and managing tactile patterns in the Texture Lab.
struct PatternModel: Equatable {
    /// Number of steps in the pattern (8 or 16)
    let stepCount: Int
    
    /// Array of steps, each with one or more texture assignments
    var steps: [PatternStep]
    
    /// Creates a new pattern with the specified number of steps
    init(stepCount: Int = 16) {
        self.stepCount = stepCount
        self.steps = (0..<stepCount).map { PatternStep(id: $0) }
    }
    
    /// Toggles a texture at the given step index.
    mutating func toggleTexture(_ texture: TextureType, at index: Int) {
        guard index >= 0 && index < steps.count else { return }
        steps[index].toggle(texture)
    }
    
    /// Clears all steps (removes all textures)
    mutating func clear() {
        for i in 0..<steps.count {
            steps[i].textures = []
        }
    }
    
    /// Returns true if any step has a non-none texture
    var hasContent: Bool {
        steps.contains { !$0.isEmpty }
    }
}
