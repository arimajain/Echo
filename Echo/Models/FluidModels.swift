import SwiftUI

enum FluidType: CaseIterable {
    case aurora  // "Ether" - The default relaxing mode
    case magma   // "Rough" - Aggressive red/orange
    case mercury // "Sharp" - Fast silver/mint

    // Extracted from Letter Flow's BackgroundManager.swift
    var palette: [Color] {
        switch self {
        case .aurora:
            // "Neon Gradient Cards - Blue/Purple Theme"
            return [
                Color(red: 8/255, green: 12/255, blue: 25/255),       // Deep base
                Color(red: 25/255, green: 40/255, blue: 80/255),      // Dark transition
                Color(red: 60/255, green: 100/255, blue: 200/255),    // Bright blue
                Color(red: 120/255, green: 80/255, blue: 255/255)     // Neon purple
            ]
        case .magma:
            // "Cyberpunk Red-Orange Gradient"
            return [
                Color(red: 15/255, green: 5/255, blue: 10/255),
                Color(red: 40/255, green: 10/255, blue: 20/255),
                Color(red: 120/255, green: 30/255, blue: 40/255),
                Color(red: 255/255, green: 80/255, blue: 60/255)
            ]
        case .mercury:
            // "Holographic Silver-Metal"
            return [
                Color(red: 15/255, green: 15/255, blue: 20/255),
                Color(red: 40/255, green: 40/255, blue: 50/255),
                Color(red: 100/255, green: 100/255, blue: 120/255),
                Color(red: 200/255, green: 200/255, blue: 255/255)
            ]
        }
    }

    var blurRadius: CGFloat {
        switch self {
        case .aurora: return 45 // High blur for "Gaseous" look
        case .magma: return 30  // Medium blur for "Viscous" look
        case .mercury: return 15 // Low blur for "Liquid Metal" look
        }
    }

    /// Human-readable name for each type.
    var displayName: String {
        switch self {
        case .aurora: return "Aurora"
        case .magma: return "Magma"
        case .mercury: return "Mercury"
        }
    }
}
