import Foundation

/// Represents a single beat in the rhythm game timeline.
struct BeatNode: Identifiable {
    let id: UUID
    let timestamp: Double   // seconds into the track
    var isHit: Bool
}

extension BeatNode {
    /// Hard-coded beat map for the demo track.
    ///
    /// This is a "cheat sheet" used while we don't have real beat detection.
    /// Timestamps are in seconds from the start of the song.
    static func demoTrackBeats() -> [BeatNode] {
        let times: [Double] = [
            2.0, 2.5, 3.0, 4.0,
            4.5, 5.0, 6.0, 6.5,
            7.0, 8.0, 8.5, 9.0,
            10.0, 10.5, 11.0, 12.0
        ]

        return times.map { t in
            BeatNode(id: UUID(), timestamp: t, isHit: false)
        }
    }
}

