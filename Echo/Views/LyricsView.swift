import SwiftUI

/// Displays synchronized lyrics with English text and finger spelling visualization.
///
/// This view observes the `LyricsManager` to show the currently active lyric line,
/// displays it in English at the top, and renders a finger spelling representation
/// below using a custom Sign Language font.
struct LyricsView: View {
    
    // MARK: - Dependencies
    
    @ObservedObject private var audioManager = AudioManager.shared
    @ObservedObject private var lyricsManager = LyricsManager.shared
    
    // MARK: - State
    
    /// Tracks the last active line ID to detect changes for haptic feedback.
    @State private var lastActiveLineId: UUID?
    
    /// Whether the custom Sign Language font is available.
    @State private var signFontAvailable: Bool = false
    
    /// The exact name of the custom font (discovered at runtime).
    @State private var signFontName: String? = nil
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            if let activeLine = lyricsManager.activeLine {
                // English text (top line)
                Text(activeLine.text)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 24)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                
                // Sign language / finger spelling (bottom line).
                if signFontAvailable, let fontName = signFontName {
                    // Use custom Sign Language font
                    Text(activeLine.text.uppercased())
                        .font(.custom(fontName, size: 60))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 24)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                } else {
                    // Fallback to hand symbols
                    fingerSpellingView(for: activeLine.text)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
            } else {
                // Empty state when no lyrics are active
                VStack(spacing: 12) {
                    Text("—")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                    
                    Text("No lyrics")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .onChange(of: audioManager.currentTime) { _, newTime in
            // Update the active line based on current playback time
            lyricsManager.updateActiveLine(at: newTime)
        }
        .onChange(of: lyricsManager.activeLine?.id) { _, newId in
            // Trigger haptic feedback when a new line appears
            if let newId = newId, newId != lastActiveLineId {
                lastActiveLineId = newId
                HapticManager.shared.playComplexPattern()
            }
        }
        .onAppear {
            // Initialize with current time
            lyricsManager.updateActiveLine(at: audioManager.currentTime)
            
            // Debug: Print all available font families and names
            print("LyricsView: 🔍 Scanning for Sign Language font...")
            for family in UIFont.familyNames.sorted() {
                let names = UIFont.fontNames(forFamilyName: family)
                print("Family: \(family) Font names: \(names)")
            }
            
            // Try to find and load the Sign Language font
            detectSignLanguageFont()
        }
    }
    
    // MARK: - Font Detection
    
    /// Detects and loads the custom Sign Language font.
    private func detectSignLanguageFont() {
        // Common Sign Language font names to try
        let possibleNames = [
            "Gallaudet",
            "Gallaudet-Regular",
            "GallaudetRegular",
            "SignLanguage",
            "ASL",
            "AmericanSignLanguage"
        ]
        
        // First, try the most likely name
        if let font = UIFont(name: "Gallaudet", size: 60) {
            signFontName = "Gallaudet"
            signFontAvailable = true
            print("LyricsView: ✅ Found Sign Language font: Gallaudet")
            return
        }
        
        // Search through all font families for Sign Language related fonts
        for family in UIFont.familyNames {
            let names = UIFont.fontNames(forFamilyName: family)
            
            // Check if any font name contains sign language keywords
            for name in names {
                let lowerName = name.lowercased()
                if lowerName.contains("gallaudet") ||
                   lowerName.contains("sign") ||
                   lowerName.contains("asl") {
                    if let font = UIFont(name: name, size: 60) {
                        signFontName = name
                        signFontAvailable = true
                        print("LyricsView: ✅ Found Sign Language font: \(name) (family: \(family))")
                        return
                    }
                }
            }
        }
        
        // If we get here, the font wasn't found
        signFontAvailable = false
        print("LyricsView: ⚠️ Sign Language font not found, using fallback hand symbols")
    }
    
    // MARK: - Finger Spelling View (Fallback)
    
    /// Creates a horizontal scrollable view of finger spelling letters.
    /// This is used as a fallback when the custom Sign Language font is not available.
    private func fingerSpellingView(for text: String) -> some View {
        let letters = text.uppercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .compactMap { $0.isLetter ? String($0) : nil }
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                    fingerSpellingLetter(letter)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 60)
    }
    
    /// Individual letter in a hand-shaped circle for finger spelling.
    private func fingerSpellingLetter(_ letter: String) -> some View {
        ZStack {
            // Outer circle (hand shape)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial)
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            
            // Letter inside
            Text(letter)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        // Background
        FluidBackgroundView(
            type: .aurora,
            amplitude: 0.3
        )
        .ignoresSafeArea()
        
        // Lyrics view at bottom
        VStack {
            Spacer()
            LyricsView()
                .glass(cornerRadius: 24, opacity: 0.2)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
        }
    }
    .preferredColorScheme(.dark)
}
