import SwiftUI

/// The deep, shifting background gradient layer for the fluid background.
///
/// Renders a smooth gradient using the FluidType's color palette with
/// animated transitions when the type changes.
struct FluidGradientView: View {
    let type: FluidType

    var body: some View {
        LinearGradient(
            colors: type.palette,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 2.0), value: type)
    }
}
