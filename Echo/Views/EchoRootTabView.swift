import SwiftUI

/// Root TabView with two primary experiences: Feel and Lab.
/// Feel is the default tab (immersive reactive music screen).
struct EchoRootTabView: View {
    @State private var selectedTab: Tab = .feel
    @StateObject private var audioManager = AudioManager.shared
    
    enum Tab: String, CaseIterable {
        case feel = "Feel"
        case lab = "Lab"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Feel (Default) - Immersive reactive music screen
            FeelTabView()
                .tag(Tab.feel)
                .tabItem {
                    Label("Feel", systemImage: "waveform")
                }
            
            // Tab 2: Lab - Structured tactile exploration
            LabTabView()
                .tag(Tab.lab)
                .tabItem {
                    Label("Lab", systemImage: "flask")
                }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Ensure Feel tab is selected on launch
            selectedTab = .feel
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Stop playback when switching tabs
            if oldValue != newValue {
                switch oldValue {
                case .feel:
                    // Stop audio when leaving Feel tab
                    audioManager.pause()
                case .lab:
                    // Stop haptic patterns when leaving Lab tab
                    // This is handled in TextureLabContainerView
                    break
                }
            }
        }
    }
}
