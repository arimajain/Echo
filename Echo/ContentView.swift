import SwiftUI

/// Immersive \"Now Playing\" screen for Echo.
///
/// Links the audio amplitude to:
/// - Background radial gradient (color temperature).
/// - Hero title.
/// - Core Haptics via ``HapticManager``.
struct ContentView: View {

    // MARK: - State

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    /// Audio engine driving amplitude values.
    @StateObject private var audioManager = AudioManager.shared

    /// Haptic engine providing audio-reactive vibration.
    @StateObject private var hapticManager = HapticManager.shared

    /// Visual Rhythm Mode manager (screen pulses + torch effects).
    @StateObject private var visualRhythmManager = VisualRhythmManager.shared

    /// Controls presentation of the launch-time accessibility hint bubble.
    @State private var showLaunchHint: Bool = true

    /// Whether the lyrics + sign language card is visible at the bottom.
    @AppStorage("showSignLanguageCard") private var showSignLanguageCard: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Layer 1: Background.
                    // Simple gradient background for better performance
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.05, blue: 0.15),
                            Color(red: 0.1, green: 0.05, blue: 0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    // Layer 2: Main content in floating glass cards.
                    ScrollView {
                        VStack(spacing: UIDevice.current.userInterfaceIdiom == .phone ? 18 : 24) {
                            Spacer()
                                .frame(height: UIDevice.current.userInterfaceIdiom == .phone ? 12 : 20)
                            
                            // Visual Rhythm toggle (floating card).
                            HStack {
                                Spacer()
                                visualRhythmToggle
                                    .padding(.horizontal, 20)
                                    .padding(.top, 12)
                            }
                            
                            // Hero section: Track title in glass card.
                            VStack(spacing: 16) {
                                Text(audioManager.currentTrack?.name ?? "ECHO")
                                    .font(.system(
                                        size: heroFontSize(for: geometry.size),
                                        weight: .bold,
                                        design: .rounded
                                    ))
                                    .foregroundStyle(.white)
                                    .padding(.vertical, 8)
                                
                                if let artist = audioManager.currentTrack?.artist {
                                    Text(artist)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .floatingGlassCard(
                                cornerRadius: UIDevice.current.userInterfaceIdiom == .phone ? 24 : 28,
                                opacity: 0.22,
                                padding: UIDevice.current.userInterfaceIdiom == .phone ? 22 : 28
                            )
                            .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .phone ? 16 : 20)
                            
                            // Track picker in glass card.
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Library")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                                
                                trackPicker
                            }
                            .floatingGlassCard(
                                cornerRadius: UIDevice.current.userInterfaceIdiom == .phone ? 20 : 24,
                                opacity: 0.2,
                                padding: UIDevice.current.userInterfaceIdiom == .phone ? 18 : 20
                            )
                            .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .phone ? 16 : 20)
                            
                            // Controls section in glass card.
                            VStack(spacing: 20) {
                                playPauseButton
                                
                                // Intensity sensitivity slider (0.5x → 2.0x).
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Intensity")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.8))
                                    
                                    Slider(
                                        value: Binding(
                                            get: { Double(audioManager.intensityMultiplier) },
                                            set: { audioManager.intensityMultiplier = Float($0) }
                                        ),
                                        in: 0.5...2.0
                                    ) {
                                        Text("Intensity")
                                    } minimumValueLabel: {
                                        Text("0.5x")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.7))
                                    } maximumValueLabel: {
                                        Text("2x")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                    
                                    // Toggle to show / hide the Sign Language card.
                                    Toggle(isOn: $showSignLanguageCard) {
                                        Text("Sign language")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(.white.opacity(0.9))
                                    }
                                    .toggleStyle(.switch)
                                    .tint(.cyan)
                                }
                                
                                // Navigation cards.
                                VStack(spacing: 12) {
                                    NavigationLink {
                                        TextureLabView()
                                    } label: {
                                        navCard(
                                            title: "Texture Lab",
                                            subtitle: "Learn haptic textures",
                                            systemImage: "waveform.path.badge.plus",
                                            color: .cyan
                                        )
                                    }
                                    
                                    NavigationLink {
                                        EchoLineVisualizerView()
                                    } label: {
                                        navCard(
                                            title: "Line Visualizer",
                                            subtitle: "Audio-reactive lines",
                                            systemImage: "waveform.path",
                                            color: .cyan
                                        )
                                    }
                                }
                            }
                            .floatingGlassCard(
                                cornerRadius: UIDevice.current.userInterfaceIdiom == .phone ? 24 : 28,
                                opacity: 0.22,
                                padding: UIDevice.current.userInterfaceIdiom == .phone ? 20 : 24
                            )
                            .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .phone ? 16 : 20)
                            
                            Spacer()
                                .frame(height: UIDevice.current.userInterfaceIdiom == .phone ? 24 : 40)
                        }
                    }
                    
                    // Launch-time accessibility hint bubble.
                    if showLaunchHint {
                        launchHintBubble
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .transition(.opacity)
                            .frame(maxHeight: .infinity, alignment: .top)
                    }
                    
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Echo")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        // Keep lyrics docked above the home indicator on iPhone so content
        // scrolls cleanly underneath on smaller screens.
        .safeAreaInset(edge: .bottom) {
            if showSignLanguageCard {
                LyricsView()
                    .glass(cornerRadius: 24, opacity: 0.25)
                    .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .phone ? 16 : 20)
                    .padding(.bottom, UIDevice.current.userInterfaceIdiom == .phone ? 12 : 24)
            }
        }
        // Synesthesia link is now event-driven: `HapticManager` and
        // `VisualRhythmManager` subscribe directly to `AudioManager`'s
        // `lastRhythmEvent`, so the UI no longer needs to fan out calls here.
        .onAppear {
            hapticManager.prepare()
            scheduleLaunchHintDismissal()
        }
        .rhythmPulse(
            amplitude: audioManager.currentAmplitude,
            isActive: visualRhythmManager.isActive
        )
        .sheet(isPresented: $visualRhythmManager.showEpilepsyWarning) {
            VisualRhythmWarningSheet(
                onAccept: { visualRhythmManager.confirmActivation() },
                onDecline: { visualRhythmManager.showEpilepsyWarning = false }
            )
            .preferredColorScheme(.dark)
            .presentationDetents([.medium])
        }
    }

    // MARK: - Controls

    /// Large glassmorphism-style Play / Pause button.
    private var playPauseButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                togglePlayback()
            }
        } label: {
            ZStack {
                // Outer glass shell with enhanced depth.
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.8),
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 6)

                // Inner glow that breathes with amplitude while playing.
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: audioManager.isPlaying
                            ? [
                                Color.cyan.opacity(0.9),
                                Color.purple.opacity(0.7)
                            ]
                            : [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 86, height: 86)
                    .scaleEffect(
                        audioManager.isPlaying
                        ? 1.0 + CGFloat(audioManager.currentAmplitude) * 0.12
                        : 1.0
                    )
                    .animation(.easeInOut(duration: 0.15), value: audioManager.currentAmplitude)
                    .blur(radius: audioManager.isPlaying ? 2 : 0)

                // Icon.
                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .offset(x: audioManager.isPlaying ? 0 : 3) // optical centering for play
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
        }
        .accessibilityLabel(audioManager.currentTrack != nil
                           ? "Play \(audioManager.currentTrack!.name)"
                           : "Play Track")
        .accessibilityHint("Double tap to feel the rhythm.")
    }

    /// Small pill-shaped navigation button used in the bottom row.
    private func navChip(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.subheadline)
            Text(title)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(.white)
        .glass(cornerRadius: 30, opacity: 0.18)
        .accessibilityLabel(title)
    }
    
    /// Large navigation card with icon, title, and subtitle.
    private func navCard(title: String, subtitle: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 16) {
            // Icon in colored circle.
            ZStack {
                Circle()
                    .fill(color.opacity(0.25))
                    .frame(width: 56, height: 56)
                
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
            }
            
            // Text content.
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Chevron.
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(16)
        .glass(cornerRadius: 20, opacity: 0.15)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint("Double tap to open")
    }

    /// Horizontal scrollable track picker.
    private var trackPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(audioManager.availableTracks) { track in
                    trackChip(track: track)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    /// Individual track chip in the picker.
    private func trackChip(track: Track) -> some View {
        let isSelected = audioManager.currentTrack?.id == track.id
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                audioManager.switchTrack(track)
            }
        } label: {
            HStack(spacing: 10) {
                // Colored indicator dot.
                Circle()
                    .fill(track.color.swiftUIColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: track.color.swiftUIColor.opacity(0.6), radius: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    if let artist = track.artist {
                        Text(artist)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(track.color.swiftUIColor)
                }
        }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glass(
                cornerRadius: 20,
                opacity: isSelected ? 0.3 : 0.18
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        track.color.swiftUIColor.opacity(isSelected ? 0.8 : 0.0),
                        lineWidth: 2
                    )
            )
    }
        .accessibilityLabel("Track: \(track.name)")
        .accessibilityHint(isSelected
                          ? "Currently playing"
                          : "Tap to switch to this track")
        .accessibilityValue(isSelected ? "Selected" : "")
    }

    /// Toggle button for Visual Rhythm Mode in the nav bar area.
    private var visualRhythmToggle: some View {
        Button {
            if visualRhythmManager.isActive {
                visualRhythmManager.deactivate()
            } else {
                visualRhythmManager.requestActivation()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: visualRhythmManager.isActive
                      ? "light.beacon.max.fill"
                      : "light.beacon.min")
                    .font(.title3)
                    .foregroundStyle(visualRhythmManager.isActive ? .yellow : .white)
                
                if visualRhythmManager.isActive {
                    Text("Visual Rhythm")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .glass(cornerRadius: 24, opacity: visualRhythmManager.isActive ? 0.28 : 0.22)
        .accessibilityLabel("Visual Rhythm Mode")
        .accessibilityHint(visualRhythmManager.isActive
                           ? "Tap to turn off screen flashes and torch effects."
                           : "Tap to enable visual rhythm mode with screen flashes and camera flash.")
        .accessibilityValue(visualRhythmManager.isActive ? "On" : "Off")
    }

    // MARK: - Actions

    private func togglePlayback() {
        if audioManager.isPlaying {
            audioManager.pause()
        } else {
            audioManager.play()
        }
    }


    // MARK: - Launch Hint

    /// A small, elegant text bubble that instructs users how to experience Echo.
    private var launchHintBubble: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.3),
                                Color.purple.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: "hand.tap.fill")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Turn Silent Mode OFF. Hold device firmly in hand to feel the sound.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .glass(cornerRadius: 20, opacity: 0.25)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Turn Silent Mode off. Hold the device firmly in your hand to feel the sound.")
    }

    /// Schedules the launch hint to fade out after a short delay.
    private func scheduleLaunchHintDismissal() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            withAnimation(.easeInOut(duration: 0.6)) {
                showLaunchHint = false
            }
        }
    }
}

// MARK: - Layout Helpers

private extension ContentView {
    func heroFontSize(for size: CGSize) -> CGFloat {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            return 56
        }
        let height = size.height
        switch height {
        case ..<650:
            return 40
        case ..<800:
            return 48
        default:
            return 56
        }
    }
}

// MARK: - Visual Rhythm Warning Sheet

/// Simple epilepsy/photosensitivity warning for Visual Rhythm Mode.
struct VisualRhythmWarningSheet: View {
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.yellow)

            Text("Photosensitivity Warning")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("Visual Rhythm Mode uses rapid screen flashes and may activate the camera flash to show the beat. This can be uncomfortable or unsafe for people with photosensitive epilepsy or light sensitivity.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                Button(action: onAccept) {
                    Text("I Understand – Enable Visual Rhythm")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.cyan, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.black)
                }

                Button(action: onDecline) {
                    Text("Cancel")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}

