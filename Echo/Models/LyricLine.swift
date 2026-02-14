import Foundation

/// Represents a single line of lyrics with its timing information.
struct LyricLine: Identifiable, Codable, Equatable {
    /// Unique identifier for this lyric line.
    let id: UUID
    
    /// Start time in seconds when this line should appear.
    let startTime: Double
    
    /// End time in seconds when this line should disappear.
    let endTime: Double
    
    /// The text content of this lyric line.
    let text: String
    
    init(id: UUID = UUID(),
         startTime: Double,
         endTime: Double,
         text: String) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}

extension LyricLine {
    /// Checks if a given time falls within this lyric line's active range.
    func isActive(at time: Double) -> Bool {
        return time >= startTime && time < endTime
    }
}
