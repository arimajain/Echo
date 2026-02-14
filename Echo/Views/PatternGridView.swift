import SwiftUI

/// Grid view for building tactile patterns step-by-step.
struct PatternGridView: View {
    @Binding var pattern: PatternModel
    let stepCount: Int
    
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
    
    var body: some View {
        VStack(spacing: 12) {
            // Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(0..<stepCount, id: \.self) { index in
                    gridCell(at: index)
                }
            }
        }
    }
    
    private func gridCell(at index: Int) -> some View {
        let step = pattern.steps[index]
        let isActive = step.texture != .none
        
        return Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                pattern.cycleTexture(at: index)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color(for: step.texture))
                    .frame(height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(isActive ? 0.4 : 0.1), lineWidth: 1)
                    )
                
                if isActive {
                    Image(systemName: iconName(for: step.texture))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .buttonStyle(.plain)
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
