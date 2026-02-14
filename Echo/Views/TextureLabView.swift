import SwiftUI
import CoreHaptics

/// Comprehensive Texture Lab for tactile pattern exploration.
/// Full-screen, focused design with dedicated views for each mode.
struct TextureLabView: View {
    @StateObject private var engine = TextureLabEngine()
    @State private var selectedMode: LabMode = .explore
    
    enum LabMode: String, CaseIterable {
        case explore = "Explore"
        case pulseGrouping = "Pulse & Grouping"
        case density = "Density"
        case patternBuilder = "Pattern Builder"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        ZStack {
            // Simple gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.05, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Mode-specific full-screen views
            Group {
                switch selectedMode {
                case .explore:
                    TextureExploreView()
                case .pulseGrouping:
                    PulseGroupingView(engine: engine)
                case .density:
                    DensityView(engine: engine)
                case .patternBuilder:
                    PatternBuilderView(engine: engine)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            
            // Mode selector at top
            VStack {
                HStack {
                    Spacer()
                    
                    Menu {
                        ForEach(LabMode.allCases, id: \.id) { mode in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedMode = mode
                                }
                            } label: {
                                HStack {
                                    Text(mode.rawValue)
                                    if selectedMode == mode {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(selectedMode.rawValue)
                                .font(.headline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Texture Explore View (Original Design)

struct TextureExploreView: View {
    @ObservedObject private var hapticManager = HapticManager.shared
    @State private var activeTexture: TextureType?
    @State private var loopTimer: Timer?
    @State private var hapticEngine: CHHapticEngine?
    
    private let textures: [TextureType] = [.deepPulse, .sharpTap, .rapidTexture, .softWave]
    
    var body: some View {
        TabView {
            ForEach(textures, id: \.id) { texture in
                textureCard(for: texture)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
    
    private func textureCard(for texture: TextureType) -> some View {
        let isActive = activeTexture == texture
        
        return VStack(spacing: 40) {
            Spacer()
            
            // Large icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isActive
                            ? [Color.cyan.opacity(0.3), Color.purple.opacity(0.2)]
                            : [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 180, height: 180)
                    .glass(cornerRadius: 90, opacity: 0.25)
                
                Image(systemName: iconName(for: texture))
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isActive
                            ? [Color.cyan, Color.purple]
                            : [Color.white, Color.white.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isActive ? 1.1 : 1.0)
                    .shadow(color: .cyan.opacity(isActive ? 0.8 : 0.3), radius: 24, y: 12)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
            
            // Text
            VStack(spacing: 12) {
                Text(texture.displayName)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                
                Text(description(for: texture))
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)
            }
            .floatingGlassCard(cornerRadius: 24, opacity: 0.18, padding: 24)
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Hold to Feel button
            holdToFeelButton(for: texture, isActive: isActive)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func holdToFeelButton(for texture: TextureType, isActive: Bool) -> some View {
        Button {
            // Intentionally empty
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isActive ? "hand.tap.fill" : "hand.tap")
                    .font(.title2)
                
                Text(isActive ? "Feeling..." : "Hold to Feel")
                    .font(.title3.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                LinearGradient(
                    colors: isActive
                    ? [Color.cyan.opacity(0.4), Color.purple.opacity(0.3)]
                    : [Color.white.opacity(0.2), Color.white.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .glass(cornerRadius: 24, opacity: isActive ? 0.35 : 0.25)
            .foregroundStyle(.white)
            .scaleEffect(isActive ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.1)
                .onChanged { _ in
                    if activeTexture != texture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            activeTexture = texture
                        }
                        playTexture(texture)
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        activeTexture = nil
                    }
                    stopTexture()
                }
        )
        .padding(.horizontal, 40)
    }
    
    private func playTexture(_ texture: TextureType) {
        stopTexture() // Stop any existing playback
        
        guard let pattern = try? HapticPatternLibrary.texturePattern(for: texture, baseIntensity: 1.0) else {
            return
        }
        
        guard hapticManager.supportsHaptics else { return }
        hapticManager.prepare()
        
        // Set up engine if needed
        if hapticEngine == nil {
            do {
                hapticEngine = try CHHapticEngine()
                try hapticEngine?.start()
            } catch {
                print("Failed to create haptic engine: \(error)")
                return
            }
        }
        
        guard let engine = hapticEngine else { return }
        
        // Get pattern duration to loop it
        let patternDuration = getPatternDuration(for: texture)
        
        // Play the pattern immediately
        playPatternOnce(pattern, engine: engine)
        
        // Set up a timer to repeatedly play the pattern for continuous feel
        loopTimer = Timer.scheduledTimer(withTimeInterval: patternDuration, repeats: true) { timer in
            Task { @MainActor in
                // Check if texture is still active (structs are value types, so we capture the texture)
                if self.activeTexture == texture, let engine = self.hapticEngine {
                    self.playPatternOnce(pattern, engine: engine)
                } else {
                    timer.invalidate()
                }
            }
        }
    }
    
    private func playPatternOnce(_ pattern: CHHapticPattern, engine: CHHapticEngine) {
        do {
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play texture pattern: \(error)")
        }
    }
    
    private func getPatternDuration(for texture: TextureType) -> TimeInterval {
        switch texture {
        case .deepPulse: return 0.25
        case .sharpTap: return 0.06
        case .rapidTexture: return 0.15
        case .softWave: return 0.5
        default: return 0.3
        }
    }
    
    private func stopTexture() {
        loopTimer?.invalidate()
        loopTimer = nil
        // Engine will be reused, no need to stop it
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
    
    private func description(for texture: TextureType) -> String {
        switch texture {
        case .deepPulse:
            return "Longer duration, medium intensity. Feels like bass."
        case .sharpTap:
            return "Very short, high sharpness. Crisp and percussive."
        case .rapidTexture:
            return "Multiple tiny pulses. Feels like hi-hat or buzz."
        case .softWave:
            return "Long continuous vibration. Ambient background layer."
        default:
            return ""
        }
    }
}

// MARK: - Pulse & Grouping View

struct PulseGroupingView: View {
    @ObservedObject var engine: TextureLabEngine
    @State private var tempo: Double = 120.0
    @State private var pulseCount: Int = 4
    @State private var selectedTexture: TextureType = .deepPulse
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Large texture icon
            textureIcon
            
            // Controls
            VStack(spacing: 24) {
                textureSelector
                pulseCountSelector
                tempoSlider
                playStopButton
            }
            .padding(24)
            .glass(cornerRadius: 24, opacity: 0.15)
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private var textureIcon: some View {
        Image(systemName: iconName(for: selectedTexture))
            .font(.system(size: 100, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.cyan, Color.purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: .cyan.opacity(0.6), radius: 30, y: 15)
    }
    
    private var textureSelector: some View {
        HStack(spacing: 16) {
            ForEach([TextureType.deepPulse, .sharpTap, .rapidTexture, .softWave], id: \.id) { texture in
                Button {
                    selectedTexture = texture
                } label: {
                    Image(systemName: iconName(for: texture))
                        .font(.title3)
                        .foregroundStyle(selectedTexture == texture ? .black : .white)
                        .frame(width: 50, height: 50)
                        .background(
                            selectedTexture == texture
                            ? Color.white
                            : Color.white.opacity(0.1)
                        )
                        .glass(cornerRadius: 12, opacity: 0)
                }
            }
        }
    }
    
    private var pulseCountSelector: some View {
        HStack(spacing: 12) {
            Text("Pulse Count")
                .font(.headline)
                .foregroundStyle(.white)
            
            Spacer()
            
            ForEach([3, 4, 5, 7], id: \.self) { count in
                Button {
                    pulseCount = count
                } label: {
                    Text("\(count)")
                        .font(.headline)
                        .foregroundStyle(pulseCount == count ? .black : .white)
                        .frame(width: 50, height: 44)
                        .background(
                            pulseCount == count
                            ? Color.white
                            : Color.white.opacity(0.1)
                        )
                        .glass(cornerRadius: 12, opacity: 0)
                }
            }
        }
    }
    
    private var tempoSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Speed")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(Int(tempo)) BPM")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Slider(value: $tempo, in: 40...200, step: 1)
                .tint(.white)
        }
    }
    
    private var playStopButton: some View {
        Button {
            if engine.isPlaying {
                engine.stop()
            } else {
                let interval = 60.0 / tempo
                engine.playPulsePattern(texture: selectedTexture, pulseCount: pulseCount, interval: interval)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: engine.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title2.weight(.semibold))
                
                Text(engine.isPlaying ? "Stop" : "Play")
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.white)
            .glass(cornerRadius: 16, opacity: 0)
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

// MARK: - Density View

struct DensityView: View {
    @ObservedObject var engine: TextureLabEngine
    @State private var tempo: Double = 120.0
    @State private var density: Int = 4
    @State private var selectedTexture: TextureType = .deepPulse
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            textureIcon
            
            VStack(spacing: 24) {
                textureSelector
                densitySlider
                tempoSlider
                playStopButton
            }
            .padding(24)
            .glass(cornerRadius: 24, opacity: 0.15)
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private var textureIcon: some View {
        Image(systemName: iconName(for: selectedTexture))
            .font(.system(size: 100, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.cyan, Color.purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: .cyan.opacity(0.6), radius: 30, y: 15)
    }
    
    private var textureSelector: some View {
        HStack(spacing: 16) {
            ForEach([TextureType.deepPulse, .sharpTap, .rapidTexture, .softWave], id: \.id) { texture in
                Button {
                    selectedTexture = texture
                } label: {
                    Image(systemName: iconName(for: texture))
                        .font(.title3)
                        .foregroundStyle(selectedTexture == texture ? .black : .white)
                        .frame(width: 50, height: 50)
                        .background(
                            selectedTexture == texture
                            ? Color.white
                            : Color.white.opacity(0.1)
                        )
                        .glass(cornerRadius: 12, opacity: 0)
                }
            }
        }
    }
    
    private var densitySlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Density")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(density) pulses")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Slider(value: Binding(
                get: { Double(density) },
                set: { density = Int($0) }
            ), in: 1...8, step: 1)
                .tint(.white)
        }
    }
    
    private var tempoSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Speed")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(Int(tempo)) BPM")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Slider(value: $tempo, in: 40...200, step: 1)
                .tint(.white)
        }
    }
    
    private var playStopButton: some View {
        Button {
            if engine.isPlaying {
                engine.stop()
            } else {
                let measureDuration = 60.0 / tempo * 4
                engine.playDensityPattern(texture: selectedTexture, density: density, measureDuration: measureDuration)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: engine.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title2.weight(.semibold))
                
                Text(engine.isPlaying ? "Stop" : "Play")
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.white)
            .glass(cornerRadius: 16, opacity: 0)
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

// MARK: - Pattern Builder View

struct PatternBuilderView: View {
    @ObservedObject var engine: TextureLabEngine
    @State private var pattern = PatternModel(stepCount: 16)
    @State private var tempo: Double = 120.0
    @State private var gridStepCount: Int = 16
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Grid
            PatternGridView(pattern: $pattern, stepCount: gridStepCount)
                .padding(24)
                .glass(cornerRadius: 24, opacity: 0.15)
                .padding(.horizontal, 40)
            
            // Controls
            VStack(spacing: 20) {
                // Step count
                HStack(spacing: 12) {
                    Text("Steps:")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    ForEach([8, 16], id: \.self) { count in
                        Button {
                            gridStepCount = count
                            pattern = PatternModel(stepCount: count)
                            engine.setPattern(pattern)
                        } label: {
                            Text("\(count)")
                                .font(.headline)
                                .foregroundStyle(gridStepCount == count ? .black : .white)
                                .frame(width: 50, height: 36)
                                .background(
                                    gridStepCount == count
                                    ? Color.white
                                    : Color.white.opacity(0.1)
                                )
                                .glass(cornerRadius: 8, opacity: 0)
                        }
                    }
                }
                
                // Tempo
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Speed")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Text("\(Int(tempo)) BPM")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    Slider(value: $tempo, in: 40...200, step: 1)
                        .tint(.white)
                }
                
                // Buttons
                HStack(spacing: 12) {
                    Button {
                        pattern.clear()
                        engine.setPattern(pattern)
                    } label: {
                        Text("Clear")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red.opacity(0.3))
                            .glass(cornerRadius: 12, opacity: 0.2)
                    }
                    
                    Button {
                        if engine.isPlaying {
                            engine.stop()
                        } else {
                            engine.setTempo(tempo)
                            engine.setPattern(pattern)
                            engine.play()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: engine.isPlaying ? "stop.fill" : "play.fill")
                                .font(.title3.weight(.semibold))
                            
                            Text(engine.isPlaying ? "Stop" : "Play")
                                .font(.headline.weight(.semibold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .glass(cornerRadius: 12, opacity: 0)
                    }
                }
            }
            .padding(24)
            .glass(cornerRadius: 24, opacity: 0.15)
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .onChange(of: pattern) { newPattern in
            engine.setPattern(newPattern)
        }
    }
}

#Preview {
    NavigationStack {
        TextureLabView()
    }
}
