import SwiftUI

/// Temporary utility view to help author beat maps for `RhythmGameEngine`.
///
/// Plays the demo track and logs timestamps whenever you tap the
/// "Mark Beat" button. Copy the printed list from the Xcode console
/// and paste into `BeatNode.demoTrackBeats()`.
struct BeatRecorderView: View {

    @ObservedObject private var audioManager = AudioManager.shared

    /// Local buffer of captured timestamps, also shown on-screen for easier copy.
    @State private var capturedBeats: [Double] = []

    var body: some View {
        VStack(spacing: 24) {
            Text("Beat Recorder")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(String(format: "Current Time: %.3f s", audioManager.currentTime))
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))

            // Transport controls.
            HStack(spacing: 24) {
                Button {
                    if audioManager.isPlaying {
                        audioManager.pause()
                    } else {
                        audioManager.play()
                    }
                } label: {
                    Label(audioManager.isPlaying ? "Pause" : "Play",
                          systemImage: audioManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.15), in: Capsule())
                        .foregroundStyle(.white)
                }

                Button {
                    audioManager.stop()
                    capturedBeats.removeAll()
                } label: {
                    Label("Reset", systemImage: "stop.fill")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            // Mark Beat button.
            Button {
                let t = audioManager.currentTime
                capturedBeats.append(t)
                print(String(format: "Beat at: %.3f", t))
                let summary = capturedBeats
                    .map { String(format: "%.3f", $0) }
                    .joined(separator: ", ")
                print("All beats so far: [\(summary)]")
            } label: {
                Text("Mark Beat")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.cyan, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 24)

            // On-screen list of captured timestamps for quick copy.
            if !capturedBeats.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Captured Timestamps (s)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))

                    Text(capturedBeats
                        .map { String(format: "%.3f", $0) }
                        .joined(separator: ", "))
                    .font(.footnote.monospaced())
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(12)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
            }

            Spacer()
        }
        .padding(.top, 40)
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - Preview

#Preview {
    BeatRecorderView()
        .preferredColorScheme(.dark)
}

