import SwiftUI

/// Example SwiftUI view demonstrating EchoLineSurface usage.
///
/// This view shows how to integrate the audio-reactive line surface
/// with mode toggling and playback control.
struct EchoLineSurfaceExample: View {
    @StateObject private var audioManager = AudioManager.shared
    @State private var mode: EchoLineSurface.RenderingMode = .calm
    @State private var isPlaying = false
    
    var body: some View {
        ZStack {
            // Full-screen line surface
            EchoLineSurface(
                mode: mode,
                isActive: audioManager.isPlaying,
                audioManager: audioManager
            )
            .ignoresSafeArea()
            
            // Overlay controls
            VStack {
                Spacer()
                
                // Mode toggle
                Picker("Mode", selection: $mode) {
                    Text("Calm").tag(EchoLineSurface.RenderingMode.calm)
                    Text("Accessibility").tag(EchoLineSurface.RenderingMode.accessibility)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Playback control
                Button(action: {
                    if audioManager.isPlaying {
                        audioManager.pause()
                    } else {
                        audioManager.play()
                    }
                }) {
                    Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    EchoLineSurfaceExample()
}
