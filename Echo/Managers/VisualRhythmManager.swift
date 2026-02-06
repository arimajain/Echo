import Foundation
import AVFoundation

// MARK: - VisualRhythmManager

/// Orchestrates the "Visual Rhythm Mode" — aggressive screen pulses and
/// optional camera-flash (torch) bursts that let users **see** the beat.
///
/// ## Responsibilities
/// - Flash the rear torch on high-amplitude peaks (> ``torchThreshold``).
/// - Publish a ``particleBurstCount`` that views observe to fire SpriteKit particle bursts.
/// - Gate the entire mode behind an epilepsy / photosensitivity warning.
///
/// ## Safety
/// - The torch is rate-limited by ``torchCooldown`` (250 ms minimum between flashes)
///   to reduce seizure risk and protect the LED hardware.
/// - Torch availability is checked at every call (`hasTorch`, `isTorchAvailable`),
///   so iPads and Simulators never hit an unsafe code path.
///
/// ## Usage
/// ```swift
/// let vrm = VisualRhythmManager.shared
/// vrm.requestActivation()          // shows epilepsy warning sheet
/// // user taps "I Understand"
/// vrm.confirmActivation()          // isActive = true
/// vrm.processAmplitude(0.85)       // torch flashes + particle burst fires
/// vrm.deactivate()                 // cleans up, turns torch off
/// ```
@MainActor
final class VisualRhythmManager: ObservableObject {

    /// Shared singleton instance.
    static let shared = VisualRhythmManager()

    // MARK: - Published State

    /// Whether Visual Rhythm Mode is currently active.
    @Published private(set) var isActive: Bool = false

    /// Controls presentation of the epilepsy / photosensitivity warning sheet.
    @Published var showEpilepsyWarning: Bool = false

    /// Incremented each time a particle burst should fire.
    ///
    /// Views observe changes to this value (via `.onChange`) to trigger
    /// a `ParticleScene.emitBurst()` call.
    @Published private(set) var particleBurstCount: Int = 0

    // MARK: - Thresholds

    /// Amplitude above which the torch flashes. `0.8` means only the loudest peaks.
    let torchThreshold: Float = 0.8

    /// Amplitude above which a particle burst fires. Slightly lower than torch
    /// so snare-level hits produce particles even when not quite loud enough
    /// for a flash.
    let particleThreshold: Float = 0.7

    // MARK: - Cooldowns / Rate Limiting

    /// Minimum interval between consecutive torch flashes (seconds).
    private let torchCooldown: TimeInterval = 0.25

    /// How long the torch stays on per flash (seconds).
    private let torchFlashDuration: TimeInterval = 0.08

    /// Minimum interval between consecutive particle bursts (seconds).
    private let particleCooldown: TimeInterval = 0.30

    /// Timestamp of the last torch flash.
    private var lastTorchFlash: Date = .distantPast

    /// Timestamp of the last particle burst.
    private var lastParticleBurst: Date = .distantPast

    /// A cancellable work item that turns the torch off after ``torchFlashDuration``.
    private var torchOffWork: DispatchWorkItem?

    // MARK: - Initialization

    private init() {}

    // MARK: - Activation Flow

    /// Requests activation of Visual Rhythm Mode.
    ///
    /// This does **not** activate the mode immediately. Instead it presents
    /// the epilepsy warning sheet. The mode only activates once the user
    /// calls ``confirmActivation()``.
    func requestActivation() {
        showEpilepsyWarning = true
    }

    /// Called when the user acknowledges the photosensitivity warning.
    ///
    /// Sets ``isActive`` to `true` and dismisses the warning sheet.
    func confirmActivation() {
        isActive = true
        showEpilepsyWarning = false
        print("VisualRhythmManager: 🎆 Visual Rhythm Mode activated.")
    }

    /// Deactivates Visual Rhythm Mode and ensures the torch is off.
    func deactivate() {
        isActive = false
        torchOffWork?.cancel()
        setTorch(on: false)
        print("VisualRhythmManager: Visual Rhythm Mode deactivated.")
    }

    // MARK: - Beat Processing

    /// Evaluates the current audio amplitude and triggers visual effects
    /// when thresholds are exceeded.
    ///
    /// Call this on every amplitude update from ``AudioManager``.
    ///
    /// - Parameter amplitude: The current RMS amplitude (`0.0 … 1.0`).
    func processAmplitude(_ amplitude: Float) {
        guard isActive else { return }

        // ── Torch flash on loud peaks ───────────────────────────────────
        if amplitude > torchThreshold {
            flashTorch()
        }

        // ── Particle burst on snare-level peaks ─────────────────────────
        if amplitude > particleThreshold {
            triggerParticleBurst()
        }
    }

    // MARK: - Torch Control

    /// Briefly flashes the rear camera torch, respecting the cooldown window.
    private func flashTorch() {
        let now = Date()
        guard now.timeIntervalSince(lastTorchFlash) >= torchCooldown else { return }
        lastTorchFlash = now

        setTorch(on: true)

        // Schedule auto-off after `torchFlashDuration`.
        torchOffWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.setTorch(on: false)
            }
        }
        torchOffWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + torchFlashDuration, execute: work)
    }

    /// Low-level torch toggle with full hardware safety checks.
    ///
    /// - Parameter on: `true` to turn the torch on, `false` to turn it off.
    ///
    /// Safe to call on devices without a torch (iPad, Simulator) — the function
    /// returns silently if the hardware is unavailable.
    func setTorch(on: Bool) {
        #if targetEnvironment(simulator)
        if on {
            print("VisualRhythmManager: 🔦 Torch ON (simulated)")
        } else {
            print("VisualRhythmManager: 🔦 Torch OFF (simulated)")
        }
        return
        #else
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch,
              device.isTorchAvailable else {
            return
        }

        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("VisualRhythmManager: ⚠️ Torch toggle failed – \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Particle Burst

    /// Increments ``particleBurstCount`` so observing views can fire a particle effect.
    private func triggerParticleBurst() {
        let now = Date()
        guard now.timeIntervalSince(lastParticleBurst) >= particleCooldown else { return }
        lastParticleBurst = now
        particleBurstCount += 1
    }
}
