import SwiftUI

/// Immersive \"Now Playing\" screen for Echo.
///
/// Links the audio amplitude to:
/// - Background radial gradient (color temperature).
/// - `RGBGlitchText` hero title.
/// - Core Haptics via ``HapticManager``.
struct ContentView: View {

    // MARK: - State

    /// Audio engine driving amplitude values.
    @StateObject private var audioManager = AudioManager.shared

    /// Haptic engine providing audio-reactive vibration.
    @StateObject private var hapticManager = HapticManager.shared

    /// Controls presentation of the launch-time accessibility hint bubble.
    @State private var showLaunchHint: Bool = true

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Layer 1: Background radial gradient.
                radialBackground
                    .ignoresSafeArea()

                // Layer 2: Hero RGB glitch text.
                VStack {
                    Spacer()

                    RGBGlitchText(
                        text: "ECHO",
                        font: .system(size: 64, weight: .bold, design: .rounded),
                        amplitude: Double(audioManager.amplitude)
                    )
                    .padding(.horizontal, 24)

                    Spacer()

                    // Layer 3: Controls.
                    VStack(spacing: 16) {
                        playPauseButton

                        // Navigation row to other experiences.
                        HStack(spacing: 12) {
                            NavigationLink {
                                TextureLabView()
                            } label: {
                                navChip(title: "Texture Lab", systemImage: "waveform.path.badge.plus")
                            }

                            NavigationLink {
                                RhythmGameView()
                            } label: {
                                navChip(title: "Game Mode", systemImage: "target")
                            }

                            NavigationLink {
                                BeatRecorderView()
                            } label: {
                                navChip(title: "Beat Rec", systemImage: "record.circle")
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 40)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Echo")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        // Synesthesia link: amplitude → haptics.
        .onChange(of: audioManager.amplitude) { _, newValue in
            hapticManager.playDynamicVibration(
                frequency: 0.5,
                intensity: newValue
            )
        }
        .onAppear {
            hapticManager.prepare()
            scheduleLaunchHintDismissal()
        }
    }

    // MARK: - Background

    /// A radial gradient whose core color shifts from deep blue to purple
    /// on louder sections.
    private var radialBackground: RadialGradient {
        let amp = Double(audioManager.amplitude)
        let centerColor: Color = amp > 0.5
            ? Color.purple
            : Color(hue: 0.62, saturation: 0.8, brightness: 0.4) // dark blue

        return RadialGradient(
            gradient: Gradient(colors: [centerColor, .black]),
            center: .center,
            startRadius: 0,
            endRadius: 500
        )
    }

    // MARK: - Controls

    /// Large glassmorphism-style Play / Pause button.
    private var playPauseButton: some View {
        Button {
            togglePlayback()
        } label: {
            ZStack {
                // Frosted glass circle.
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 96, height: 96)
                    .overlay(
                        Circle()
                            .stroke(
                                Color.white.opacity(0.25),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 12)

                // Inner glow that breathes with amplitude while playing.
                Circle()
                    .stroke(
                        Color.white.opacity(audioManager.isPlaying ? 0.6 : 0.2),
                        lineWidth: 4
                    )
                    .frame(width: 82, height: 82)
                    .scaleEffect(
                        audioManager.isPlaying
                        ? 1.0 + CGFloat(audioManager.amplitude) * 0.15
                        : 1.0
                    )
                    .animation(.easeInOut(duration: 0.15), value: audioManager.amplitude)

                // Icon.
                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
                    .offset(x: audioManager.isPlaying ? 0 : 3) // optical centering for play
            }
        }
        .accessibilityLabel("Play Demo Track")
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
        .background(Color.white.opacity(0.12), in: Capsule())
        .foregroundStyle(.white)
        .accessibilityLabel(title)
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.tap.fill")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))

            Text("Turn Silent Mode OFF. Hold device firmly in hand to feel the sound.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
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

// MARK: - Preview

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}

