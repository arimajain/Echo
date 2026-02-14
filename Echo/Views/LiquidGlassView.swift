import SwiftUI

/// High-performance, audio-reactive \"liquid glass\" background based on
/// metaball-style blobs. Designed to sit behind primary content.
struct LiquidGlassView: View {

    // MARK: - Dependencies

    @ObservedObject private var audioManager = AudioManager.shared

    // MARK: - Blob Model

    private struct Blob: Identifiable {
        let id = UUID()
        let baseCenter: CGPoint   // normalized (0...1) space
        let baseRadius: CGFloat
        let travelRadius: CGFloat
        let speed: Double
        let phase: Double
        let color: Color
    }

    /// Static configuration for 5 blobs. Motion is computed procedurally
    /// from time, so we don't need mutable velocity state.
    private let blobs: [Blob] = [
        Blob(baseCenter: CGPoint(x: 0.3, y: 0.4),
             baseRadius: 90,
             travelRadius: 40,
             speed: 0.4,
             phase: 0.0,
             color: Color.purple),
        Blob(baseCenter: CGPoint(x: 0.7, y: 0.35),
             baseRadius: 80,
             travelRadius: 45,
             speed: 0.55,
             phase: 1.3,
             color: Color.cyan),
        Blob(baseCenter: CGPoint(x: 0.5, y: 0.6),
             baseRadius: 100,
             travelRadius: 60,
             speed: 0.32,
             phase: 2.1,
             color: Color.blue),
        Blob(baseCenter: CGPoint(x: 0.2, y: 0.7),
             baseRadius: 70,
             travelRadius: 35,
             speed: 0.47,
             phase: 3.4,
             color: Color(hue: 0.60, saturation: 0.9, brightness: 0.9)),
        Blob(baseCenter: CGPoint(x: 0.8, y: 0.75),
             baseRadius: 60,
             travelRadius: 30,
             speed: 0.6,
             phase: 4.2,
             color: Color(hue: 0.52, saturation: 0.95, brightness: 0.95))
    ]

    // MARK: - Body

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let amp = Double(audioManager.currentAmplitude)

            ZStack {
                // Layer 1: Goo (heavy blur, additive blending).
                Canvas { context, size in
                    drawBlobs(in: context, size: size, time: time, amplitude: amp, coreStroke: false)
                }
                .blur(radius: 30)
                .blendMode(.plusLighter)

                // Layer 2: Core lines for definition.
                Canvas { context, size in
                    drawBlobs(in: context, size: size, time: time, amplitude: amp, coreStroke: true)
                }

                // Layer 3: Shine overlay.
                shineOverlay
            }
            .compositingGroup()
        }
    }

    // MARK: - Drawing

    private func drawBlobs(
        in context: GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        amplitude: Double,
        coreStroke: Bool
    ) {
        let baseAmp = max(0.1, amplitude)

        for blob in blobs {
            // Speed up slightly with amplitude.
            let effectiveSpeed = blob.speed * (0.6 + baseAmp * 1.4)
            let t = time * effectiveSpeed + blob.phase

            // Circular motion around the baseCenter.
            let offsetX = cos(t) * blob.travelRadius
            let offsetY = sin(t * 0.8) * blob.travelRadius

            let center = CGPoint(
                x: blob.baseCenter.x * size.width + offsetX,
                y: blob.baseCenter.y * size.height + offsetY
            )

            // Radius grows with amplitude.
            let radiusScale = 0.7 + baseAmp * 0.7
            let radius = blob.baseRadius * radiusScale

            var path = Path()
            path.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

            if coreStroke {
                // Thin, bright core.
                context.stroke(
                    path,
                    with: .color(blob.color.opacity(0.9)),
                    lineWidth: 2
                )
            } else {
                // Soft, glowing fill for the goo layer.
                context.fill(
                    path,
                    with: .radialGradient(
                        Gradient(colors: [
                            blob.color.opacity(0.9),
                            blob.color.opacity(0.0)
                        ]),
                        center: .init(x: center.x, y: center.y),
                        startRadius: radius * 0.1,
                        endRadius: radius
                    )
                )
            }
        }
    }

    // MARK: - Shine Overlay

    private var shineOverlay: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.35),
                Color.white.opacity(0.05),
                Color.white.opacity(0.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .blendMode(.softLight)
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        LiquidGlassView()
    }
    .preferredColorScheme(.dark)
}

