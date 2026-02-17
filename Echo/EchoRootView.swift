import SwiftUI

/// High-level container that gives Echo a Letter Flow–style start screen
/// before dropping into the existing immersive `ContentView`.
struct EchoRootView: View {
    var body: some View {
        TrackListView()
            .preferredColorScheme(.dark)
    }
}

#Preview {
    EchoRootView()
        .preferredColorScheme(.dark)
}

