import SwiftUI

// MARK: - RhythmPulse ViewModifier

/// A `ViewModifier` that overlays a beat-synced color flash on top of any view.
///
/// When **Visual Rhythm Mode** is active, the modifier reads the current audio
/// amplitude and shifts the screen color on loud peaks:
///
/// | Amplitude     | Effect                              |
/// |---------------|-------------------------------------|
/// | > 0.8         | Bright white flash (loudest hits)   |
/// | > 0.5         | Deep purple wash (mid-high energy)  |
/// | ≤ 0.5         | No overlay (silent / calm sections) |
///
/// The `.easeInOut(duration: 0.1)` animation makes transitions snappy and
/// beat-locked while still feeling smooth rather than jarring.
///
/// ## Usage
/// ```swift
/// ZStack { /* your content */ }
///     .modifier(RhythmPulse(amplitude: audioManager.currentAmplitude,
///                            isActive: visualRhythmManager.isActive))
/// ```
struct RhythmPulse: ViewModifier {

    // MARK: - Inputs

    /// The current audio amplitude (`0.0 … 1.0`).
    let amplitude: Float

    /// Whether Visual Rhythm Mode is currently active.
    let isActive: Bool

    // MARK: - Derived Color

    /// Computes the overlay color based on the current amplitude.
    ///
    /// Returns `.clear` when the mode is inactive or the amplitude is below
    /// the visual threshold, so there's zero performance cost at idle.
    private var pulseColor: Color {
        guard isActive else { return .clear }

        if amplitude > 0.8 {
            // Loudest peaks → bright white flash.
            return .white.opacity(0.25 + Double(amplitude - 0.8) * 2.5)
        } else if amplitude > 0.5 {
            // Mid-high energy → purple wash whose intensity scales with amplitude.
            let normalized = Double(amplitude - 0.5) / 0.3  // 0…1 across [0.5, 0.8]
            return Color.purple.opacity(normalized * 0.35)
        } else {
            return .clear
        }
    }

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .overlay(
                pulseColor
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            )
            .animation(.easeInOut(duration: 0.1), value: amplitude)
    }
}

// MARK: - Convenience Extension

extension View {
    /// Applies the ``RhythmPulse`` modifier for beat-synced screen flashes.
    ///
    /// - Parameters:
    ///   - amplitude: Current audio amplitude.
    ///   - isActive: Whether Visual Rhythm Mode is active.
    func rhythmPulse(amplitude: Float, isActive: Bool) -> some View {
        modifier(RhythmPulse(amplitude: amplitude, isActive: isActive))
    }
}
