import SwiftUI
import CoreHaptics

/// Full-screen explore mode for testing individual textures.
/// ONLY mode allowed to use horizontal swipe (TabView for textures).
struct ExploreModeView: View {
    @State private var activeTexture: TextureType?
    @StateObject private var hapticManager = HapticManager.shared
    @State private var loopTimer: Timer?
    
    private let textures: [TextureType] = [.deepPulse, .sharpTap, .rapidTexture, .softWave]
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Small mode label
            Text("Explore")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 40)
            
            // Swipeable texture pages (ONLY place with horizontal swipe)
            TabView {
                ForEach(textures, id: \.id) { texture in
                    texturePage(for: texture)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            Spacer()
        }
        .onAppear {
            // Engine is already initialized in HapticManager.shared on app launch
            hapticManager.prepare()
        }
        .onDisappear {
            // Stop all haptic playback when leaving Explore mode
            stopTexture()
        }
        .onChange(of: activeTexture) { oldValue, newValue in
            // Stop playback when switching textures (swiping between pages)
            if oldValue != newValue && oldValue != nil {
                stopTexture()
            }
        }
    }
    
    private func texturePage(for texture: TextureType) -> some View {
        let isActive = activeTexture == texture
        
        return VStack(spacing: 0) {
            Spacer()
            
            // Interactive surface
            InteractiveSurfaceView(
                isActive: isActive,
                onTouchDown: {
                    print("ExploreModeView: 👆 Touch down for texture: \(texture.displayName)")
                    activeTexture = texture
                    playTexture(texture)
                },
                onTouchUp: {
                    print("ExploreModeView: 👆 Touch up for texture: \(texture.displayName)")
                    activeTexture = nil
                    stopTexture()
                }
            )
            .padding(.bottom, 40)
            
            // Touch hint
            Text("Touch and hold to feel")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(isActive ? 0.8 : 0.4))
                .padding(.bottom, 24)
                .animation(.easeInOut(duration: 0.2), value: isActive)
            
            // Texture name
            Text(texture.displayName)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
                .padding(.bottom, 8)
            
            // One-line descriptor
            Text(description(for: texture))
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Haptic Engine Management
    
    private func setupHapticEngine() {
        // Engine is already initialized in HapticManager.shared on app launch
        // Just ensure it's prepared for immediate use
        hapticManager.prepare()
    }
    
    private func stopHapticEngine() {
        stopTexture()
        // Engine stays alive in HapticManager, no need to stop it
    }
    
    // MARK: - Haptic Playback
    
    private func playTexture(_ texture: TextureType) {
        stopTexture()
        
        guard let pattern = try? HapticPatternLibrary.texturePattern(for: texture, baseIntensity: 1.0) else {
            print("ExploreModeView: ⚠️ Failed to create pattern for texture: \(texture)")
            return
        }
        
        let patternDuration = getPatternDuration(for: texture)
        
        // Play immediately using shared engine
        _ = hapticManager.playTexturePattern(pattern, name: "Explore - \(texture.displayName)")
        
        // Loop continuously
        loopTimer = Timer.scheduledTimer(withTimeInterval: patternDuration, repeats: true) { timer in
            Task { @MainActor in
                guard self.activeTexture == texture else {
                    timer.invalidate()
                    return
                }
                // Use shared engine - already initialized and ready
                _ = self.hapticManager.playTexturePattern(pattern, name: "Explore - \(texture.displayName) [Loop]")
            }
        }
    }
    
    private func stopTexture() {
        loopTimer?.invalidate()
        loopTimer = nil
    }
    
    private func getPatternDuration(for texture: TextureType) -> TimeInterval {
        switch texture {
        case .deepPulse: return 0.25
        case .sharpTap: return 0.06
        case .rapidTexture: return 0.15
        case .softWave: return 0.6
        default: return 0.3
        }
    }
    
    private func description(for texture: TextureType) -> String {
        switch texture {
        case .deepPulse: return "Longer duration, medium intensity"
        case .sharpTap: return "Very short, high sharpness"
        case .rapidTexture: return "Multiple tiny pulses"
        case .softWave: return "Long continuous vibration"
        default: return ""
        }
    }
}
