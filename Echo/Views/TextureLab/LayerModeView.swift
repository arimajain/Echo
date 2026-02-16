import SwiftUI

/// Full-screen Layer mode for tactile blending.
/// Simplified tap-to-add interaction.
struct LayerModeView: View {
    @StateObject private var engine = LayerEngine()
    @State private var orbScale: CGFloat = 1.0
    
    var body: some View {
        let _ = print("LayerModeView: 🎨 Body rendered")
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let orbCenterY = screenHeight * 0.35
            
            ZStack {
                // Central orb (60% height area)
                LayerOrbView(
                    blendedColor: engine.blendedColor,
                    glowIntensity: engine.glowIntensity,
                    totalLayers: engine.totalLayers
                )
                .scaleEffect(orbScale)
                .frame(maxWidth: .infinity)
                .frame(height: screenHeight * 0.6)
                .position(x: geometry.size.width / 2, y: orbCenterY)
                .allowsHitTesting(false)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Hint text when no layers
                    if engine.totalLayers == 0 {
                        Text("Tap textures below to layer haptics")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.bottom, 20)
                    }
                    
                    // Texture tokens at bottom (40% height area)
                    HStack(spacing: 40) {
                        ForEach([TextureType.deepPulse, .sharpTap, .rapidTexture, .softWave], id: \.id) { texture in
                            textureToken(for: texture)
                        }
                    }
                    .padding(.bottom, 60)
                    
                    // Clear button when layers are active
                    if engine.totalLayers > 0 {
                        Button(action: {
                            engine.clearAll()
                            triggerOrbPulse()
                        }) {
                            Text("Clear All")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(.white.opacity(0.1))
                                        .overlay(
                                            Capsule()
                                                .stroke(.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func textureToken(for texture: TextureType) -> some View {
        let count = engine.count(for: texture)
        let color = colorForTexture(texture)
        let canAdd = count < 3 && engine.totalLayers < 8
        
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(0.6),
                            color.opacity(0.3),
                            color.opacity(0.1)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .frame(width: 60, height: 60)
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.4), lineWidth: 2)
                )
                .shadow(color: color.opacity(0.3), radius: 8)
                .scaleEffect(count > 0 ? 1.05 : 1.0)
            
            // Content
            if count > 0 {
                VStack(spacing: 2) {
                    Text("\(count)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    // Minus button overlay for removing
                    Button(action: {
                        engine.removeLayer(texture)
                        triggerOrbPulse()
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            } else {
                Image(systemName: iconName(for: texture))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color.opacity(0.8))
            }
        }
        .onTapGesture {
            print("LayerModeView: 👆 Texture token tapped: \(texture)")
            if canAdd {
                print("LayerModeView: ✅ Can add layer, calling engine.addLayer")
                engine.addLayer(texture)
                triggerOrbPulse()
            } else {
                print("LayerModeView: ⚠️ Cannot add layer - count: \(count), total: \(engine.totalLayers)")
            }
        }
    }
    
    private func triggerOrbPulse() {
        withAnimation(.easeOut(duration: 0.2)) {
            orbScale = 1.05
        }
        withAnimation(.easeIn(duration: 0.2).delay(0.2)) {
            orbScale = 1.0
        }
    }
    
    private func colorForTexture(_ texture: TextureType) -> Color {
        switch texture {
        case .deepPulse: return .blue
        case .sharpTap: return .yellow
        case .rapidTexture: return .purple
        case .softWave: return .green
        default: return .white
        }
    }
    
    private func iconName(for texture: TextureType) -> String {
        switch texture {
        case .deepPulse: return "waveform.path"
        case .sharpTap: return "circle.fill"
        case .rapidTexture: return "sparkles"
        case .softWave: return "waveform"
        default: return "circle"
        }
    }
}
