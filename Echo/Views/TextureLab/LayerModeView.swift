import SwiftUI

/// Full-screen Layer mode for tactile blending.
/// Drag-and-drop interaction: drag textures into orb to layer haptics.
struct LayerModeView: View {
    @StateObject private var engine = LayerEngine()
    @State private var orbScale: CGFloat = 1.0
    @State private var draggedTexture: TextureType? = nil
    @State private var dragTranslation: CGSize = .zero   // visual offset for current drag
    @State private var isDragging: Bool = false
    
    var body: some View {
        let _ = print("LayerModeView: 🎨 Body rendered")
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            // Position orb slightly higher to create more room for bottom content
            let orbCenterY = screenHeight * 0.32
            // Slightly smaller orb height for a tighter look
            let orbHeight = screenHeight * 0.58
            let orbBottom = orbCenterY + (orbHeight / 2)
            // Calculate spacer height: keep reasonable gap below orb,
            // but also reserve space at the bottom for tokens + Clear All
            let desiredTopOfHint = orbBottom + (screenHeight * 0.04) // ~4% of screen height below orb
            let minBottomReserved: CGFloat = 260 // space for tokens + Clear All above bottom bar
            let maxTopOfHint = max(0, screenHeight - minBottomReserved)
            let spacerHeight = min(desiredTopOfHint, maxTopOfHint)
                        
            ZStack {
                // Central animated orb (60% height area) - Drop destination
                AnimatedOrbView(
                    hue: hueFromColor(engine.blendedColor),
                    hoverIntensity: 0.2,
                    rotateOnHover: true,
                    forceHoverState: false,
                    hapticsActive: engine.totalLayers > 0,
                    backgroundColor: .black
                )
                .scaleEffect(orbScale)
                .frame(maxWidth: .infinity)
                .frame(height: orbHeight)
                .position(x: geometry.size.width / 2, y: orbCenterY)
                .allowsHitTesting(true)
                
                // Persistent chips for currently active textures (stay inside the orb while playing)
                activeTokensOverlay(
                    in: geometry,
                    orbCenterY: orbCenterY
                )
                
                // Hint text inside the orb when no layers are active
                if engine.totalLayers == 0 {
                    Text("Drag textures into the orb\nand layer haptics")
                        .font(.system(size: 14, weight: .medium))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 56)
                        .position(x: geometry.size.width / 2, y: orbCenterY)
                        .allowsHitTesting(false)
                }
                
                VStack(spacing: 0) {
                    // Spacer calculated to push content below orb with reasonable spacing
                    Spacer()
                        .frame(height: spacerHeight)
                    
                    // Texture tokens at bottom (40% height area)
                    HStack(spacing: 40) {
                        ForEach([TextureType.deepPulse, .sharpTap, .rapidTexture, .softWave], id: \.id) { texture in
                            textureToken(for: texture, geometry: geometry)
                        }
                    }
                    .padding(.bottom, 60)
                    
                    // Clear button area – fixed height so tokens never shift vertically.
                    Button(action: {
                        engine.clearAll()
                        triggerOrbPulse()
                    }) {
                        Text("Clear")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(engine.totalLayers > 0 ? 0.9 : 0.35))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.white.opacity(engine.totalLayers > 0 ? 0.12 : 0.04))
                                    .overlay(
                                        Capsule()
                                            .stroke(.white.opacity(engine.totalLayers > 0 ? 0.25 : 0.08), lineWidth: 1)
                                    )
                            )
                    }
                    .disabled(engine.totalLayers == 0)
                    .frame(height: 40)
                    .padding(.top, 20)
                    .padding(.bottom, 72)
                }
                // Extra top padding so bottom controls sit a bit higher, giving more space under the orb.
                .padding(.top, 24)
            }
        }
    }
    
    @ViewBuilder
    private func textureToken(for texture: TextureType, geometry: GeometryProxy) -> some View {
        let count = engine.count(for: texture)
        let color = colorForTexture(texture)
        
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
                // Show a small count indicator only (no minus button here).
                Text("×\(count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Image(systemName: iconName(for: texture))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color.opacity(0.8))
            }
        }
        .offset(dragOffset(for: texture))
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    // Start drag for this texture
                    if !isDragging {
                        isDragging = true
                        draggedTexture = texture
                    }
                    // Only apply offset for the currently dragged texture
                    if draggedTexture == texture {
                        dragTranslation = value.translation
                    }
                }
                .onEnded { _ in
                    // On drop, add layer (if within limits), then reset offset
                    if draggedTexture == texture {
                        let count = engine.count(for: texture)
                        if count < 3 && engine.totalLayers < 8 {
                            engine.addLayer(texture)
                            triggerOrbPulse()
                            print("LayerModeView: ✅ Dropped \(texture.displayName) (simplified hit-test)")
                        } else {
                            print("LayerModeView: ⚠️ Cannot add layer - count: \(count), total: \(engine.totalLayers)")
                        }
                    }
                    dragTranslation = .zero
                    draggedTexture = nil
                    isDragging = false
                }
        )
    }
    
    @ViewBuilder
    private func textureTokenPreview(for texture: TextureType) -> some View {
        let color = colorForTexture(texture)
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(0.8),
                            color.opacity(0.4),
                            color.opacity(0.2)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .frame(width: 60, height: 60)
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.6), lineWidth: 2)
                )
                .shadow(color: color.opacity(0.5), radius: 12)
            
            Image(systemName: iconName(for: texture))
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(color.opacity(0.9))
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
    
    @ViewBuilder
    private func activeTokensOverlay(in geometry: GeometryProxy, orbCenterY: CGFloat) -> some View {
        let active: [(TextureType, Int)] = [
            (.deepPulse, engine.count(for: .deepPulse)),
            (.sharpTap, engine.count(for: .sharpTap)),
            (.rapidTexture, engine.count(for: .rapidTexture)),
            (.softWave, engine.count(for: .softWave))
        ].filter { $0.1 > 0 }
        
        let center = CGPoint(x: geometry.size.width / 2, y: orbCenterY)
        // Slightly larger radius to cover more of the orb
        let radius: CGFloat = active.count <= 1 ? 0 : 80
        
        ZStack {
            ForEach(Array(active.enumerated()), id: \.offset) { idx, item in
                let texture = item.0
                let count = item.1
                let position = activeTokenPosition(
                    index: idx,
                    total: active.count,
                    center: center,
                    radius: radius
                )
                
                activeChip(for: texture, count: count)
                    .position(position)
            }
        }
    }
    
    /// Returns the current drag offset for a given texture token
    private func dragOffset(for texture: TextureType) -> CGSize {
        guard isDragging, let draggedTexture, draggedTexture == texture else {
            return .zero
        }
        return dragTranslation
    }
    
    // MARK: - Chip Helpers
    
    @ViewBuilder
    private func activeChip(for texture: TextureType, count: Int) -> some View {
        let baseColor = colorForTexture(texture)
        let icon = iconName(for: texture)
        
        HStack(spacing: 8) {
            // Remove button
            Button(action: {
                engine.removeLayer(texture)
                triggerOrbPulse()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.9))
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            
            // Icon + optional count (no text label)
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                
                if count > 1 {
                    Text("×\(count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.trailing, 4)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 8)
        // Slightly taller, a bit narrower capsule
        .frame(height: 40)
        .background(
            ZStack {
                // Colored, liquid-glass base (tinted by texture color)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                baseColor.opacity(0.85),
                                baseColor.opacity(0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.55),
                                        baseColor.opacity(0.9)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        // Subtle inner highlight for "liquid" sheen
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.20),
                                        Color.white.opacity(0.03)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.screen)
                    )
            }
        )
        // Softer glow so the blur radius isn't overwhelming
        .shadow(color: baseColor.opacity(0.35), radius: 8, x: 0, y: 4)
    }
    
    /// Positions chips around a ring inside the orb.
    private func activeTokenPosition(index: Int, total: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        guard total > 1 else { return center }
        let angle = (Double(index) / Double(total)) * (2.0 * Double.pi) - Double.pi / 2.0
        return CGPoint(
            x: center.x + radius * CGFloat(cos(angle)),
            y: center.y + radius * CGFloat(sin(angle))
        )
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
    
    /// Converts a SwiftUI Color to hue value (0-360 degrees)
    private func hueFromColor(_ color: Color) -> Float {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Float(hue * 360.0)
    }
}
