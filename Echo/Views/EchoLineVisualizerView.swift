import SwiftUI

/// Dedicated full-screen view for the EchoLineSurface visualizer.
///
/// A minimal, immersive experience showing only the audio-reactive horizontal lines
/// with minimal playback controls.
struct EchoLineVisualizerView: View {
    @StateObject private var audioManager = AudioManager.shared
    @State private var mode: EchoLineSurface.RenderingMode = .calm
    @Environment(\.dismiss) private var dismiss
    
    /// Optional track to load when view appears
    let trackToLoad: Track?
    
    /// Store the initial track to prevent it from changing
    @State private var displayedTrack: Track?
    
    /// Prevent double-taps on play/pause button
    @State private var isButtonProcessing = false
    
    init(trackToLoad: Track? = nil) {
        self.trackToLoad = trackToLoad
    }
    
    var body: some View {
        ZStack {
            // Full-screen line surface
            EchoLineSurface(
                mode: mode,
                isActive: audioManager.isPlaying,
                audioManager: audioManager
            )
            .ignoresSafeArea()
            
            // Minimal overlay controls with smooth animations
            VStack {
                // Top bar with back button and mode toggle
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial.opacity(0.8), in: Circle())
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    }
                    
                    Spacer()
                    
                    // Mode toggle
                    Picker("Mode", selection: $mode) {
                        Text("Calm").tag(EchoLineSurface.RenderingMode.calm)
                        Text("Accessibility").tag(EchoLineSurface.RenderingMode.accessibility)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    .background(.ultraThinMaterial.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                
                Spacer()
                
                // Bottom controls: track info and play/pause with smooth animations
                VStack(spacing: 24) {
                    // Track info - use displayedTrack to prevent changes
                    if let track = displayedTrack ?? audioManager.currentTrack {
                        VStack(spacing: 6) {
                            Text(track.name)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                            
                            if let artist = track.artist {
                                Text(artist)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))
                            } else {
                                Text("Echo")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
                    }
                    
                    // Large Play/Pause button - with proper state management
                    Button {
                        // Prevent double-taps
                        guard !isButtonProcessing else { return }
                        isButtonProcessing = true
                        
                        // Update state immediately for responsive UI
                        let wasPlaying = audioManager.isPlaying
                        
                        // Perform action
                        if wasPlaying {
                            audioManager.pause()
                        } else {
                            audioManager.play()
                        }
                        
                        // Allow button to be pressed again after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isButtonProcessing = false
                        }
                    } label: {
                        ZStack {
                            // Glow ring - simplified animation
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                                .frame(width: 90, height: 90)
                                .blur(radius: 8)
                                .opacity(audioManager.isPlaying ? 0.8 : 0.4)
                            
                            // Button - use explicit state to prevent glitches
                            Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 72))
                                .foregroundStyle(.white)
                                .background(.ultraThinMaterial.opacity(0.9), in: Circle())
                                .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
                        }
                    }
                    .buttonStyle(.plain) // Prevent default button animations
                    .disabled(isButtonProcessing) // Disable during processing
                }
                .padding(.bottom, 50)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .onAppear {
            // Set the displayed track first to prevent it from changing
            if let track = trackToLoad {
                displayedTrack = track
                audioManager.loadTrack(track)
                if !audioManager.isPlaying {
                    audioManager.play()
                }
            } else if let currentTrack = audioManager.currentTrack {
                // Use current track if available
                displayedTrack = currentTrack
                if !audioManager.isPlaying {
                    audioManager.play()
                }
            } else if let firstTrack = audioManager.availableTracks.first {
                // Load first available track if none is loaded
                displayedTrack = firstTrack
                audioManager.loadTrack(firstTrack)
                audioManager.play()
            }
        }
    }
}

#Preview {
    NavigationStack {
        EchoLineVisualizerView()
    }
}
