import SwiftUI

// MARK: - VisualizerView

/// A "Liquid Pulse" visualizer that expands and contracts with the music.
///
/// `VisualizerView` observes ``AudioManager/currentAmplitude`` and translates it
/// into a stack of concentric, glowing circles. Each ring reacts at a different
/// magnitude — outer rings flare more dramatically while inner rings stay tighter —
/// creating the illusion of a pulsing drop of water.
///
/// ## Ring Anatomy (inside → out)
/// | Layer | Scale Response | Opacity | Blur |
/// |-------|---------------|---------|------|
/// | Core  | subtle        | bright  | none |
/// | Inner | moderate      | medium  | soft |
/// | Outer | dramatic      | faint   | heavy|
///
/// ## Usage
/// ```swift
/// VisualizerView(audioManager: AudioManager.shared)
/// ```
struct VisualizerView: View {

    // MARK: - Dependencies

    /// The audio manager whose ``AudioManager/currentAmplitude`` drives the animation.
    @ObservedObject var audioManager: AudioManager

    // MARK: - Configuration

    /// Total number of concentric ring layers.
    private let ringCount: Int = 5

    // MARK: - Derived State

    /// Current amplitude cast to `CGFloat` for use in geometry modifiers.
    private var amplitude: CGFloat {
        CGFloat(audioManager.currentAmplitude)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width, geometry.size.height)

            ZStack {
                // Rings are drawn outermost-first so the bright core paints on top.
                ForEach((0..<ringCount).reversed(), id: \.self) { index in
                    pulseRing(at: index, diameter: diameter)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // The single animation modifier the user requested — ties every
        // geometry change (scaleEffect, opacity) to the amplitude value.
        .animation(.easeInOut(duration: 0.18), value: audioManager.currentAmplitude)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Audio Visualizer")
        .accessibilityHint("Pulsing circles that expand and contract with the music's volume.")
        .accessibilityValue(amplitudeDescription)
    }

    // MARK: - Ring Builder

    /// Builds a single pulse ring at the given layer index.
    ///
    /// - Parameters:
    ///   - index: `0` is the innermost (core) ring, `ringCount - 1` is the outermost glow.
    ///   - diameter: The available diameter from the parent `GeometryReader`.
    @ViewBuilder
    private func pulseRing(at index: Int, diameter: CGFloat) -> some View {
        // `progress` goes from 0.0 (core) → 1.0 (outermost).
        let progress = CGFloat(index) / CGFloat(ringCount - 1)

        // --- Size: core is ~40% of the container; outermost reaches ~85%. ---
        let ringDiameter = diameter * (0.4 + progress * 0.45)

        // --- Scale response: outer rings react more to amplitude. ---
        // Core multiplier ≈ 0.08, outermost ≈ 0.6.
        let scaleMultiplier: CGFloat = 0.08 + progress * 0.52
        let scale: CGFloat = 1.0 + amplitude * scaleMultiplier

        // --- Opacity: core is vivid; outer rings are ghostly. ---
        let baseOpacity: Double = 0.7 - Double(progress) * 0.5          // 0.7 → 0.2
        let liveOpacity: Double = baseOpacity + Double(amplitude) * 0.2  // brighten on loud hits

        // --- Blur: outer rings get progressively softer. ---
        let blurRadius: CGFloat = progress * 20

        Circle()
            .fill(ringGradient(progress: progress))
            .frame(width: ringDiameter, height: ringDiameter)
            .scaleEffect(scale)
            .opacity(min(liveOpacity, 1.0))
            .blur(radius: blurRadius)
    }

    // MARK: - Gradient

    /// Returns a radial gradient whose hue shifts with both the song's progress
    /// and the ring's layer position.
    ///
    /// At the **start** of the track, the orb sits in cool blues / purples.
    /// As the song approaches its **climax**, the palette migrates smoothly
    /// through magenta into hot oranges / reds, providing a visual narrative
    /// arc across the track.
    ///
    /// - Parameter progress: `0.0` (core) to `1.0` (outermost).
    private func ringGradient(progress: CGFloat) -> RadialGradient {
        // Base hue driven by global song progress (0 → 1).
        let baseHue = songProgressHue(fraction: audioManager.currentProgress)

        // Subtle per-ring variation adds depth (inner → outer).
        let hue: Double = baseHue + Double(progress) * 0.08

        let coreColor = Color(hue: hue, saturation: 0.75, brightness: 1.0)
        let edgeColor = Color(hue: hue + 0.05, saturation: 0.6, brightness: 0.6).opacity(0.0)

        return RadialGradient(
            gradient: Gradient(colors: [coreColor, edgeColor]),
            center: .center,
            startRadius: 0,
            endRadius: 150
        )
    }

    /// Maps a normalized song progress value onto the color wheel.
    ///
    /// - Early in the track (`fraction ≈ 0.0`) we stay around cool blues/purples.
    /// - Midway (`fraction ≈ 0.5`) we travel through magenta.
    /// - Near the end (`fraction → 1.0`) we arrive at hot oranges/reds.
    ///
    /// Visually this feels like the song \"heats up\" as it approaches the chorus.
    private func songProgressHue(fraction: Double) -> Double {
        // Clamp for safety.
        let t = max(0.0, min(1.0, fraction))

        // We take a two-stage journey around the hue wheel:
        //   0.0 → 0.6 : blue (0.60) → purple (0.80)
        //   0.6 → 1.0 : purple (0.80) → red/orange (wrap from 1.02 → 0.02)
        let startHue = 0.60   // cool blue
        let midHue   = 0.80   // purple / magenta
        let endHue   = 0.02   // red/orange (wrapped)

        if t <= 0.6 {
            // Phase 1: blue → purple
            let localT = t / 0.6
            return startHue + (midHue - startHue) * localT
        } else {
            // Phase 2: purple → red/orange, traveling across the 1.0 wrap.
            let localT = (t - 0.6) / 0.4
            let expandedEnd = endHue + 1.0           // 1.02 (so we go past 1.0)
            let hue = midHue + (expandedEnd - midHue) * localT
            return hue.truncatingRemainder(dividingBy: 1.0)
        }
    }

    // MARK: - Accessibility

    /// A human-readable description of the current amplitude for VoiceOver.
    private var amplitudeDescription: String {
        switch amplitude {
        case 0.0:
            return "Silent"
        case 0.0..<0.25:
            return "Quiet"
        case 0.25..<0.55:
            return "Moderate volume"
        case 0.55..<0.8:
            return "Loud"
        default:
            return "Very loud"
        }
    }
}

// MARK: - Preview

#Preview("Visualizer – Idle") {
    VisualizerView(audioManager: AudioManager.shared)
        .preferredColorScheme(.dark)
}
