import SwiftUI

/// Immersive reactive music screen with bulging lines.
/// Full-screen experience with minimal overlay controls.
struct FeelTabView: View {
    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var visualRhythmManager = VisualRhythmManager.shared
    @State private var controlsOpacity: Double = 1.0
    @State private var controlsTimer: Timer?
    @State private var showSettings = false
    @State private var mode: EchoLineSurface.RenderingMode = .calm
    
    var body: some View {
        ZStack {
            // Layer 1: Reactive lines surface (full screen)
            EchoLineSurface(
                mode: mode,
                isActive: audioManager.isPlaying,
                audioManager: audioManager
            )
            .ignoresSafeArea()
            
            // Layer 2: Minimal overlay controls
            VStack(spacing: 0) {
                // Top overlay (no timer)
                topOverlay
                
                Spacer()
                
                // Center controls (pause button)
                centerControls
                
                Spacer()
                
                // Bottom overlay
                bottomOverlay
            }
            .opacity(controlsOpacity)
            
            // Settings panel (slides up from bottom)
            if showSettings {
                settingsPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .rhythmPulse(amplitude: audioManager.amplitude, isActive: visualRhythmManager.isActive)
        .sheet(isPresented: $visualRhythmManager.showEpilepsyWarning) {
            VisualRhythmWarningSheet(
                onAccept: { visualRhythmManager.confirmActivation() },
                onDecline: { visualRhythmManager.showEpilepsyWarning = false }
            )
            .preferredColorScheme(.dark)
            .presentationDetents([.medium])
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if showSettings {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSettings = false
                }
            } else {
                showControlsTemporarily()
            }
        }
        .onAppear {
            // Load first track if none is loaded
            if audioManager.currentTrack == nil, let firstTrack = audioManager.availableTracks.first {
                audioManager.loadTrack(firstTrack)
            }
            // Auto-hide controls after 3 seconds
            scheduleControlsFade()
        }
        .onDisappear {
            controlsTimer?.invalidate()
            // Stop audio when leaving Feel tab
            audioManager.pause()
        }
    }
    
    // MARK: - Top Overlay
    
    private var topOverlay: some View {
        HStack {
            Spacer()
            
            // Settings button (top right)
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSettings.toggle()
                }
                showControlsTemporarily()
            } label: {
                Image(systemName: showSettings ? "xmark" : "slider.horizontal.3")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial.opacity(0.4), in: Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
    
    // MARK: - Center Controls
    
    private var centerControls: some View {
        HStack(spacing: 40) {
            // Previous track button
            Button {
                previousTrack()
                showControlsTemporarily()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial.opacity(0.5), in: Circle())
            }
            
            // Center pause button
            Button {
                if audioManager.isPlaying {
                    audioManager.pause()
                } else {
                    audioManager.play()
                }
                showControlsTemporarily()
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial.opacity(0.7))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            
            // Next track button
            Button {
                nextTrack()
                showControlsTemporarily()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial.opacity(0.5), in: Circle())
            }
        }
    }
    
    // MARK: - Bottom Overlay
    
    private var bottomOverlay: some View {
        VStack(spacing: 8) {
            // Track info
            if let track = audioManager.currentTrack {
                Text(track.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                
                if let artist = track.artist {
                    Text(artist)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                }
            } else {
                // Load first track if none is playing
                Button {
                    if let firstTrack = audioManager.availableTracks.first {
                        audioManager.loadTrack(firstTrack)
                        audioManager.play()
                    }
                } label: {
                    Text("Start Listening")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial.opacity(0.6), in: Capsule())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .padding(.bottom, 40)
    }
    
    // MARK: - Settings Panel
    
    private var settingsPanel: some View {
        VStack(spacing: 20) {
            // Track selection
            trackSelection
            
            // Visual mode toggle
            visualModeToggle
            
            // Intensity slider
            intensityControl
            
            // Visual Rhythm Mode toggle
            visualRhythmToggle
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .padding(.bottom, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial.opacity(0.95), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .ignoresSafeArea(edges: .bottom)
    }
    
    private var trackSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Track")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(audioManager.availableTracks) { track in
                        Button {
                            audioManager.loadTrack(track)
                            if !audioManager.isPlaying {
                                audioManager.play()
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(track.color.swiftUIColor)
                                    .frame(width: 50, height: 50)
                                
                                Text(track.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .padding(12)
                            .background(
                                audioManager.currentTrack?.id == track.id
                                ? Color.white.opacity(0.2)
                                : Color.white.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var visualModeToggle: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visual Mode")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            
            Picker("Mode", selection: $mode) {
                Text("Calm").tag(EchoLineSurface.RenderingMode.calm)
                Text("Accessibility").tag(EchoLineSurface.RenderingMode.accessibility)
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var intensityControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Intensity")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text(String(format: "%.1fx", audioManager.intensityMultiplier))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Slider(
                value: Binding(
                    get: { Double(audioManager.intensityMultiplier) },
                    set: { audioManager.intensityMultiplier = Float($0) }
                ),
                in: 0.5...2.0
            )
            .tint(.white)
        }
    }
    
    private var visualRhythmToggle: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visual Rhythm")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            
            HStack {
                Text("Screen flashes & flashlight")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { visualRhythmManager.isActive },
                    set: { isOn in
                        if isOn {
                            visualRhythmManager.requestActivation()
                        } else {
                            visualRhythmManager.deactivate()
                        }
                    }
                ))
                .tint(.yellow)
            }
        }
    }
    
    // MARK: - Track Navigation
    
    private func previousTrack() {
        guard let currentTrack = audioManager.currentTrack,
              let currentIndex = audioManager.availableTracks.firstIndex(where: { $0.id == currentTrack.id }) else {
            return
        }
        
        let previousIndex = currentIndex > 0 ? currentIndex - 1 : audioManager.availableTracks.count - 1
        let previousTrack = audioManager.availableTracks[previousIndex]
        audioManager.loadTrack(previousTrack)
        if !audioManager.isPlaying {
            audioManager.play()
        }
    }
    
    private func nextTrack() {
        guard let currentTrack = audioManager.currentTrack,
              let currentIndex = audioManager.availableTracks.firstIndex(where: { $0.id == currentTrack.id }) else {
            return
        }
        
        let nextIndex = (currentIndex + 1) % audioManager.availableTracks.count
        let nextTrack = audioManager.availableTracks[nextIndex]
        audioManager.loadTrack(nextTrack)
        if !audioManager.isPlaying {
            audioManager.play()
        }
    }
    
    // MARK: - Control Visibility Management
    
    private func showControlsTemporarily() {
        withAnimation(.easeInOut(duration: 0.3)) {
            controlsOpacity = 1.0
        }
        scheduleControlsFade()
    }
    
    private func scheduleControlsFade() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            if !showSettings {
                withAnimation(.easeInOut(duration: 0.5)) {
                    controlsOpacity = 0.3 // Fade but don't completely hide
                }
            }
        }
    }
}
