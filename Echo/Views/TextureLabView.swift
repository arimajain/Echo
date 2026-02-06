import SwiftUI

/// Educational onboarding module that teaches users to recognize different
/// haptic \"textures\" before entering the main Echo experience.
struct TextureLabView: View {

    // MARK: - Dependencies

    @ObservedObject private var hapticManager = HapticManager.shared

    // MARK: - Data

    private let lessons: [TextureLesson] = TextureLesson.demoLessons

    // MARK: - State

    /// The texture currently being felt (if any).
    @State private var activeTexture: TextureType?

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                VStack(spacing: 4) {
                    Text("Texture Lab")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .accessibilityAddTraits(.isHeader)

                    Text("Learn how different sounds *feel* before you enter Echo.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)

                // Carousel
                TabView {
                    ForEach(lessons) { lesson in
                        lessonCard(for: lesson)
                            .padding(.horizontal, 24)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Lesson Card

    private func lessonCard(for lesson: TextureLesson) -> some View {
        let isActive = activeTexture == lesson.hapticType

        return VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: lesson.iconName)
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: isActive
                        ? [Color.cyan, Color.purple]
                        : [Color.white, Color.white.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(isActive ? 1.15 : 1.0)
                .shadow(color: .cyan.opacity(isActive ? 0.6 : 0.2), radius: 20, y: 10)
                .animation(.easeInOut(duration: 0.15), value: isActive)
                .accessibilityHidden(true)

            // Text
            VStack(spacing: 8) {
                Text(lesson.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(lesson.description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 12)

            Spacer()

            // Hold to Feel button
            holdToFeelButton(for: lesson)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - Hold to Feel Button

    private func holdToFeelButton(for lesson: TextureLesson) -> some View {
        let isActive = activeTexture == lesson.hapticType

        return Button {
            // Intentionally empty – we drive everything from the long-press state.
        } label: {
            Text("Hold to Feel")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isActive
                                ? [Color.cyan, Color.purple]
                                : [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: isActive ? 2 : 1)
                )
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.1)
                .onChanged { _ in
                    if activeTexture != lesson.hapticType {
                        activeTexture = lesson.hapticType
                        hapticManager.playTexture(type: lesson.hapticType)
                    }
                }
                .onEnded { _ in
                    activeTexture = nil
                    hapticManager.stopTexture()
                }
        )
        .accessibilityLabel("Hold to feel \(lesson.hapticType.displayName) texture.")
        .accessibilityHint("Touch and hold to feel this haptic texture, then lift to stop.")
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - Preview

#Preview {
    TextureLabView()
        .preferredColorScheme(.dark)
}

