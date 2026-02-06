import SwiftUI

// MARK: - ChromaticGlitch ViewModifier

/// Splits content into **Red**, **Green**, and **Blue** layers offset from each other
/// and adds a random positional jitter — creating a modern "glitch" aesthetic on loud beats.
///
/// ## How It Works
/// Three copies of the content are rendered, each tinted to a single color channel
/// using `.colorMultiply`. When the amplitude is below ``threshold`` all three
/// overlap perfectly and recombine into the original white. When the amplitude
/// exceeds the threshold the layers drift apart, revealing the RGB fringing.
///
/// A random **jitter** of ±3 px is applied to the entire group on every amplitude
/// tick while the effect is active, giving it a raw, analog-distortion feel.
///
/// ## Compositing
/// ```
/// Layer 1 (Red)   — normal blend mode
/// Layer 2 (Green) — additive (.plusLighter)
/// Layer 3 (Blue)  — additive (.plusLighter)
/// ─────────────────────────────────────────
/// Overlap = R + G + B = White (original)
/// ```
///
/// ## Usage
/// ```swift
/// Text("Echo")
///     .chromaticGlitch(amplitude: audioManager.currentAmplitude)
/// ```
struct ChromaticGlitch: ViewModifier {

    // MARK: - Inputs

    /// Current audio amplitude (`0.0 … 1.0`).
    let amplitude: Float

    /// Amplitude above which the RGB split and jitter activate.
    var threshold: Float = 0.45

    // MARK: - Jitter State

    /// Random horizontal offset applied each tick (±3 px).
    @State private var jitterX: CGFloat = 0

    /// Random vertical offset applied each tick (±2 px).
    @State private var jitterY: CGFloat = 0

    // MARK: - Derived Values

    /// Whether the glitch effect is currently firing.
    private var isGlitching: Bool { amplitude > threshold }

    /// How far apart the R/G/B layers drift (0 when calm, up to ~5 pt on loudest peaks).
    private var splitAmount: CGFloat {
        guard isGlitching else { return 0 }
        // Normalize the above-threshold portion into 0…1, then scale to max offset.
        let normalized = CGFloat(amplitude - threshold) / CGFloat(1.0 - threshold)
        return normalized * 5.0
    }

    // MARK: - Body

    func body(content: Content) -> some View {
        ZStack {
            // ── Red channel — drifts upper-left ─────────────────────────
            content
                .colorMultiply(.red)
                .offset(x: -splitAmount, y: -splitAmount * 0.5)

            // ── Green channel — drifts lower-center ─────────────────────
            content
                .colorMultiply(.green)
                .blendMode(.plusLighter)
                .offset(x: splitAmount * 0.5, y: splitAmount)

            // ── Blue channel — drifts right ─────────────────────────────
            content
                .colorMultiply(.blue)
                .blendMode(.plusLighter)
                .offset(x: splitAmount, y: -splitAmount * 0.3)
        }
        // Smooth the RGB spread so it doesn't flicker.
        .animation(.easeInOut(duration: 0.08), value: splitAmount)
        // Jitter the entire group for that raw analog feel.
        .offset(x: jitterX, y: jitterY)
        // Regenerate random jitter on every amplitude tick.
        .onChange(of: amplitude) { _, newValue in
            if newValue > threshold {
                jitterX = CGFloat.random(in: -3...3)
                jitterY = CGFloat.random(in: -2...2)
            } else {
                jitterX = 0
                jitterY = 0
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Convenience Extension

extension View {
    /// Applies a chromatic-aberration RGB split and random jitter on loud beats.
    ///
    /// - Parameters:
    ///   - amplitude: Current audio amplitude (`0.0 … 1.0`).
    ///   - threshold: Amplitude above which the effect activates (default `0.45`).
    func chromaticGlitch(amplitude: Float, threshold: Float = 0.45) -> some View {
        modifier(ChromaticGlitch(amplitude: amplitude, threshold: threshold))
    }
}
