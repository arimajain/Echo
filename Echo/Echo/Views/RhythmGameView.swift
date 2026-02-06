import SwiftUI

/// Radial rhythm game interface synchronized with the audio timeline.
struct RhythmGameView: View {

    @ObservedObject private var audioManager = AudioManager.shared
    @StateObject private var engine = RhythmGameEngine()

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2,
                                 y: geometry.size.height / 2)
            let targetRadius = size * 0.14
            let maxRadius = size * 0.45

            ZStack {
                Color.black.ignoresSafeArea()

                // Ripples for active beats.
                ForEach(engine.getActiveBeats()) { beat in
                    let radius = radius(
                        for: beat,
                        currentTime: audioManager.currentTime,
                        targetRadius: targetRadius,
                        maxRadius: maxRadius
                    )

                    Circle()
                        .stroke(Color.white.opacity(0.55), lineWidth: 2)
                        .frame(width: radius * 2, height: radius * 2)
                        .position(center)
                }

                // Target zone.
                Circle()
                    .stroke(targetStrokeColor, lineWidth: 5)
                    .frame(width: targetRadius * 2, height: targetRadius * 2)
                    .position(center)
                    .shadow(color: targetStrokeColor.opacity(0.7), radius: 12)
                    .animation(.easeInOut(duration: 0.12), value: engine.lastJudgement)

                // HUD: score + combo
                VStack {
                    HStack {
                        Text("Score \(engine.score)")
                        Spacer()
                        Text("Combo \(engine.currentCombo)×")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    Spacer()
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                engine.userDidTap()
            }
        }
    }

    // MARK: - Helpers

    /// Maps a beat timestamp to a circle radius based on current playback time.
    private func radius(for beat: BeatNode,
                        currentTime: Double,
                        targetRadius: CGFloat,
                        maxRadius: CGFloat) -> CGFloat {
        let dt = beat.timestamp - currentTime
        let window: Double = 1.5
        let normalized = min(max(abs(dt) / window, 0.0), 1.0)
        // At dt = 0 → radius = targetRadius, at |dt| = window → radius = maxRadius.
        return targetRadius + (maxRadius - targetRadius) * CGFloat(normalized)
    }

    /// Color for the target zone based on latest judgement.
    private var targetStrokeColor: Color {
        switch engine.lastJudgement {
        case .perfect:
            return .green
        case .good:
            return .cyan
        case .miss:
            return .red
        case nil:
            return .white.opacity(0.8)
        }
    }
}

// MARK: - Preview

#Preview {
    RhythmGameView()
        .preferredColorScheme(.dark)
}

