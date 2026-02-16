import SwiftUI

/// Large circular interactive surface for tactile exploration.
/// Pure UI component - haptic logic handled via closures.
struct InteractiveSurfaceView: View {
    let isActive: Bool
    let onTouchDown: () -> Void
    let onTouchUp: () -> Void
    
    @State private var isPressed = false
    @State private var scale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    
    var body: some View {
        ZStack {
            // Subtle radial gradient background
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
            
            // Glow ring (more visible when active)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(isActive ? 0.6 : 0.2),
                            Color.purple.opacity(isActive ? 0.4 : 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 240, height: 240)
                .blur(radius: isActive ? 8 : 4)
                .opacity(glowOpacity)
            
            // Main surface circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: isActive
                        ? [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                        ]
                        : [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(scale)
                .shadow(
                    color: isActive
                    ? Color.cyan.opacity(0.3)
                    : Color.black.opacity(0.2),
                    radius: isActive ? 20 : 10,
                    y: isActive ? 10 : 5
                )
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        withAnimation(.easeOut(duration: 0.2)) {
                            scale = 0.95
                            glowOpacity = 0.8
                        }
                        onTouchDown()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    withAnimation(.easeOut(duration: 0.25)) {
                        scale = 1.0
                        glowOpacity = 0.3
                    }
                    onTouchUp()
                }
        )
        .onChange(of: isActive) { oldValue, newValue in
            if !newValue && isPressed {
                isPressed = false
                withAnimation(.easeOut(duration: 0.25)) {
                    scale = 1.0
                    glowOpacity = 0.3
                }
            }
        }
    }
}
