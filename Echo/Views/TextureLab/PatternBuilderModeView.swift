import SwiftUI

/// Full-screen pattern builder mode with grid layout.
/// Static layout, no swipes.
struct PatternBuilderModeView: View {
    @ObservedObject var engine: TextureLabEngine
    @State private var pattern = PatternModel(stepCount: 16)
    @State private var tempo: Double = 70.0
    @State private var gridStepCount: Int = 16
    @State private var showPresets = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Presets button above grid
            HStack {
                Spacer()
                Button {
                    showPresets = true
                } label: {
                    Text("Presets")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                }
                .padding(.trailing, 20)
                .padding(.top, 8)
            }
            
            // Full-screen grid view (moved up, no title)
            PatternGridView(pattern: $pattern, stepCount: gridStepCount, engine: engine)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            
            // Compact controls at bottom
            VStack(spacing: 16) {
                // Step count selector
                stepCountSelector
                
                // Tempo control
                tempoControl
                
                // Action buttons
                actionButtons
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .onChange(of: pattern) { oldValue, newValue in
            // Update pattern live - playback continues if active
            engine.setPattern(newValue)
        }
        .onChange(of: gridStepCount) { oldValue, newValue in
            // When step count changes, create new pattern
            // Playback will continue if active (currentStep will be adjusted)
            pattern = PatternModel(stepCount: newValue)
            engine.setPattern(pattern)
        }
        .onChange(of: tempo) { oldValue, newValue in
            // Update tempo live - timer will be recreated with new interval
            // Playback continues from same step position
            engine.setTempo(newValue)
        }
        .sheet(isPresented: $showPresets) {
            PresetSelectionView(
                selectedPreset: { preset in
                    applyPreset(preset)
                    showPresets = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
    
    private func applyPreset(_ preset: BuilderPreset) {
        // Replace current pattern with preset
        withAnimation(.easeInOut(duration: 0.2)) {
            pattern = preset.toPatternModel()
            // Presets are 16 steps, ensure grid matches
            gridStepCount = 16
        }
        
        // Update engine
        engine.setPattern(pattern)
        engine.setTempo(tempo)
        
        // Automatically start playback
        engine.play()
    }
    
    private var stepCountSelector: some View {
        HStack(spacing: 8) {
            Text("Steps")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.6))
            
            ForEach([8, 16], id: \.self) { count in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        gridStepCount = count
                    }
                } label: {
                    Text("\(count)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(gridStepCount == count ? .black : .white.opacity(0.7))
                        .frame(width: 44, height: 32)
                        .background(
                            gridStepCount == count
                            ? Color.white
                            : Color.white.opacity(0.1)
                        )
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    private var tempoControl: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Tempo")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            }
            
            Slider(value: $tempo, in: 20...120, step: 1)
                .tint(.white.opacity(0.8))
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Clear button (secondary - outline style)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    pattern.clear()
                    engine.setPattern(pattern)
                }
            } label: {
                Text("Clear")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.clear)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Play/Stop button (primary - solid fill)
            Button {
                if engine.isPlaying {
                    engine.stop()
                } else {
                    engine.setTempo(tempo)
                    engine.setPattern(pattern)
                    engine.play()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: engine.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text(engine.isPlaying ? "Stop" : "Play")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(Capsule())
            }
            .scaleEffect(engine.isPlaying ? 1.0 : 1.0) // Can add subtle press animation if needed
        }
    }
}
