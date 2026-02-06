import SwiftUI

/// High-polish RGB glitch text used in Visual Rhythm Mode.
///
/// Layers three copies of the same text (R, G, B) with chromatic offsets that
/// increase as `amplitude` rises. On heavy hits (`amplitude > 0.8`), the
/// entire stack jitters slightly to simulate vibration.
struct RGBGlitchText: View {

    // MARK: - Inputs

    let text: String
    var font: Font = .largeTitle
    let amplitude: Double    // 0.0 ... 1.0 from AudioManager

    // MARK: - Jitter State

    @State private var jitterX: CGFloat = 0
    @State private var jitterY: CGFloat = 0

    // MARK: - Derived

    private var cgAmplitude: CGFloat { CGFloat(amplitude) }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Layer 1: Red, offset left
            Text(text)
                .font(font)
                .foregroundColor(.red)
                .offset(x: -cgAmplitude * 10, y: 0)
                .blendMode(.screen)

            // Layer 2: Blue, offset right
            Text(text)
                .font(font)
                .foregroundColor(.blue)
                .offset(x: cgAmplitude * 10, y: 0)
                .blendMode(.screen)

            // Layer 3: Green, centered
            Text(text)
                .font(font)
                .foregroundColor(.green)
                .blendMode(.screen)
        }
        // Group jitter: only on strong hits
        .offset(x: jitterX, y: jitterY)
        .onChange(of: amplitude) { _, newValue in
            if newValue > 0.8 {
                jitterX = CGFloat.random(in: -3...3)
                jitterY = CGFloat.random(in: -3...3)
            } else {
                jitterX = 0
                jitterY = 0
            }
        }
        // Ultra-fast response to amplitude changes
        .animation(.linear(duration: 0.1), value: amplitude)
        .accessibilityLabel(text)
    }
}

