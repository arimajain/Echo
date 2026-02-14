import Foundation
import SwiftUI

/// Manages the current fluid background state and provides controls to switch
/// between different fluid types with smooth animations.
@MainActor
final class FluidBackgroundManager: ObservableObject {

    /// Shared singleton instance.
    static let shared = FluidBackgroundManager()

    /// The currently active fluid type.
    @Published var activeType: FluidType = .aurora

    // MARK: - Initialization

    private init() {}

    // MARK: - Mode Control

    /// Sets the active fluid type with animation.
    ///
    /// - Parameter type: The fluid type to activate.
    func setMode(_ type: FluidType) {
        withAnimation(.easeInOut(duration: 1.0)) {
            activeType = type
        }
        print("FluidBackgroundManager: Switched to \(type.displayName) mode.")
    }

    /// Cycles to the next fluid type in the sequence.
    ///
    /// Order: `.aurora` → `.magma` → `.mercury` → `.aurora` (loops).
    func cycleMode() {
        let allTypes = FluidType.allCases
        guard let currentIndex = allTypes.firstIndex(of: activeType) else {
            setMode(.aurora)
            return
        }

        let nextIndex = (currentIndex + 1) % allTypes.count
        setMode(allTypes[nextIndex])
    }
}
