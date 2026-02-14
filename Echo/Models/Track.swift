import Foundation
import SwiftUI

/// Represents a single audio track in Echo's library.
struct Track: Identifiable, Equatable {
    let id: UUID
    let name: String
    let filename: String      // e.g., "DemoTrack" (without extension)
    let artist: String?
    let color: TrackColor

    init(id: UUID = UUID(),
         name: String,
         filename: String,
         artist: String? = nil,
         color: TrackColor = .cyan) {
        self.id = id
        self.name = name
        self.filename = filename
        self.artist = artist
        self.color = color
    }
}

/// Color theme for a track (used in visualizers).
enum TrackColor: String, CaseIterable {
    case cyan
    case purple
    case blue
    case orange
    case pink

    var swiftUIColor: SwiftUI.Color {
        switch self {
        case .cyan: return .cyan
        case .purple: return .purple
        case .blue: return .blue
        case .orange: return .orange
        case .pink: return .pink
        }
    }
}

extension Track {
    /// Default library of tracks available in Echo.
    static let library: [Track] = [
        Track(
            name: "Demo Track",
            filename: "DemoTrack",
            artist: "Echo",
            color: .cyan
        ),
        Track(
            name: "Track 2",
            filename: "Track2",
            artist: "Echo",
            color: .purple
        ),
        Track(
            name: "Track 3",
            filename: "Track3",
            artist: "Echo",
            color: .blue
        ),
        Track(
            name: "Track 4",
            filename: "Track4",
            artist: "Echo",
            color: .pink
        )
    ]
}
