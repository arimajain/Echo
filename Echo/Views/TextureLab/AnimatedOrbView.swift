import SwiftUI
import MetalKit
import Metal
import UIKit

/// Animated orb view with noise-based surface, color hue adjustment, and hover effects.
/// Converted from TypeScript/WebGL to iOS/Metal.
struct AnimatedOrbView: UIViewRepresentable {
    /// Hue adjustment in degrees (0-360)
    var hue: Float = 0
    
    /// Hover intensity (0.0-1.0)
    var hoverIntensity: Float = 0.2
    
    /// Whether to rotate on hover
    var rotateOnHover: Bool = true
    
    /// Force hover state (for testing)
    var forceHoverState: Bool = false
    
    /// Whether haptics are active (controls hover state)
    var hapticsActive: Bool = false
    
    /// Background color (affects blending)
    var backgroundColor: Color = .black
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        let mtkView = MTKView()
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.isOpaque = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
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
        
        context.coordinator.setup(mtkView: mtkView, container: containerView)
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.update(
            hue: hue,
            hoverIntensity: hoverIntensity,
            rotateOnHover: rotateOnHover,
            forceHoverState: forceHoverState,
            hapticsActive: hapticsActive,
            backgroundColor: backgroundColor
        )
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    final class Coordinator: NSObject, MTKViewDelegate {
        private var device: MTLDevice?
        private var commandQueue: MTLCommandQueue?
        private var renderPipelineState: MTLRenderPipelineState?
        private var vertexBuffer: MTLBuffer?
        
        private var time: Float = 0
        private var lastTime: CFTimeInterval = 0
        private var targetHover: Float = 0
        private var currentHover: Float = 0
        private var currentRot: Float = 0
        private let rotationSpeed: Float = 0.3
        
        private var hue: Float = 0
        private var hoverIntensity: Float = 0.2
        private var rotateOnHover: Bool = true
        private var forceHoverState: Bool = false
        private var hapticsActive: Bool = false
        private var backgroundColor: Color = .black
        
        private weak var mtkView: MTKView?
        private weak var containerView: UIView?
        
        func setup(mtkView: MTKView, container: UIView) {
            guard let device = mtkView.device else { return }
            self.device = device
            self.mtkView = mtkView
            self.containerView = container
            self.commandQueue = device.makeCommandQueue()
            
            // Full-screen quad vertices with UV coordinates
            let vertices: [Float] = [
                // Position      UV
                -1.0, -1.0,     0.0, 0.0,
                 1.0, -1.0,     1.0, 0.0,
                -1.0,  1.0,     0.0, 1.0,
                 1.0,  1.0,     1.0, 1.0
            ]
            vertexBuffer = device.makeBuffer(
                bytes: vertices,
                length: vertices.count * MemoryLayout<Float>.size,
                options: []
            )
            
            guard let library = device.makeDefaultLibrary(),
                  let vertexFunction = library.makeFunction(name: "orb_vertex"),
                  let fragmentFunction = library.makeFunction(name: "orb_fragment") else {
                print("AnimatedOrbView: ⚠️ Failed to load Metal shader functions")
                return
            }
            
            let vertexDescriptor = MTLVertexDescriptor()
            vertexDescriptor.attributes[0].format = .float2
            vertexDescriptor.attributes[0].offset = 0
            vertexDescriptor.attributes[0].bufferIndex = 0
            vertexDescriptor.attributes[1].format = .float2
            vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 2
            vertexDescriptor.attributes[1].bufferIndex = 0
            vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 4
            vertexDescriptor.layouts[0].stepRate = 1
            vertexDescriptor.layouts[0].stepFunction = .perVertex
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.vertexDescriptor = vertexDescriptor
            pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            do {
                renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                print("AnimatedOrbView: ⚠️ Failed to create render pipeline state: \(error)")
                return
            }
            
            mtkView.delegate = self
            lastTime = CACurrentMediaTime()
            
            // Setup touch handling
            setupTouchHandling()
        }
        
        private func setupTouchHandling() {
            // Touch handling removed - hover is now controlled by hapticsActive
        }
        
        func update(hue: Float, hoverIntensity: Float, rotateOnHover: Bool, forceHoverState: Bool, hapticsActive: Bool, backgroundColor: Color) {
            self.hue = hue
            self.hoverIntensity = hoverIntensity
            self.rotateOnHover = rotateOnHover
            self.forceHoverState = forceHoverState
            self.hapticsActive = hapticsActive
            self.backgroundColor = backgroundColor
            
            // Update target hover based on haptics active state
            targetHover = hapticsActive ? 1.0 : 0.0
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle resize if needed
        }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let renderPipelineState = renderPipelineState,
                  let commandBuffer = commandQueue?.makeCommandBuffer(),
                  let renderPassDescriptor = view.currentRenderPassDescriptor else {
                return
            }
            
            let currentTime = CACurrentMediaTime()
            let dt = Float(max(0, currentTime - lastTime))
            lastTime = currentTime
            time += dt
            
            // Smooth hover interpolation
            // Use hapticsActive to control hover (or forceHoverState for testing)
            let effectiveHover: Float = forceHoverState ? 1.0 : (hapticsActive ? 1.0 : 0.0)
            currentHover += (effectiveHover - currentHover) * 0.1
            
            // Rotation on hover
            if rotateOnHover && effectiveHover > 0.5 {
                currentRot += dt * rotationSpeed
            }
            
            // Convert background color to RGB
            let bgColor = UIColor(backgroundColor)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            bgColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            let backgroundColorVec = SIMD3<Float>(Float(red), Float(green), Float(blue))
            
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(renderPipelineState)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            // Set shader uniforms
            var iTime = time
            let drawableWidth = Float(view.drawableSize.width)
            let drawableHeight = Float(view.drawableSize.height)
            var iResolution = SIMD2<Float>(drawableWidth, drawableHeight)
            var hueValue = hue
            var hoverValue = currentHover
            var rotValue = currentRot
            var hoverIntensityValue = hoverIntensity
            var backgroundColorValue = backgroundColorVec
            
            renderEncoder.setFragmentBytes(&iTime, length: MemoryLayout<Float>.size, index: 0)
            renderEncoder.setFragmentBytes(&iResolution, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
            renderEncoder.setFragmentBytes(&hueValue, length: MemoryLayout<Float>.size, index: 2)
            renderEncoder.setFragmentBytes(&hoverValue, length: MemoryLayout<Float>.size, index: 3)
            renderEncoder.setFragmentBytes(&rotValue, length: MemoryLayout<Float>.size, index: 4)
            renderEncoder.setFragmentBytes(&hoverIntensityValue, length: MemoryLayout<Float>.size, index: 5)
            renderEncoder.setFragmentBytes(&backgroundColorValue, length: MemoryLayout<SIMD3<Float>>.size, index: 6)
            
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
