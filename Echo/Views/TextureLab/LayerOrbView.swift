import SwiftUI

/// Large glowing orb for Layer mode with breathing animation and color blending.
struct LayerOrbView: View {
    let blendedColor: Color
    let glowIntensity: Double
    let totalLayers: Int
    
    @State private var breathingScale: CGFloat = 1.0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Single blended radial gradient (no stacking)
            // Outer glow expands slightly with more layers
            let glowRadius = 120.0 + (Double(totalLayers) * 10.0)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            blendedColor.opacity(glowIntensity * 0.6),
                            blendedColor.opacity(glowIntensity * 0.3),
                            blendedColor.opacity(glowIntensity * 0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 60,
                        endRadius: glowRadius
                    )
                )
                .frame(width: glowRadius * 2, height: glowRadius * 2)
                .blur(radius: 20)
                .scaleEffect(breathingScale * pulseScale)
            
            // Core orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            blendedColor.opacity(glowIntensity * 0.5),
                            blendedColor.opacity(glowIntensity * 0.2),
                            blendedColor.opacity(glowIntensity * 0.05)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(breathingScale * pulseScale)
        }
        .onAppear {
            startBreathingAnimation()
        }
        .onChange(of: totalLayers) { oldValue, newValue in
            if newValue > oldValue {
                // Layer added - trigger pulse
                triggerPulse()
            } else if newValue < oldValue {
                // Layer removed - trigger contraction
                triggerContraction()
            }
        }
    }
    
    private func startBreathingAnimation() {
        withAnimation(
            .easeInOut(duration: 3.5)
            .repeatForever(autoreverses: true)
        ) {
            breathingScale = 1.02
        }
    }
    
    /// Triggers a soft pulse when texture is added
    func triggerPulse() {
        withAnimation(.easeOut(duration: 0.3)) {
            pulseScale = 1.05
        }
        withAnimation(.easeIn(duration: 0.2).delay(0.3)) {
            pulseScale = 1.0
        }
    }
    
    /// Triggers a slight contraction when texture is removed
    func triggerContraction() {
        withAnimation(.easeInOut(duration: 0.25)) {
            pulseScale = 0.98
        }
        withAnimation(.easeInOut(duration: 0.25).delay(0.25)) {
            pulseScale = 1.0
        }
    }
}
