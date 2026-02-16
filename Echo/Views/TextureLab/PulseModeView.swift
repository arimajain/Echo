import SwiftUI

/// Full-screen pulse & grouping mode.
/// Static layout, no swipes.
struct PulseModeView: View {
    @ObservedObject var engine: TextureLabEngine
    @State private var tempo: Double = 120.0
    @State private var pulseCount: Int = 4
    @State private var selectedTexture: TextureType = .deepPulse
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Grouping indicator dots (above surface)
            groupingIndicator
                .padding(.bottom, 32)
            
            // Interactive surface with accent animation (visual center)
            ZStack {
                InteractiveSurfaceView(
                    isActive: engine.isPlaying,
                    onTouchDown: {
                        if !engine.isPlaying {
                            engine.playPulsePattern(texture: selectedTexture, pulseCount: pulseCount, bpm: tempo)
                        }
                    },
                    onTouchUp: {
                        if engine.isPlaying {
                            engine.stop()
                        }
                    }
                )
                
                // Visual accent indicator (stronger glow on first beat of cycle)
                // Positioned absolutely so it doesn't affect layout
                if engine.isPlaying && engine.currentPulseBeat == 0 {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(0.8),
                                    Color.purple.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 260, height: 260)
                        .blur(radius: 12)
                        .opacity(0.9)
                        .animation(.easeInOut(duration: 0.15), value: engine.currentPulseBeat)
                        .allowsHitTesting(false) // Don't interfere with touch
                }
            }
            .frame(width: 260, height: 260) // Fixed frame size to prevent layout shifts
            .padding(.bottom, 40)
            
            // Compact control panel
            VStack(spacing: 20) {
                // Texture selector
                textureSelector
                
                // Speed control
                tempoControl
                
                // Grouping selector
                groupingSelector
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
            
            Spacer()
        }
    }
    
    // MARK: - Grouping Indicator
    
    private var groupingIndicator: some View {
        HStack(spacing: 12) {
            ForEach(0..<pulseCount, id: \.self) { index in
                let isActive = engine.isPlaying && engine.currentPulseBeat == index
                let isFirstBeat = index == 0
                
                Circle()
                    .fill(
                        isActive
                        ? (isFirstBeat ? Color.white : Color.white.opacity(0.7))
                        : Color.white.opacity(0.2)
                    )
                    .frame(width: isFirstBeat ? 10 : 8, height: isFirstBeat ? 10 : 8)
                    .overlay(
                        // Subtle glow for first beat when active
                        Group {
                            if isFirstBeat && isActive {
                                Circle()
                                    .fill(Color.cyan.opacity(0.4))
                                    .blur(radius: 4)
                                    .frame(width: 14, height: 14)
                            }
                        }
                    )
                    .animation(.easeInOut(duration: 0.15), value: engine.currentPulseBeat)
            }
        }
        .frame(height: 14) // Fixed height to prevent layout shifts
    }
    
    private var textureSelector: some View {
        HStack(spacing: 8) {
            ForEach([TextureType.deepPulse, .sharpTap, .rapidTexture, .softWave], id: \.id) { texture in
                Button {
                    selectedTexture = texture
                } label: {
                    Image(systemName: iconName(for: texture))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(selectedTexture == texture ? .black : .white.opacity(0.7))
                        .frame(width: 40, height: 40)
                        .background(
                            selectedTexture == texture
                            ? Color.white
                            : Color.white.opacity(0.1)
                        )
                        .clipShape(Circle())
                }
            }
        }
    }
    
    private var tempoControl: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Speed")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("\(Int(tempo))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Slider(value: $tempo, in: 40...200, step: 1)
                .tint(.white.opacity(0.8))
        }
    }
    
    private var groupingSelector: some View {
        VStack(spacing: 8) {
            Text("Grouping")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.6))
            
            HStack(spacing: 8) {
                ForEach([3, 4, 5, 7], id: \.self) { count in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            pulseCount = count
                            // Stop playback if changing grouping while playing
                            if engine.isPlaying {
                                engine.stop()
                            }
                        }
                    } label: {
                        Text("\(count)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(pulseCount == count ? .black : .white.opacity(0.7))
                            .frame(width: 50, height: 36)
                            .background(
                                pulseCount == count
                                ? Color.white
                                : Color.white.opacity(0.1)
                            )
                            .clipShape(Capsule())
                            .scaleEffect(pulseCount == count ? 1.0 : 0.95)
                    }
                    .buttonStyle(.plain)
                }
            }
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
