import SpriteKit
import UIKit

// MARK: - ParticleScene

/// A lightweight SpriteKit scene that emits beat-driven particle bursts.
///
/// `ParticleScene` is overlaid behind the main SwiftUI controls via `SpriteView`.
/// When ``VisualRhythmManager`` detects a snare-level peak it increments
/// `particleBurstCount`, and the hosting view calls ``emitBurst()`` to
/// spray a short-lived fan of glowing particles from the center of the screen.
///
/// ## Design Choices
/// - **No .sks file required** — the emitter is configured entirely in code
///   for portability and Student Challenge compliance.
/// - **Additive blending** gives particles a neon-glow look against the dark
///   background without occluding the visualizer underneath.
/// - Particles auto-remove after their lifetime expires, keeping the node
///   tree lean.
///
/// ## Usage
/// ```swift
/// let scene = ParticleScene(size: proxy.size)
/// SpriteView(scene: scene, options: [.allowsTransparency])
/// ```
final class ParticleScene: SKScene {

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        view.allowsTransparency = true
        scaleMode = .resizeFill
    }

    // MARK: - Burst API

    /// Emits a radial burst of particles from the center of the scene.
    ///
    /// Each call creates a fresh `SKEmitterNode` with a short lifetime.
    /// The node removes itself once all particles have died, so repeated
    /// calls don't leak nodes.
    func emitBurst() {
        let emitter = makeEmitter()
        emitter.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(emitter)

        // Self-cleanup after all particles expire.
        let totalLifetime = Double(emitter.particleLifetime + emitter.particleLifetimeRange) + 0.3
        emitter.run(.sequence([
            .wait(forDuration: totalLifetime),
            .removeFromParent()
        ]))
    }

    // MARK: - Emitter Factory

    /// Creates and configures a programmatic particle emitter.
    ///
    /// The emitter is designed for a single short burst:
    /// - `numParticlesToEmit = 50` limits the fan to exactly 50 particles.
    /// - `particleBirthRate = 500` fires them all within ~0.1 s.
    /// - Full 360° emission angle with speed variation for a natural scatter.
    private func makeEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()

        // ── Count & Timing ──────────────────────────────────────────
        emitter.particleBirthRate       = 500       // fast burst
        emitter.numParticlesToEmit      = 50        // exactly 50 particles per burst

        // ── Lifetime ────────────────────────────────────────────────
        emitter.particleLifetime        = 0.7
        emitter.particleLifetimeRange   = 0.3

        // ── Motion ──────────────────────────────────────────────────
        emitter.emissionAngleRange      = .pi * 2   // full 360° spray
        emitter.particleSpeed           = 220
        emitter.particleSpeedRange      = 120

        // ── Appearance ──────────────────────────────────────────────
        emitter.particleAlpha           = 0.9
        emitter.particleAlphaRange      = 0.1
        emitter.particleAlphaSpeed      = -1.2      // fade out over lifetime

        emitter.particleScale           = 0.06
        emitter.particleScaleRange      = 0.03
        emitter.particleScaleSpeed      = -0.02     // shrink slightly as they fly

        emitter.particleBlendMode       = .add      // neon glow

        // ── Color (cyan → purple gradient over lifetime) ────────────
        emitter.particleColor           = .cyan
        emitter.particleColorBlendFactor = 1.0

        let colorSequence = SKKeyframeSequence(
            keyframeValues: [UIColor.cyan, UIColor.systemPurple, UIColor.white.withAlphaComponent(0.0)],
            times: [0.0, 0.5, 1.0]
        )
        colorSequence.interpolationMode = .linear
        emitter.particleColorSequence   = colorSequence

        // ── Texture (generated circle — no asset dependency) ────────
        emitter.particleTexture         = generateCircleTexture(diameter: 12)

        return emitter
    }

    // MARK: - Texture Generation

    /// Renders a small filled-circle image in code so we don't depend on any
    /// external asset file.
    ///
    /// - Parameter diameter: The diameter of the circle in points.
    /// - Returns: An `SKTexture` containing a white filled circle.
    private func generateCircleTexture(diameter: CGFloat) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }
}
