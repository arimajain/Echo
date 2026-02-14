import SwiftUI
import MetalKit
import Metal
import UIKit

/// Letter Flow–style aurora lights Metal background, tuned for Echo.
///
/// This is a lightly adapted copy of `AuroraView` from Letter Flow, wrapped
/// in a more Swifty API for Echo and focused on iPhone performance.
struct AuroraBackgroundView: UIViewRepresentable {
    typealias UIViewType = UIView
    
    /// Drives subtle brightness and motion; typically bound to audio amplitude.
    var amplitude: Float
    
    /// Overall animation speed multiplier.
    var speed: Float
    
    /// How wide the aurora band is ($0 \dots 1$).
    var blend: Float
    
    /// Optional explicit colors; when empty, cycles through built-in palettes.
    var colorStops: [Color] = []
    
    // Multiple color palettes for smooth transitions.
    private let colorPalettes: [[Color]] = [
        // Classic Purple-Green
        [
            Color(red: 0.32, green: 0.15, blue: 1.0),
            Color(red: 0.49, green: 1.0,  blue: 0.40),
            Color(red: 0.32, green: 0.15, blue: 1.0)
        ],
        // Blue-Pink-Green
        [
            Color(red: 0.2,  green: 0.4,  blue: 1.0),
            Color(red: 1.0,  green: 0.3,  blue: 0.8),
            Color(red: 0.3,  green: 0.9,  blue: 0.5),
            Color(red: 0.2,  green: 0.4,  blue: 1.0)
        ],
        // Purple-Pink-Red
        [
            Color(red: 0.4,  green: 0.1,  blue: 0.9),
            Color(red: 0.9,  green: 0.2,  blue: 0.7),
            Color(red: 1.0,  green: 0.3,  blue: 0.2),
            Color(red: 0.4,  green: 0.1,  blue: 0.9)
        ],
        // Green-Blue-Cyan
        [
            Color(red: 0.2,  green: 0.8,  blue: 0.4),
            Color(red: 0.1,  green: 0.6,  blue: 1.0),
            Color(red: 0.2,  green: 0.9,  blue: 0.9),
            Color(red: 0.2,  green: 0.8,  blue: 0.4)
        ]
    ]
    
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
        
        // iPhone‑friendly performance: lower FPS and resolution for background only.
        mtkView.preferredFramesPerSecond = 30
        mtkView.framebufferOnly = true
        mtkView.presentsWithTransaction = false
        
        let backgroundScale = min(UIScreen.main.nativeScale, 1.5)
        mtkView.contentScaleFactor = backgroundScale
        mtkView.layer.contentsScale = backgroundScale
        mtkView.layer.magnificationFilter = .linear
        
