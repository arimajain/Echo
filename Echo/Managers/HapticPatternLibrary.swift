import Foundation
import CoreHaptics

/// Library of clearly distinguishable rhythm haptic patterns.
///
/// These are designed to be:
/// - Short and punchy for percussive events (kick / snare / hihat).
/// - Expressive for structural events (build / drop).
struct HapticPatternLibrary {

    // MARK: - Public API

    /// Returns a Core Haptics pattern for the given rhythm type.
    ///
    /// - Parameter type: High-level rhythm classification.
    /// - Parameter baseIntensity: Overall scaling factor (`0.0 ... 1.0`).
    static func pattern(for type: RhythmType, baseIntensity: Float = 1.0) throws -> CHHapticPattern {
        let scaled = max(0.0, min(baseIntensity, 1.0))

        switch type {
        case .kick:
            return try kick(intensityScale: scaled)
        case .snare:
            return try snare(intensityScale: scaled)
        case .hihat:
            return try hihat(intensityScale: scaled)
        case .build:
            return try build(intensityScale: scaled)
        case .drop:
            return try drop(intensityScale: scaled)
        }
    }

    // MARK: - Individual Patterns

    /// Kick: sharp attack, very short, maximum impact.
    ///
    /// - Intensity: 1.0 (scaled by `intensityScale`)
    /// - Duration: 0.08s
    /// - Shape: fast transient followed by micro tail.
    private static func kick(intensityScale: Float) throws -> CHHapticPattern {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                               value: 1.0 * intensityScale)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                               value: 0.8)

        let event = CHHapticEvent(eventType: .hapticContinuous,
                                  parameters: [intensity, sharpness],
                                  relativeTime: 0,
                                  duration: 0.08)

        return try CHHapticPattern(events: [event], parameters: [])
    }

    /// Snare: slightly longer transient with medium intensity.
    ///
    /// - Intensity: 0.6
    /// - Duration: ~0.12s
    private static func snare(intensityScale: Float) throws -> CHHapticPattern {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                               value: 0.6 * intensityScale)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                               value: 0.7)

        let event = CHHapticEvent(eventType: .hapticContinuous,
                                  parameters: [intensity, sharpness],
                                  relativeTime: 0,
                                  duration: 0.12)

        return try CHHapticPattern(events: [event], parameters: [])
    }

    /// Hi-hat: very short, light tick.
    ///
    /// - Intensity: 0.3
    /// - Duration: 0.03s
    private static func hihat(intensityScale: Float) throws -> CHHapticPattern {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                               value: 0.3 * intensityScale)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                               value: 1.0)

        let event = CHHapticEvent(eventType: .hapticContinuous,
                                  parameters: [intensity, sharpness],
                                  relativeTime: 0,
                                  duration: 0.03)

        return try CHHapticPattern(events: [event], parameters: [])
    }

    /// Build: continuous ramp from low to high intensity.
    ///
    /// - Base intensity: starts at 0.2, ramps to 1.0 (scaled by `intensityScale`)
    /// - Duration: 1.2s
    private static func build(intensityScale: Float) throws -> CHHapticPattern {
        let baseStart: Float = 0.2
        let baseEnd: Float = 1.0
        let duration: TimeInterval = 1.2

        let event = CHHapticEvent(eventType: .hapticContinuous,
                                  parameters: [],
                                  relativeTime: 0,
                                  duration: duration)

        // Curve from 0.2 → 1.0, scaled by intensityScale.
        let controlPoints: [CHHapticParameterCurve.ControlPoint] = [
            .init(relativeTime: 0.0, value: baseStart * intensityScale),
            .init(relativeTime: duration, value: baseEnd * intensityScale)
        ]

        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: controlPoints,
            relativeTime: 0
        )

        return try CHHapticPattern(events: [event], parameterCurves: [curve])
    }

    /// Drop: multi-pulse composite burst.
    ///
    /// - Three transients with descending intensity to feel like a heavy drop.
    private static func drop(intensityScale: Float) throws -> CHHapticPattern {
        let base: Float = 1.0 * intensityScale

        func transient(at time: TimeInterval, intensity value: Float, sharpness s: Float) -> CHHapticEvent {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                                   value: value)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                                   value: s)
            return CHHapticEvent(eventType: .hapticTransient,
                                 parameters: [intensity, sharpness],
                                 relativeTime: time)
        }

        let events: [CHHapticEvent] = [
            transient(at: 0.0,  intensity: base,       sharpness: 0.4),
            transient(at: 0.08, intensity: base * 0.9, sharpness: 0.7),
            transient(at: 0.16, intensity: base * 0.8, sharpness: 0.9)
        ]

        return try CHHapticPattern(events: events, parameters: [])
    }
    
    // MARK: - Texture Lab Patterns
    
    /// Returns a Core Haptics pattern for the given texture type.
    ///
    /// - Parameter type: The texture type from Texture Lab.
    /// - Parameter baseIntensity: Overall scaling factor (`0.0 ... 1.0`).
    static func texturePattern(for type: TextureType, baseIntensity: Float = 1.0) throws -> CHHapticPattern? {
        guard type != .none else { return nil }
        
        let scaled = max(0.0, min(baseIntensity, 1.0))
        
        switch type {
        case .deepPulse:
            return try deepPulse(intensityScale: scaled)
        case .sharpTap:
            return try sharpTap(intensityScale: scaled)
        case .rapidTexture:
            return try rapidTexture(intensityScale: scaled)
        case .softWave:
            return try softWave(intensityScale: scaled)
        case .smooth, .rough, .sharp:
            // Legacy textures - not used in new Texture Lab
            return nil
        case .none:
            return nil
        }
    }
    
    /// Deep Pulse: Longer duration, medium intensity, low sharpness, smooth envelope.
    /// Feels like bass.
    ///
    /// - Duration: 0.25s
    /// - Intensity: 0.7 (scaled)
    /// - Sharpness: 0.2
    private static func deepPulse(intensityScale: Float) throws -> CHHapticPattern {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                               value: 0.7 * intensityScale)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                               value: 0.2)
        
        // Smooth envelope: fade in and out
        let duration: TimeInterval = 0.25
        let event = CHHapticEvent(eventType: .hapticContinuous,
                                  parameters: [intensity, sharpness],
                                  relativeTime: 0,
                                  duration: duration)
        
        // Create smooth fade in/out curve
        let controlPoints: [CHHapticParameterCurve.ControlPoint] = [
            .init(relativeTime: 0.0, value: 0.0),
            .init(relativeTime: 0.1, value: 0.7 * intensityScale),
            .init(relativeTime: 0.15, value: 0.7 * intensityScale),
            .init(relativeTime: 0.25, value: 0.0)
        ]
        
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: controlPoints,
            relativeTime: 0
        )
        
        return try CHHapticPattern(events: [event], parameterCurves: [curve])
    }
    
    /// Sharp Tap: Very short, high sharpness, high attack, quick decay.
    /// Feels crisp and percussive.
    ///
    /// - Duration: 0.06s
    /// - Intensity: 0.9 (scaled)
    /// - Sharpness: 0.95
    private static func sharpTap(intensityScale: Float) throws -> CHHapticPattern {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                               value: 0.9 * intensityScale)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                               value: 0.95)
        
        let duration: TimeInterval = 0.06
        let event = CHHapticEvent(eventType: .hapticContinuous,
                                  parameters: [intensity, sharpness],
                                  relativeTime: 0,
                                  duration: duration)
        
        // Quick attack, fast decay
        let controlPoints: [CHHapticParameterCurve.ControlPoint] = [
            .init(relativeTime: 0.0, value: 0.9 * intensityScale),
            .init(relativeTime: 0.02, value: 0.9 * intensityScale),
            .init(relativeTime: 0.06, value: 0.0)
        ]
        
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: controlPoints,
            relativeTime: 0
        )
        
        return try CHHapticPattern(events: [event], parameterCurves: [curve])
    }
    
    /// Rapid Texture: Multiple tiny pulses clustered, lower intensity.
    /// Feels like hi-hat or buzz.
    ///
    /// - Duration: 0.15s
    /// - Multiple micro-pulses within the duration
    private static func rapidTexture(intensityScale: Float) throws -> CHHapticPattern {
        let baseIntensity: Float = 0.4 * intensityScale
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                               value: 0.8)
        
        // Create 5 rapid micro-pulses
        var events: [CHHapticEvent] = []
        let pulseCount = 5
        let totalDuration: TimeInterval = 0.15
        let pulseSpacing = totalDuration / Double(pulseCount)
        
        for i in 0..<pulseCount {
            let time = Double(i) * pulseSpacing
            let pulseIntensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                                       value: baseIntensity)
            let pulse = CHHapticEvent(eventType: .hapticTransient,
                                      parameters: [pulseIntensity, sharpness],
                                      relativeTime: time)
            events.append(pulse)
        }
        
        return try CHHapticPattern(events: events, parameters: [])
    }
    
    /// Soft Wave: Long continuous vibration, low intensity, smooth fade in/out.
    /// Ambient background layer.
    ///
    /// - Duration: 0.5s
    /// - Intensity: 0.3 (scaled)
    /// - Sharpness: 0.1
    private static func softWave(intensityScale: Float) throws -> CHHapticPattern {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                               value: 0.3 * intensityScale)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                               value: 0.1)
        
        let duration: TimeInterval = 0.5
        let event = CHHapticEvent(eventType: .hapticContinuous,
                                  parameters: [intensity, sharpness],
                                  relativeTime: 0,
                                  duration: duration)
        
        // Very smooth fade in/out
        let controlPoints: [CHHapticParameterCurve.ControlPoint] = [
            .init(relativeTime: 0.0, value: 0.0),
            .init(relativeTime: 0.1, value: 0.3 * intensityScale),
            .init(relativeTime: 0.4, value: 0.3 * intensityScale),
            .init(relativeTime: 0.5, value: 0.0)
        ]
        
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: controlPoints,
            relativeTime: 0
        )
        
        return try CHHapticPattern(events: [event], parameterCurves: [curve])
    }
}

