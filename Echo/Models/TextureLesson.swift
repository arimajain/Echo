import Foundation

/// High-level categories of haptic \"texture\" used in the Texture Lab.
enum TextureType: String, CaseIterable, Identifiable {
    case smooth
    case rough
    case sharp

    var id: String { rawValue }

    /// Human-readable name for display.
    var displayName: String {
        switch self {
        case .smooth: return "Smooth"
        case .rough:  return "Rough"
        case .sharp:  return "Sharp"
        }
    }
}

/// Represents a single educational lesson in the Texture Lab.
struct TextureLesson: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
    let hapticType: TextureType
}

extension TextureLesson {
    /// Default set of lessons used by the Texture Lab carousel.
    static let demoLessons: [TextureLesson] = [
        TextureLesson(
            title: "The Sine Wave",
            description: "Smooth, continuous vibration. Represents flutes, vocals, and pure tones.",
            iconName: "waveform.path",
            hapticType: .smooth
        ),
        TextureLesson(
            title: "The Transient",
            description: "A single sharp tap. Feels like a kick drum or a door closing.",
            iconName: "circle.hexagonpath.fill",
            hapticType: .sharp
        ),
        TextureLesson(
            title: "The Distortion",
            description: "Gritty, buzzing vibration. Represents guitars, distortion, and noisy textures.",
            iconName: "bolt.badge.a.fill",
            hapticType: .rough
        )
    ]
}

