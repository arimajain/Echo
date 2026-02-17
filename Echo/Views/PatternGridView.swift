import SwiftUI
import UIKit
import Combine

/// Grid view for building tactile patterns step-by-step.
struct PatternGridView: View {
    @Binding var pattern: PatternModel
    let stepCount: Int
    var engine: TextureLabEngine? = nil
    
    /// Color mapping for each texture type
    private func color(for texture: TextureType) -> Color {
        switch texture {
        case .none:
            return Color.white.opacity(0.1)
        case .deepPulse:
            return Color.blue.opacity(0.6)
        case .sharpTap:
            return Color.red.opacity(0.6)
        case .rapidTexture:
            return Color.yellow.opacity(0.6)
        case .softWave:
            return Color.green.opacity(0.6)
        default:
            return Color.white.opacity(0.2)
        }
    }
    
    @State private var refreshID = UUID()
    
    var body: some View {
        let currentStep = engine?.currentStep ?? -1
        let isPlaying = engine?.isPlaying ?? false
        
        return VStack(spacing: 16) {
            // Grid with liquid glass design
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(0..<stepCount, id: \.self) { index in
                    gridCell(at: index, currentStep: currentStep, isPlaying: isPlaying)
                }
            }
        }
        .id(refreshID)
        .onReceive(engine?.objectWillChange.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()) { _ in
            // Force view refresh when engine publishes changes
            refreshID = UUID()
        }
    }
    
    @ViewBuilder
    private func gridCell(at index: Int, currentStep: Int, isPlaying: Bool) -> some View {
        // Bounds check to prevent index out of range
        // Always read from current pattern state, not a captured value
        if index >= 0 && index < pattern.steps.count {
            // Read step directly from pattern binding to ensure we have latest state
            let step = pattern.steps[index]
            let isActive = step.texture != .none
            let isPulsing = isPlaying && currentStep == index
            
            Button {
                // Get current texture and calculate next
                let currentTexture = pattern.steps[index].texture
                let nextTexture = currentTexture.next()
                
                // Update pattern directly
                var updatedPattern = pattern
                updatedPattern.cycleTexture(at: index)
                pattern = updatedPattern
                
                // Immediately update engine with new pattern (don't wait for onChange)
                engine?.setPattern(pattern)
                
                // Play the haptic pattern for the texture being selected (if not none)
                if nextTexture != .none {
                    if let hapticPattern = try? HapticPatternLibrary.texturePattern(for: nextTexture, baseIntensity: 1.0) {
                        _ = HapticManager.shared.playTexturePattern(hapticPattern, name: "Builder Select Step \(index + 1) - \(nextTexture.displayName)")
                    }
                }
            } label: {
                ZStack {
                    // Liquid glass background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            // Glassmorphic gradient
                            LinearGradient(
                                colors: cellGlassColors(
                                    isActive: isActive,
                                    texture: step.texture
                                ),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .background(
                            // Frosted glass blur effect
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            // Glass border with glow
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: cellBorderGradient(isActive: isActive),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: isActive ? 1.5 : 1
                                )
                        )
                        .shadow(
                            color: isActive ? cellGlowColor(texture: step.texture) : Color.clear,
                            radius: isActive ? 4 : 0,
                            x: 0,
                            y: 0
                        )
                        .shadow(
                            color: Color.black.opacity(0.3),
                            radius: isActive ? 8 : 3,
                            x: 0,
                            y: isActive ? 4 : 1
                        )
                        .shadow(
                            color: isActive ? Color.clear : Color.black.opacity(0.4),
                            radius: isActive ? 0 : 2,
                            x: 0,
                            y: isActive ? 0 : 1
                        )
                        .scaleEffect(isPulsing ? 1.02 : 1.0)
                        .shadow(
                            color: isPulsing ? cellGlowColor(texture: step.texture).opacity(0.25) : Color.clear,
                            radius: isPulsing ? 6 : 0,
                            x: 0,
                            y: 0
                        )
                        .frame(height: 60)
                        .animation(
                            .easeInOut(duration: 0.4),
                            value: isPulsing
                        )
                    
                    // Content with depth
                    if isActive {
                        ZStack {
                            // Subtle inner glow
                            Image(systemName: iconName(for: step.texture))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.95),
                                            .white.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: cellGlowColor(texture: step.texture).opacity(0.4), radius: 4)
                        }
                    } else {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.25),
                                        .white.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            // Fallback for out-of-bounds indices - liquid glass style
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                .frame(height: 60)
                .overlay(
                    Text("\(index + 1)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.2))
                )
        }
    }
    
    // MARK: - Cell Visual Helpers (Liquid Glass)
    
    private func cellGlassColors(isActive: Bool, texture: TextureType) -> [Color] {
        if isActive {
            // Active: colored glass with texture-specific tint - floats above
            let baseColor = color(for: texture)
            return [
                baseColor.opacity(0.25),
                baseColor.opacity(0.15),
                baseColor.opacity(0.08)
            ]
        } else {
            // Inactive: darker, more recessed frosted glass
            return [
                Color.white.opacity(0.06),
                Color.white.opacity(0.03),
                Color.white.opacity(0.01)
            ]
        }
    }
    
    private func cellBorderGradient(isActive: Bool) -> [Color] {
        if isActive {
            return [
                Color.white.opacity(0.6),
                Color.white.opacity(0.3),
                Color.white.opacity(0.4)
            ]
        } else {
            return [
                Color.white.opacity(0.2),
                Color.white.opacity(0.1),
                Color.white.opacity(0.15)
            ]
        }
    }
    
    private func cellGlowColor(texture: TextureType) -> Color {
        switch texture {
        case .deepPulse:
            return Color.blue.opacity(0.18)
        case .sharpTap:
            return Color.red.opacity(0.18)
        case .rapidTexture:
            return Color.yellow.opacity(0.18)
        case .softWave:
            return Color.green.opacity(0.18)
        default:
            return Color.white.opacity(0.12)
        }
    }
    
    private func iconName(for texture: TextureType) -> String {
        switch texture {
        case .deepPulse:
            return "waveform.path"
        case .sharpTap:
            return "circle.fill"
        case .rapidTexture:
            return "sparkles"
        case .softWave:
            return "waveform"
        default:
            return ""
        }
    }
}
