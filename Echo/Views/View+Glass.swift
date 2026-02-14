import SwiftUI

/// Glassmorphism-style effect used throughout Echo.
/// Inspired by Letter Flow's liquid glass aesthetic.
struct GlassEffect: ViewModifier {
    var cornerRadius: CGFloat = 20
    var opacity: Double = 0.2
    var shadowRadius: CGFloat = 20
    var shadowY: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Deep blur / material base.
                    Color.white.opacity(opacity)
                        .background(.ultraThinMaterial)
                    
                    // Subtle inner glow
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Gradient stroke border catching light along the edge.
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .shadow(color: .black.opacity(0.3), radius: shadowRadius, x: 0, y: shadowY)
            .shadow(color: .black.opacity(0.15), radius: shadowRadius * 0.5, x: 0, y: shadowY * 0.5)
    }
}

/// Enhanced glass card with floating effect.
struct FloatingGlassCard: ViewModifier {
    var cornerRadius: CGFloat = 24
    var opacity: Double = 0.25
    var padding: CGFloat = 20
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .glass(cornerRadius: cornerRadius, opacity: opacity, shadowRadius: 24, shadowY: 12)
    }
}

extension View {
    /// Applies the Echo glassmorphism effect.
    func glass(cornerRadius: CGFloat = 20, opacity: Double = 0.2, shadowRadius: CGFloat = 20, shadowY: CGFloat = 10) -> some View {
        modifier(GlassEffect(cornerRadius: cornerRadius, opacity: opacity, shadowRadius: shadowRadius, shadowY: shadowY))
    }
    
    /// Creates a floating glass card container.
    func floatingGlassCard(cornerRadius: CGFloat = 24, opacity: Double = 0.25, padding: CGFloat = 20) -> some View {
        modifier(FloatingGlassCard(cornerRadius: cornerRadius, opacity: opacity, padding: padding))
    }
}

