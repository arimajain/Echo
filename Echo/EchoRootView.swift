import SwiftUI

/// High-level container that gives Echo a Letter Flow–style start screen
/// before dropping into the existing immersive `ContentView`.
struct EchoRootView: View {
    
    // MARK: - State
    
    @State private var showMainExperience = false
    @State private var animateTitle = false
    @State private var showPlayButton = false
    @State private var headlineIndex = 0
    
    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var hapticManager = HapticManager.shared
    @StateObject private var visualRhythmManager = VisualRhythmManager.shared
    
    private let headlineMessages: [String] = [
        "Feel every beat.",
        "Turn sound into touch.",
        "Close your eyes. Feel the music."
    ]
    
    private let headlineTimer = Timer.publish(every: 2.6, on: .main, in: .common).autoconnect()
    
    // MARK: - Body
    
    var body: some View {
        TrackListView()
            .preferredColorScheme(.dark)
    }
    
    // MARK: - Intro Screen
    
    private var introScreen: some View {
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
            
            VStack(spacing: 32) {
                Spacer(minLength: 0)
                
                VStack(spacing: 10) {
                    // Hero title, inspired by Letter Flow’s animated title,
                    // but using Echo’s glitch typography.
                    RGBGlitchText(
                        text: "ECHO",
                        font: .system(
                            size: 64,
                            weight: .black,
                            design: .rounded
                        ),
                        amplitude: animateTitle
                        ? max(0.15, Double(audioManager.currentAmplitude))
                        : 0.0
                    )
                    .shadow(color: .black.opacity(0.6), radius: 14, y: 6)
                    .scaleEffect(animateTitle ? 1.0 : 0.85)
                    .opacity(animateTitle ? 1.0 : 0)
                    .animation(
                        .spring(response: 0.9, dampingFraction: 0.8).delay(0.05),
                        value: animateTitle
                    )
                    
                    Text("Turn sound into touch.")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .opacity(animateTitle ? 1.0 : 0.0)
                        .offset(y: animateTitle ? 0 : 10)
                        .animation(
                            .easeOut(duration: 0.6).delay(0.2),
                            value: animateTitle
                        )
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                
                // Primary CTA – large glass play button similar to Letter Flow.
                Button {
                    playHaptics()
                    startExperience()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 26, weight: .black))
                            .symbolRenderingMode(.hierarchical)
                        
                        Text("PLAY")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .shadow(color: .white.opacity(0.25), radius: 10, y: 3)
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 48)
                }
                .glass(cornerRadius: 32, opacity: 0.26)
                .scaleEffect(showPlayButton ? 1.0 : 0.3)
                .opacity(showPlayButton ? 1.0 : 0.0)
                .animation(
                    .spring(response: 0.85, dampingFraction: 0.7)
                    .delay(0.4),
                    value: showPlayButton
                )
                .accessibilityLabel("Play")
                .accessibilityHint("Start Echo and feel the music.")
                
                // Rotating headline line, similar to Letter Flow’s rotating tagline.
                if showPlayButton {
                    Text(headlineMessages[headlineIndex])
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .contentTransition(.numericText())
                        .animation(.easeInOut, value: headlineIndex)
                        .onReceive(headlineTimer) { _ in
                            guard !showMainExperience else { return }
                            withAnimation(.spring(response: 0.7, dampingFraction: 0.88)) {
                                headlineIndex = (headlineIndex + 1) % headlineMessages.count
                            }
                        }
                } else {
                    // Reserve layout space before animation kicks in.
                    Text(headlineMessages.first ?? "")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.clear)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Accessibility / onboarding hint, echoing the existing bubble copy.
                VStack(spacing: 8) {
                    Text("Turn Silent Mode OFF.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Hold your iPhone in your hand to feel the rhythm through haptics.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .glass(cornerRadius: 20, opacity: 0.22)
                .padding(.bottom, 20)
            }
        }
        .safeAreaPadding(.horizontal)
        .onAppear {
            prepareHaptics()
            
            withAnimation {
                animateTitle = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation {
                    showPlayButton = true
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func startExperience() {
        // Ensure audio + haptics are ready before switching.
        audioManager.play()
        
        withAnimation {
            showMainExperience = true
        }
    }
    
    private func prepareHaptics() {
        hapticManager.prepare()
    }
    
    private func playHaptics() {
        // Simple emphasis tap using the existing manager, scaled by intensity.
        let scaled = min(0.9 * audioManager.intensityMultiplier, 1.0)
        hapticManager.playDynamicVibration(
            frequency: 0.6,
            intensity: scaled
        )
    }
}

#Preview {
    EchoRootView()
        .preferredColorScheme(.dark)
}

