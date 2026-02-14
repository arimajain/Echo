import SwiftUI

/// Track selection screen that shows available tracks.
struct TrackListView: View {
    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var hapticManager = HapticManager.shared
    @State private var selectedTrack: Track?
    @State private var navigateToVisualizer = false
    
    var body: some View {
        NavigationStack {
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
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 12) {
                            RGBGlitchText(
                                text: "ECHO",
                                font: .system(
                                    size: 56,
                                    weight: .black,
                                    design: .rounded
                                ),
                                amplitude: 0.15
                            )
                            .shadow(color: .black.opacity(0.6), radius: 14, y: 6)
                            
                            Text("Select a track to begin")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 20)
                        
                        // Track list
                        VStack(spacing: 16) {
                            ForEach(audioManager.availableTracks) { track in
                                trackCard(track: track)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        
                        // Navigation to main experience
                        NavigationLink {
                            ContentView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("All Features")
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    
                                    Text("Texture Lab, Game Mode, Beat Recorder & more")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .padding(20)
                            .glass(cornerRadius: 20, opacity: 0.22)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Echo")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .navigationDestination(isPresented: $navigateToVisualizer) {
                if let track = selectedTrack {
                    EchoLineVisualizerView(trackToLoad: track)
                }
            }
        }
        .onAppear {
            hapticManager.prepare()
        }
    }
    
    private func trackCard(track: Track) -> some View {
        Button {
            selectedTrack = track
            // Small haptic feedback
            hapticManager.playDynamicVibration(frequency: 0.5, intensity: 0.3)
            navigateToVisualizer = true
        } label: {
            HStack(spacing: 16) {
                // Colored indicator
                Circle()
                    .fill(track.color.swiftUIColor)
                    .frame(width: 12, height: 12)
                    .shadow(color: track.color.swiftUIColor.opacity(0.6), radius: 4)
                
                // Track info
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    if let artist = track.artist {
                        Text(artist)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(20)
            .glass(cornerRadius: 20, opacity: 0.22)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TrackListView()
}
