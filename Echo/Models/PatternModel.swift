import Foundation

/// Represents a single step in a pattern grid.
struct PatternStep: Identifiable, Equatable {
    let id: Int
    var texture: TextureType
    
    init(id: Int, texture: TextureType = .none) {
        self.id = id
        self.texture = texture
    }
}

/// Model for storing and managing tactile patterns in the Texture Lab.
struct PatternModel: Equatable {
    /// Number of steps in the pattern (8 or 16)
    let stepCount: Int
    
    /// Array of steps, each with a texture assignment
    var steps: [PatternStep]
    
    /// Creates a new pattern with the specified number of steps
    init(stepCount: Int = 16) {
        self.stepCount = stepCount
        self.steps = (0..<stepCount).map { PatternStep(id: $0) }
    }
    
    /// Cycles the texture at the given step index
    mutating func cycleTexture(at index: Int) {
        guard index >= 0 && index < steps.count else { return }
        steps[index].texture = steps[index].texture.next()
    }
    
    /// Sets the texture at the given index
    mutating func setTexture(_ texture: TextureType, at index: Int) {
        guard index >= 0 && index < steps.count else { return }
        steps[index].texture = texture
    }
    
    /// Clears all steps (sets to .none)
    mutating func clear() {
        for i in 0..<steps.count {
            steps[i].texture = .none
        }
    }
    
    /// Returns true if any step has a non-none texture
    var hasContent: Bool {
        steps.contains { $0.texture != .none }
    }
}