        containerView.addSubview(mtkView)
        NSLayoutConstraint.activate([
            mtkView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            mtkView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            mtkView.topAnchor.constraint(equalTo: containerView.topAnchor),
            mtkView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        context.coordinator.setup(mtkView: mtkView)
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.update(
            colorStops: colorStops,
            amplitude: amplitude,
            blend: blend,
            speed: speed
        )
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(colorPalettes: colorPalettes)
    }
    
    final class Coordinator: NSObject, MTKViewDelegate {
        var device: MTLDevice!
        var commandQueue: MTLCommandQueue!
        var renderPipelineState: MTLRenderPipelineState!
        var vertexBuffer: MTLBuffer!
        var time: Float = 0.0
        var colorStops: [Color] = []
        var amplitude: Float = 1.0
        var blend: Float = 0.5
        var speed: Float = 1.0
        var resolution: SIMD2<Float> = SIMD2<Float>(1, 1)
        
        private let colorPalettes: [[Color]]
        private var palettesRGB: [[[Float]]] = []
        private var transitionTime: Float = 0.0
        private var lastTime: CFTimeInterval = 0
        private let transitionDuration: Float = 10.0
        
        init(colorPalettes: [[Color]]) {
            self.colorPalettes = colorPalettes
            super.init()
            
            palettesRGB = colorPalettes.map { palette in
                palette.map { color in
                    let uiColor = UIColor(color)
                    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                    uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                    return [Float(r), Float(g), Float(b)]
                }
            }
            if let first = colorPalettes.first {
                colorStops = first
            }
        }
        
        func setup(mtkView: MTKView) {
            guard let device = mtkView.device else { return }
            self.device = device
            commandQueue = device.makeCommandQueue()
            
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
                  let vertexFunction = library.makeFunction(name: "vertex_main"),
                  let fragmentFunction = library.makeFunction(name: "fragment_main") else {
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
                return
            }
            
            lastTime = CACurrentMediaTime()
            mtkView.delegate = self
        }
        
        func update(colorStops: [Color], amplitude: Float, blend: Float, speed: Float) {
            if !colorStops.isEmpty {
                self.colorStops = colorStops
            }
            self.amplitude = amplitude
            self.blend = blend
            self.speed = speed
        }
        
        private func currentColorsRGB() -> [SIMD3<Float>] {
            guard !palettesRGB.isEmpty else {
                var result: [SIMD3<Float>] = []
                for color in colorStops {
                    let uiColor = UIColor(color)
                    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                    uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                    result.append(SIMD3<Float>(Float(r), Float(g), Float(b)))
                }
                return result
            }
            
            let totalCycles = transitionTime / transitionDuration
            let cycleIndex = Int(floor(totalCycles)) % palettesRGB.count
            let normalizedTime = totalCycles - floor(totalCycles)
            
            let paletteIndex1 = cycleIndex
            let paletteIndex2 = (cycleIndex + 1) % palettesRGB.count
            
            let palette1 = palettesRGB[paletteIndex1]
            let palette2 = palettesRGB[paletteIndex2]
            
            let t = smoothStep(normalizedTime)
            
            let maxCount = max(palette1.count, palette2.count)
            var interpolated: [SIMD3<Float>] = []
            
            for i in 0..<maxCount {
                let c1 = palette1[min(i, palette1.count - 1)]
                let c2 = palette2[min(i, palette2.count - 1)]
                
                let r = c1[0] * (1.0 - t) + c2[0] * t
                let g = c1[1] * (1.0 - t) + c2[1] * t
                let b = c1[2] * (1.0 - t) + c2[2] * t
                
                interpolated.append(SIMD3<Float>(r, g, b))
            }
            return interpolated
        }
        
        private func smoothStep(_ t: Float) -> Float {
            let clamped = max(0.0, min(1.0, t))
            return clamped * clamped * (3.0 - 2.0 * clamped)
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
            let dt = Float(max(0, currentTime - lastTime)) * speed
            lastTime = currentTime
            time += dt
            transitionTime += dt
            
            var colors = currentColorsRGB()
            while colors.count < 2 {
                colors.append(SIMD3<Float>(0.5, 0.5, 0.5))
            }
            
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(renderPipelineState)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            var timeValue = time
            var amplitudeValue = amplitude
            var blendValue = blend
            var resolutionValue = resolution
            var colorCount = Int32(colors.count)
            
            let maxColors = 8
            var colorBuffer = Array(repeating: SIMD3<Float>(0, 0, 0), count: maxColors)
            for i in 0..<min(colors.count, maxColors) {
                colorBuffer[i] = colors[i]
            }
            
            renderEncoder.setFragmentBytes(&timeValue, length: MemoryLayout<Float>.size, index: 0)
            renderEncoder.setFragmentBytes(&amplitudeValue, length: MemoryLayout<Float>.size, index: 1)
            renderEncoder.setFragmentBytes(&colorBuffer, length: MemoryLayout<SIMD3<Float>>.size * maxColors, index: 2)
            renderEncoder.setFragmentBytes(&resolutionValue, length: MemoryLayout<SIMD2<Float>>.size, index: 3)
            renderEncoder.setFragmentBytes(&blendValue, length: MemoryLayout<Float>.size, index: 4)
            renderEncoder.setFragmentBytes(&colorCount, length: MemoryLayout<Int32>.size, index: 5)
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

#Preview {
    AuroraBackgroundView(
        amplitude: 0.4,
        speed: 1.0,
        blend: 0.8
    )
    .ignoresSafeArea()
}

