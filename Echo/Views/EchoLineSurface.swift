import SwiftUI
import MetalKit
import Metal
import UIKit
import Combine

/// Audio-reactive horizontal line surface rendered with Metal.
///
/// Displays 8 parallel horizontal lines whose thickness changes based on
/// FFT frequency bands. Supports two modes:
/// - **Calm**: Subtle, smooth animations with softer colors
/// - **Accessibility**: Higher contrast, stronger visual feedback
struct EchoLineSurface: UIViewRepresentable {
    typealias UIViewType = UIView
    
    /// Rendering mode: `.calm` or `.accessibility`
    var mode: RenderingMode
    
    /// Whether the surface should be visible (fades out when paused).
    var isActive: Bool
    
    /// Audio manager to observe for frequency bands.
    @ObservedObject var audioManager: AudioManager
    
    enum RenderingMode {
        case calm
        case accessibility
        
        /// Decay factor for amplitude smoothing (higher = smoother).
        var decay: Float {
            switch self {
            case .calm: return 0.9
            case .accessibility: return 0.75
            }
        }
        
        /// Base line thickness in pixels.
        var baseThickness: Float {
            switch self {
            case .calm: return 2.0
            case .accessibility: return 3.0
            }
        }
        
        /// Scale factor for amplitude-to-thickness mapping (in pixels).
        var scaleFactor: Float {
            switch self {
            case .calm: return 12.0
            case .accessibility: return 26.0
            }
        }

        
        /// Blur amount for soft edges.
        var blur: Float {
            switch self {
            case .calm: return 2.0
            case .accessibility: return 1.2
            }
        }

        
        /// Line brightness (0.0-1.0).
        var lineBrightness: Float {
            switch self {
            case .calm: return 0.6
            case .accessibility: return 0.95
            }
        }
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .black
        containerView.isOpaque = true
        
        let mtkView = MTKView()
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.isOpaque = true
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        
        // Target 60fps for smooth animation
        mtkView.preferredFramesPerSecond = 60
        mtkView.framebufferOnly = true
        mtkView.presentsWithTransaction = false
        
