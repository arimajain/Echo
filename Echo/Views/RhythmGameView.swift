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
                // Background with fluid effect
                FluidBackgroundView(
                    type: .aurora,
                    amplitude: Double(audioManager.amplitude)
                )
                .ignoresSafeArea()

                // Ripples for active beats.
                ForEach(engine.getActiveBeats()) { beat in
                    let radius = radius(
                        for: beat,
                        currentTime: audioManager.currentTime,
                        targetRadius: targetRadius,
                        maxRadius: maxRadius
                    )

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.7),
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: radius * 2, height: radius * 2)
                        .position(center)
                        .blur(radius: 1)
                }

                // Target zone in glass card.
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    targetStrokeColor.opacity(0.2),
                                    targetStrokeColor.opacity(0.05),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: targetRadius
                            )
                        )
                        .frame(width: targetRadius * 2, height: targetRadius * 2)
                    
                Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    targetStrokeColor.opacity(0.9),
                                    targetStrokeColor.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                    .frame(width: targetRadius * 2, height: targetRadius * 2)
                }
                    .position(center)
                .shadow(color: targetStrokeColor.opacity(0.8), radius: 20)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: engine.lastJudgement)

                // HUD: score + combo in floating glass card
                VStack {
                    HStack(spacing: 20) {
                        // Score card
                        VStack(spacing: 4) {
                            Text("Score")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.7))
                            
                            Text("\(engine.score)")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .glass(cornerRadius: 20, opacity: 0.22)
                        
                        // Combo card
                        VStack(spacing: 4) {
                            Text("Combo")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.7))
                            
                            Text("\(engine.currentCombo)×")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(
                                    engine.currentCombo > 0
                                    ? LinearGradient(
                                        colors: [.cyan, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    : LinearGradient(
                                        colors: [.white, .white],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .glass(cornerRadius: 20, opacity: 0.22)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    Spacer()
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                engine.userDidTap()
            }
            // 👇 CRITICAL FIX: Auto-start music so the game timeline moves
            .onAppear {
                audioManager.stop() // Reset to 0
                audioManager.play()
            }
            .onDisappear {
                audioManager.stop()
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
