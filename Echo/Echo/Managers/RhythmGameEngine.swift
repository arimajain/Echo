import Foundation
import SwiftUI

/// Judgement categories for user input timing.
enum RhythmJudgement {
    case perfect
    case good
    case miss
}

/// Core logic for the radial rhythm game.
@MainActor
final class RhythmGameEngine: ObservableObject {

    // MARK: - Published State

    @Published private(set) var beats: [BeatNode]
    @Published private(set) var score: Int = 0
    @Published private(set) var currentCombo: Int = 0
    @Published private(set) var lastJudgement: RhythmJudgement?

    // MARK: - Dependencies

    private let audioManager: AudioManager
    private let hapticManager = HapticManager.shared

    // MARK: - Internal

    /// Beats for which we've already fired the anticipation tick.
    private var anticipationFired: Set<UUID> = []

    /// Timer driving anticipation checks.
    private var gameTimer: Timer?

    // MARK: - Initialization

    init(audioManager: AudioManager = .shared) {
        self.audioManager = audioManager
        self.beats = BeatNode.demoTrackBeats()
        startGameTimer()
    }

    deinit {
        gameTimer?.invalidate()
    }

    // MARK: - Active Beats

    /// Returns beats within a ±1.5 second window of the current playback time.
    func getActiveBeats() -> [BeatNode] {
        let t = audioManager.currentTime
        return beats.filter { abs($0.timestamp - t) <= 1.5 }
    }

    // MARK: - Input / Scoring

    /// Called when the user taps the screen.
    func userDidTap() {
        let t = audioManager.currentTime

        // Find closest *unhit* beat.
        guard let (index, beat) = beats.enumerated()
            .filter({ !$0.element.isHit })
            .min(by: { abs($0.element.timestamp - t) < abs($1.element.timestamp - t) })
        else {
            register(judgement: .miss)
            return
        }

        let diff = abs(beat.timestamp - t)

        if diff < 0.1 {
            // Perfect
            beats[index].isHit = true
            score += 100
            currentCombo += 1
            register(judgement: .perfect)
        } else if diff < 0.2 {
            // Good
            beats[index].isHit = true
            score += 50
            currentCombo += 1
            register(judgement: .good)
        } else {
            // Miss
            register(judgement: .miss)
        }
    }

    private func register(judgement: RhythmJudgement) {
        lastJudgement = judgement

        if judgement == .miss {
            currentCombo = 0
        }

        // Clear feedback after a short flash.
        let stamp = UUID()
        let localStamp = stamp
        // Use a local value to prevent race conditions if needed later.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }
            _ = localStamp  // currently unused, kept for potential expansion.
            self.lastJudgement = nil
        }
    }

    // MARK: - Anticipation Haptics

    private func startGameTimer() {
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0,
                                         repeats: true) { [weak self] _ in
            guard let self else { return }
            self.gameTick()
        }
    }

    /// Checks for upcoming beats and triggers anticipation haptics.
    private func gameTick() {
        let t = audioManager.currentTime

        for beat in beats where !beat.isHit && !anticipationFired.contains(beat.id) {
            let delta = beat.timestamp - t

            // Fire cue when we are roughly 0.5 seconds away from the beat.
            if delta > 0.48 && delta < 0.52 {
                anticipationFired.insert(beat.id)
                hapticManager.playDynamicVibration(
                    frequency: 0.5,
                    intensity: 0.2
                )
            }
        }
    }
}

