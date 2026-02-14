import SwiftUI
import Foundation

/// A fluid background visualizer with slow, physics-accurate blob motion.
///
/// The blobs "breathe" with audio amplitude (size/opacity) but maintain
/// constant slow drift speed for a calm, ethereal effect.
struct FluidBackgroundView: View {
    let type: FluidType
    let amplitude: Double

    @State private var blobs: [Blob] = []

    struct Blob: Identifiable {
        let id = UUID()
        var position: CGPoint = .zero // Anchor
        var speed: Double
        var size: CGFloat
        var hueShift: Double
        var phase: Double
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Layer 1: The Deep Aurora Gradient
                FluidGradientView(type: type)

                // Layer 2: The Floating Bokeh
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        context.blendMode = .plusLighter
                        // Use the specific blur from the type (Ether=High, Mercury=Low)
                        context.addFilter(.blur(radius: type.blurRadius))

                        for blob in blobs {
                            // PHYSICS FIX: Constant slow drift (No amplitude multiplier)
                            let angle = time * blob.speed + blob.phase
                            
                            // AUDIO REACTION: Only pulse the size & wobble radius
                            let beatPulse = 1.0 + (amplitude * 0.3)
                            
                            // Calculate orbit position
                            let orbitRadius = size.width * 0.2 * beatPulse
                            let x = (size.width/2) + Foundation.cos(angle) * orbitRadius
                            let y = (size.height/2) + Foundation.sin(angle) * orbitRadius

                            // Draw the blob
                            let currentSize = blob.size * beatPulse
                            let rect = CGRect(
                                x: x - currentSize/2,
                                y: y - currentSize/2,
                                width: currentSize,
                                height: currentSize
                            )
                            
                            // Inner Gradient logic from Letter Flow
                            // We use the 2nd and 3rd colors of the palette for the glowing blobs
                            let blobColors = [
                                type.palette[1].opacity(0.8), // Core
                                type.palette[2].opacity(0.4), // Edge
                                .clear
                            ]
                            
                            context.fill(
                                Path(ellipseIn: rect),
                                with: .radialGradient(
                                    Gradient(colors: blobColors),
                                    center: rect.center,
                                    startRadius: 0,
                                    endRadius: currentSize/2
                                )
                            )
                        }
                    }
                }
            }
            .onAppear {
                setupBlobs(in: geo.size)
            }
        }
    }

    private func setupBlobs(in size: CGSize) {
        // EXACT constants from Letter Flow
        // blobCountPhone = 2, blobCountPad = 3 (We use 3 for richness)
        let baseSize = min(size.width, size.height)
        
        blobs = (0..<3).map { _ in
            Blob(
                speed: Double.random(in: 0.3...0.6), // Slow drift
                size: CGFloat.random(in: baseSize*0.5 ... baseSize*0.8), // HUGE blobs
                hueShift: Double.random(in: -0.1...0.1),
                phase: Double.random(in: 0...6.28)
            )
        }
    }
}

extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
