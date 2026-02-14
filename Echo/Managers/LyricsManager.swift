import Foundation
import Combine

/// Manages lyrics synchronization with audio playback.
///
/// Loads timestamped lyrics from a JSON file and provides real-time
/// access to the currently active lyric line based on playback time.
@MainActor
class LyricsManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = LyricsManager()
    
    // MARK: - Published Properties
    
    /// The currently active lyric line (if any).
    @Published var activeLine: LyricLine?
    
    // MARK: - Private Properties
    
    /// All loaded lyric lines, sorted by start time.
    private var lyrics: [LyricLine] = []
    
    /// The last time we checked for active line (for efficiency).
    private var lastCheckedTime: Double = 0.0
    
    // MARK: - Initialization
    
    private init() {
        loadLyrics()
    }
    
    // MARK: - Loading
    
    /// Loads lyrics from `Lyrics.json` in the app bundle.
    private func loadLyrics() {
        guard let url = Bundle.main.url(forResource: "Lyrics", withExtension: "json") else {
            print("LyricsManager: ⚠️ Could not find Lyrics.json in bundle")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            lyrics = try decoder.decode([LyricLine].self, from: data)
            
            // Sort by start time for efficient binary search
            lyrics.sort { $0.startTime < $1.startTime }
            
            print("LyricsManager: ✅ Loaded \(lyrics.count) lyric lines")
        } catch {
            print("LyricsManager: ⚠️ Failed to load lyrics – \(error.localizedDescription)")
        }
    }
    
    // MARK: - Querying
    
    /// Finds the lyric line that should be active at the given time.
    ///
    /// - Parameter time: Current playback time in seconds.
    /// - Returns: The active `LyricLine` if one exists, otherwise `nil`.
    func getCurrentLine(at time: Double) -> LyricLine? {
        // Optimize: if time hasn't changed much, check if current line is still active
        if let current = activeLine,
           abs(time - lastCheckedTime) < 0.1,
           current.isActive(at: time) {
            return current
        }
        
        lastCheckedTime = time
        
        // Binary search for efficiency (lyrics are sorted by startTime)
        var left = 0
        var right = lyrics.count - 1
        var result: LyricLine?
        
        while left <= right {
            let mid = (left + right) / 2
            let line = lyrics[mid]
            
            if line.isActive(at: time) {
                result = line
                break
            } else if time < line.startTime {
                right = mid - 1
            } else {
                left = mid + 1
            }
        }
        
        // Fallback: linear search if binary search didn't find exact match
        // (handles edge cases where time is between lines)
        if result == nil {
            result = lyrics.first { $0.isActive(at: time) }
        }
        
        return result
    }
    
    /// Updates the active line based on current playback time.
    ///
    /// Call this method regularly (e.g., from a timer or audio manager callback)
    /// to keep `activeLine` synchronized with playback.
    ///
    /// - Parameter time: Current playback time in seconds.
    func updateActiveLine(at time: Double) {
        let newLine = getCurrentLine(at: time)
        
        // Only update if the line actually changed (prevents unnecessary UI updates)
        if newLine?.id != activeLine?.id {
            activeLine = newLine
        }
    }
    
    /// Resets the active line (e.g., when playback stops).
    func reset() {
        activeLine = nil
        lastCheckedTime = 0.0
    }
}
