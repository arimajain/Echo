import SwiftUI

/// Main container for Texture Lab with persistent mode selection.
/// Uses segmented control at top, no nested swipes.
struct TextureLabContainerView: View {
    @StateObject private var engine = TextureLabEngine()
    @State private var selectedMode: LabMode = .explore
    
    enum LabMode: String, CaseIterable {
        case explore = "Explore"
        case pulse = "Rhythm"
        case builder = "Builder"
        case layer = "Layer"
    }
    
    var body: some View {
        ZStack {
            // Subtle gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.08, green: 0.05, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Persistent mode selector at top
                modeSelector
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                
                // Mode content (static, no paging)
                Group {
                    switch selectedMode {
                    case .explore:
                        ExploreModeView()
                    case .pulse:
                        PulseModeView(engine: engine)
                    case .builder:
                        PatternBuilderModeView(engine: engine)
                    case .layer:
                        LayerModeView()
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.25), value: selectedMode)
        .onChange(of: selectedMode) { oldValue, newValue in
            // Stop playback when switching modes within Lab tab
            if oldValue != newValue {
                engine.stop()
                // LayerEngine manages its own cleanup via deinit
            }
        }
        .onDisappear {
            // Stop all playback when leaving Lab tab
            engine.stop()
        }
    }
    
    private var modeSelector: some View {
        HStack(spacing: 0) {
            ForEach(LabMode.allCases, id: \.self) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 15, weight: selectedMode == mode ? .semibold : .regular))
                        .foregroundStyle(selectedMode == mode ? .white : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedMode == mode
                            ? Color.white.opacity(0.15)
                            : Color.clear
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.08), in: Capsule())
    }
}