        containerView.addSubview(mtkView)
        NSLayoutConstraint.activate([
            mtkView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            mtkView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            mtkView.topAnchor.constraint(equalTo: containerView.topAnchor),
            mtkView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        context.coordinator.setup(mtkView: mtkView, mode: mode, audioManager: audioManager)
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.update(mode: mode, isActive: isActive)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    final class Coordinator: NSObject, MTKViewDelegate {
        var device: MTLDevice!
        var commandQueue: MTLCommandQueue!
        var renderPipelineState: MTLRenderPipelineState!
        var vertexBuffer: MTLBuffer!
        
        var time: Float = 0.0
        var resolution: SIMD2<Float> = SIMD2<Float>(1, 1)
        var lastTime: CFTimeInterval = 0
        
        // Amplitude smoothing state (32 bands)
        var smoothedBands: [Float] = Array(repeating: 0.0, count: 32)
        var currentMode: RenderingMode = .calm
        var isActive: Bool = true
        
        // Smooth opacity interpolation
        var targetOpacity: Float = 1.0
        var currentOpacity: Float = 1.0
        
        // Audio manager subscription
        private var cancellables = Set<AnyCancellable>()
        private weak var audioManager: AudioManager?
        
        func setup(mtkView: MTKView, mode: RenderingMode, audioManager: AudioManager) {
            guard let device = mtkView.device else { return }
            self.device = device
            self.audioManager = audioManager
            self.currentMode = mode
            commandQueue = device.makeCommandQueue()
            
            // Full-screen quad vertices
            let vertices: [Float] = [
                -1.0, -1.0,
                 1.0, -1.0,
                -1.0,  1.0,
                 1.0,  1.0
            ]
            vertexBuffer = device.makeBuffer(
                bytes: vertices,
                length: vertices.count * MemoryLayout<Float>.size,
                options: []
            )
            
            guard let library = device.makeDefaultLibrary(),
                  let vertexFunction = library.makeFunction(name: "echo_line_vertex"),
                  let fragmentFunction = library.makeFunction(name: "echo_line_fragment") else {
                print("EchoLineSurface: ⚠️ Failed to load Metal shader functions")
                return
            }
            
            let vertexDescriptor = MTLVertexDescriptor()
            vertexDescriptor.attributes[0].format = .float2
            vertexDescriptor.attributes[0].offset = 0
            vertexDescriptor.attributes[0].bufferIndex = 0
            vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 2
            vertexDescriptor.layouts[0].stepRate = 1
            vertexDescriptor.layouts[0].stepFunction = .perVertex
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.vertexDescriptor = vertexDescriptor
            pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
            
            do {
                renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                print("EchoLineSurface: ⚠️ Failed to create render pipeline – \(error.localizedDescription)")
                return
            }
            
            lastTime = CACurrentMediaTime()
            mtkView.delegate = self
            
            // Subscribe to frequency bands (must access on main actor)
            // Since setup is called from makeUIView which is on main thread,
            // we can safely access main actor properties here
            Task { @MainActor in
                guard let audioManager = self.audioManager else { return }
                // Initialize with current bands immediately
                let initialBands = audioManager.frequencyBands
                if !initialBands.isEmpty {
                    self.updateSmoothedBands(newBands: initialBands)
                }
                
                audioManager.$frequencyBands
                    .sink { [weak self] bands in
                        guard let self else { return }
                        self.updateSmoothedBands(newBands: bands)
                    }
                    .store(in: &self.cancellables)
            }
        }
        
        func update(mode: RenderingMode, isActive: Bool) {
            self.currentMode = mode
            self.isActive = isActive
            self.targetOpacity = isActive ? 1.0 : 0.0
        }
        
        // Debug counter for printing (instance variable)
        private var debugPrintCounter: Int = 0
        
        /// Applies amplitude smoothing: A_smoothed = previous * decay + newValue * (1 - decay)
        private func updateSmoothedBands(newBands: [Float]) {
            guard newBands.count == 32 else { return }
            let decay = currentMode.decay
            let oneMinusDecay = 1.0 - decay
            
            for i in 0..<32 {
                smoothedBands[i] = smoothedBands[i] * decay + newBands[i] * oneMinusDecay
            }
            // Debug: Print band values occasionally to verify they're updating
            #if DEBUG
            debugPrintCounter += 1
            if debugPrintCounter % 60 == 0 {  // Print every 60 updates (~1 second at 60fps)
                print("EchoLineSurface bands: \(smoothedBands.map { String(format: "%.2f", $0) }.joined(separator: ", "))")
            }
            #endif
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            resolution = SIMD2<Float>(Float(size.width), Float(size.height))
        }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let renderPipelineState,
                  let commandBuffer = commandQueue?.makeCommandBuffer(),
                  let renderPassDescriptor = view.currentRenderPassDescriptor else {
                return
            }
            
            let currentTime = CACurrentMediaTime()
            let dt = Float(max(0, currentTime - lastTime))
            lastTime = currentTime
            time += dt
            
            // Smooth opacity interpolation (fade out when paused)
            let fadeSpeed: Float = 2.0  // Fade speed per second
            if currentOpacity < targetOpacity {
                currentOpacity = min(currentOpacity + dt * fadeSpeed, targetOpacity)
            } else if currentOpacity > targetOpacity {
                currentOpacity = max(currentOpacity - dt * fadeSpeed, targetOpacity)
            }
            let opacity = currentOpacity
            
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(renderPipelineState)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            // Prepare shader parameters
            var bandAmplitudes = smoothedBands
            var timeValue = time
            var resolutionValue = resolution
            var baseThickness = currentMode.baseThickness
            var scaleFactor = currentMode.scaleFactor
            var blur = currentMode.blur
            var lineBrightness = currentMode.lineBrightness
            var waveEnabled: Float = 1.0  // Disable wave by default for minimal design
            var waveSpeed: Float = 1.2
            var waveAmplitude: Float = 1.0
            var opacityValue = opacity
            
            renderEncoder.setFragmentBytes(&bandAmplitudes, length: MemoryLayout<Float>.size * 32, index: 0)
            renderEncoder.setFragmentBytes(&timeValue, length: MemoryLayout<Float>.size, index: 1)
            renderEncoder.setFragmentBytes(&resolutionValue, length: MemoryLayout<SIMD2<Float>>.size, index: 2)
            renderEncoder.setFragmentBytes(&baseThickness, length: MemoryLayout<Float>.size, index: 3)
            renderEncoder.setFragmentBytes(&scaleFactor, length: MemoryLayout<Float>.size, index: 4)
            renderEncoder.setFragmentBytes(&blur, length: MemoryLayout<Float>.size, index: 5)
            renderEncoder.setFragmentBytes(&lineBrightness, length: MemoryLayout<Float>.size, index: 6)
            renderEncoder.setFragmentBytes(&waveEnabled, length: MemoryLayout<Float>.size, index: 7)
            renderEncoder.setFragmentBytes(&waveSpeed, length: MemoryLayout<Float>.size, index: 8)
            renderEncoder.setFragmentBytes(&waveAmplitude, length: MemoryLayout<Float>.size, index: 9)
            renderEncoder.setFragmentBytes(&opacityValue, length: MemoryLayout<Float>.size, index: 10)
            
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var audioManager = AudioManager.shared
        @State private var mode: EchoLineSurface.RenderingMode = .calm
        @State private var isActive = true
        
        var body: some View {
            ZStack {
                EchoLineSurface(
                    mode: mode,
                    isActive: isActive,
                    audioManager: audioManager
                )
                .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    HStack {
                        Button("Calm") {
                            mode = .calm
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Accessibility") {
                            mode = .accessibility
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(isActive ? "Pause" : "Play") {
                            isActive.toggle()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .onAppear {
                // Start playback for preview
                audioManager.play()
            }
        }
    }
    
    return PreviewWrapper()
}
