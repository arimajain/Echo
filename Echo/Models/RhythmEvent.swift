import Foundation

/// A structured description of a musical rhythm moment in the track.
///
/// This is the core unit that the rest of the system (haptics, visuals,
/// rhythm games) will consume instead of raw waveform data.
struct RhythmEvent: Identifiable, Sendable {
    let id = UUID()
    
    /// Time in seconds from the start of the current track.
    let timestamp: TimeInterval
    
    /// High-level classification of the rhythmic moment.
    let type: RhythmType
    
    /// Normalized strength of the event (`0.0 ... 1.0`).
    let intensity: Float
}

/// Coarse rhythm categories used to build haptic and visual "grammar".
enum RhythmType: Sendable {
    case kick      // Strong, low-end hit
    case snare     // Mid-punch accent
    case hihat     // Light, high-frequency tick
    case build     // Rising energy / tension
    case drop      // Peak impact / chorus entry
}

