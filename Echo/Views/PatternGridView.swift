import SwiftUI
import UIKit
import Combine

/// Grid view for building tactile patterns step-by-step.
/// Uses quadrant-based tiles: each tile divided into 4 zones for direct texture assignment.
struct PatternGridView: View {
    @Binding var pattern: PatternModel
    let stepCount: Int
    var engine: TextureLabEngine? = nil
    
    /// Texture color mapping
    private func color(for texture: TextureType) -> Color {
        switch texture {
        case .deepPulse: return .blue
        case .sharpTap: return .yellow
        case .rapidTexture: return .purple
        case .softWave: return .green
        default: return .white
        }
    }
    
    /// Icon name for each texture
    private func iconName(for texture: TextureType) -> String {
        switch texture {
        case .deepPulse: return "waveform.path"
        case .sharpTap: return "circle.fill"
        case .rapidTexture: return "chart.bar.fill"
        case .softWave: return "waveform"
        default: return ""
        }
    }
    
    @State private var refreshID = UUID()
    
    var body: some View {
        let currentStep = engine?.currentStep ?? -1
        let isPlaying = engine?.isPlaying ?? false
        
        return VStack(spacing: 16) {
            // Clean grid with quadrant-based tiles
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(0..<stepCount, id: \.self) { index in
                    quadrantTile(at: index, currentStep: currentStep, isPlaying: isPlaying)
                }
            }
        }
        .id(refreshID)
        .onReceive(engine?.objectWillChange.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()) { _ in
            refreshID = UUID()
        }
    }
    
    @ViewBuilder
    private func quadrantTile(at index: Int, currentStep: Int, isPlaying: Bool) -> some View {
        if index >= 0 && index < pattern.steps.count {
            let step = pattern.steps[index]
            let isCurrentStep = isPlaying && currentStep == index
            let hasDeep = step.textures.contains(.deepPulse)
            let hasSharp = step.textures.contains(.sharpTap)
            let hasRapid = step.textures.contains(.rapidTexture)
            let hasSoft = step.textures.contains(.softWave)
            let hasAny = !step.isEmpty
            
            ZStack {
                // Base tile: dark matte fill
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                // 2x2 Grid structure for quadrants
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // Top-left: Deep
                        quadrantCell(
                            texture: .deepPulse,
                            isActive: hasDeep,
                            isCurrentStep: isCurrentStep,
                            index: index
                        )
                        
                        // Top-right: Sharp
                        quadrantCell(
                            texture: .sharpTap,
                            isActive: hasSharp,
                            isCurrentStep: isCurrentStep,
                            index: index
                        )
                    }
                    
                    HStack(spacing: 0) {
                        // Bottom-left: Rapid
                        quadrantCell(
                            texture: .rapidTexture,
                            isActive: hasRapid,
                            isCurrentStep: isCurrentStep,
                            index: index
                        )
                        
                        // Bottom-right: Soft
                        quadrantCell(
                            texture: .softWave,
                            isActive: hasSoft,
                            isCurrentStep: isCurrentStep,
                            index: index
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Subtle divider lines (cross pattern)
                GeometryReader { geometry in
                    // Vertical divider (centered)
                    Rectangle()
                        .fill(Color.white.opacity(0.03))
                        .frame(width: 1)
                        .frame(height: geometry.size.height)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    
                    // Horizontal divider (centered)
                    Rectangle()
                        .fill(Color.white.opacity(0.03))
                        .frame(width: geometry.size.width, height: 1)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                
               
                
                // Step number (centered, above everything except playhead glow)
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
                    .zIndex(1)
            }
            .scaleEffect(isCurrentStep ? 1.03 : 1.0)
            .shadow(
                color: isCurrentStep ? Color.white.opacity(0.15) : Color.clear,
                radius: isCurrentStep ? 8 : 0
            )
            .animation(.easeInOut(duration: 0.2), value: isCurrentStep)
            .frame(height: 80)
        } else {
            // Fallback for out-of-bounds
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.4))
                .frame(height: 80)
        }
    }
    
    @ViewBuilder
    private func quadrantCell(
        texture: TextureType,
        isActive: Bool,
        isCurrentStep: Bool,
        index: Int
    ) -> some View {
        let baseColor = color(for: texture)
        let icon = iconName(for: texture)
        
        ZStack {
            // Quadrant background (transparent when inactive, colored when active)
            if isActive {
                Rectangle()
                    .fill(baseColor.opacity(0.15))
                    .overlay(
                        // Subtle inner glow when active
                        Rectangle()
                            .fill(baseColor.opacity(isCurrentStep ? 0.3 : 0.08))
                    )
            } else {
                Color.clear
            }
            
            // Icon in center of quadrant
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(isActive ? 0.1 : 0.03))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleTexture(texture, at: index)
        }
    }
    
    /// Blends colors from active quadrants to create background color for step number
    private func blendActiveQuadrantColors(hasDeep: Bool, hasSharp: Bool, hasRapid: Bool, hasSoft: Bool) -> Color {
        var red: Double = 0
        var green: Double = 0
        var blue: Double = 0
        var totalWeight: Double = 0
        
        // Deep Pulse (Blue: 0, 0, 1)
        if hasDeep {
            totalWeight += 1
            blue += 1
        }
        
        // Sharp Tap (Yellow: 1, 1, 0)
        if hasSharp {
            totalWeight += 1
            red += 1
            green += 1
        }
        
        // Rapid Texture (Purple: 0.5, 0, 1)
        if hasRapid {
            totalWeight += 1
            red += 0.5
            blue += 1
        }
        
        // Soft Wave (Green: 0, 1, 0)
        if hasSoft {
            totalWeight += 1
            green += 1
        }
        
        guard totalWeight > 0 else {
            return .white
        }
        
        red /= totalWeight
        green /= totalWeight
        blue /= totalWeight
        
        return Color(red: red, green: green, blue: blue)
    }
    
    private func toggleTexture(_ texture: TextureType, at index: Int) {
        var updatedPattern = pattern
        updatedPattern.toggleTexture(texture, at: index)
        pattern = updatedPattern
        
        // Immediately update engine
        engine?.setPattern(pattern)
        
        // Preview haptic for the toggled texture
        let newStep = pattern.steps[index]
        if newStep.textures.contains(texture) {
            // Texture was added - play preview
            if let hapticPattern = try? HapticPatternLibrary.texturePattern(for: texture, baseIntensity: 1.0) {
                _ = HapticManager.shared.playTexturePattern(
                    hapticPattern,
                    name: "Builder Toggle Step \(index + 1) - \(texture.displayName)"
                )
            }
        }
    }
}
