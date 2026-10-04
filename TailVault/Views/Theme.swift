//
//  Theme.swift
//  TailVault
//
//  Tint themes: a soft accent hue + a faint background wash laid
//  over the standard light/dark appearance. Mono = stock iOS look.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Platform shims (iOS + macOS from one codebase)

#if canImport(UIKit)
/// Cross-platform image type — UIImage on iOS, NSImage on macOS.
typealias PlatformImage = UIImage
extension Image {
    init(platformImage: PlatformImage) { self.init(uiImage: platformImage) }
}
#elseif canImport(AppKit)
typealias PlatformImage = NSImage
extension Image {
    init(platformImage: PlatformImage) { self.init(nsImage: platformImage) }
}
#endif

#if os(macOS)
/// iOS-only text-input modifiers, stubbed as no-ops so shared call
/// sites compile unchanged on the Mac (which has a real keyboard).
enum UIKeyboardType {
    case decimalPad, numbersAndPunctuation, phonePad, emailAddress
}
enum TextInputAutocapitalization {
    case never, words, sentences, characters
}
extension View {
    func keyboardType(_ type: UIKeyboardType) -> some View { self }
    func textInputAutocapitalization(_ style: TextInputAutocapitalization?) -> some View { self }
}
#endif

extension View {
    /// `.navigationBarTitleDisplayMode(.inline)` on iOS; no-op on macOS,
    /// where the modifier doesn't exist.
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// Half-height sheet on iOS; macOS sheets just size to fit.
    @ViewBuilder
    func mediumSheetDetent() -> some View {
        #if os(iOS)
        self.presentationDetents([.medium])
        #else
        self
        #endif
    }
}

extension ToolbarItemPlacement {
    /// `.topBarTrailing` on iOS, trailing edge of the window toolbar on macOS.
    static var trailingBar: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }
    /// `.topBarLeading` on iOS, next to the sidebar toggle on macOS.
    static var leadingBar: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .navigation
        #endif
    }
}

extension Color {
    /// Grouped-list background on iOS, window background on macOS.
    static var groupedBackground: Color {
        #if os(iOS)
        Color(.systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
}

enum TintTheme: String, CaseIterable, Identifiable {
    case mono, sky, blush, sage, lavender, peach

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mono:     return "Mono"
        case .sky:      return "Sky"
        case .blush:    return "Blush"
        case .sage:     return "Sage"
        case .lavender: return "Lavender"
        case .peach:    return "Peach"
        }
    }

    /// Accent for buttons, links, toggles, selection.
    var accent: Color {
        switch self {
        case .mono:     return .blue
        case .sky:      return Color(red: 0.30, green: 0.62, blue: 0.94)
        case .blush:    return Color(red: 0.93, green: 0.44, blue: 0.58)
        case .sage:     return Color(red: 0.38, green: 0.66, blue: 0.50)
        case .lavender: return Color(red: 0.58, green: 0.50, blue: 0.88)
        case .peach:    return Color(red: 0.95, green: 0.55, blue: 0.38)
        }
    }

    /// Swatch shown in the Settings picker.
    var swatch: Color {
        guard self == .mono else { return accent }
        #if os(iOS)
        return Color(.systemGray3)
        #else
        return Color(nsColor: .systemGray).opacity(0.6)
        #endif
    }
}

// MARK: - Background wash

/// Hides the default list/form background and layers a faint hue
/// over the system background — subtle in light, moody in dark.
private struct ThemedSurface: ViewModifier {
    let theme: TintTheme
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        if theme == .mono {
            content
        } else {
            content
                .scrollContentBackground(.hidden)
                .background {
                    ZStack {
                        Color.groupedBackground
                        theme.accent.opacity(scheme == .dark ? 0.10 : 0.07)
                    }
                    .ignoresSafeArea()
                }
        }
    }
}

extension View {
    /// Apply to any List or Form to pick up the tint wash.
    func themedSurface(_ theme: TintTheme) -> some View {
        modifier(ThemedSurface(theme: theme))
    }
}

// MARK: - Settings picker row

struct TintThemePicker: View {
    @Binding var selection: TintTheme

    var body: some View {
        HStack(spacing: 14) {
            ForEach(TintTheme.allCases) { theme in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(theme.swatch.gradient)
                            .frame(width: 36, height: 36)
                        if selection == theme {
                            Image(systemName: "checkmark")
                                .font(.footnote.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    .overlay {
                        Circle().strokeBorder(
                            selection == theme ? theme.swatch : .clear, lineWidth: 2
                        )
                        .padding(-3)
                    }
                    Text(theme.label)
                        .font(.caption2)
                        .foregroundStyle(selection == theme ? .primary : .secondary)
                }
                .onTapGesture { selection = theme }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

// MARK: - Haptics

enum Haptics {
    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        // No haptics on macOS — checking things off is its own reward.
    }
}

// MARK: - Confetti 🎉

/// Lightweight dependency-free confetti burst. Overlay it and pieces
/// shoot up from the bottom edge, then drift back down. Remove it from
/// the hierarchy to reset.
struct ConfettiView: View {
    private struct Particle: Identifiable {
        let id = UUID()
        let x: CGFloat          // 0...1 launch position along the bottom
        let size: CGFloat
        let delay: Double
        let apex: CGFloat       // peak height as a fraction of the view
        let rise: Double        // seconds to reach the apex
        let fall: Double        // seconds to drift back off screen
        let drift: CGFloat      // horizontal travel, fraction of width
        let swayAmp: CGFloat
        let swayFreq: Double
        let spin: Double        // degrees per second
        let color: Color
        let isCircle: Bool
    }

    private static let palette: [Color] =
        [.pink, .orange, .yellow, .mint, .teal, .indigo, .purple]

    private let particles: [Particle] = (0..<44).map { _ in
        let x: CGFloat = .random(in: 0.05...0.95)
        return Particle(
            x: x,
            size: .random(in: 7...13),
            delay: .random(in: 0...0.18),
            apex: .random(in: 0.55...1.05),
            rise: .random(in: 0.42...0.62),
            fall: .random(in: 1.1...1.7),
            // Fan away from the launch point, so the burst spreads outward.
            drift: (x - 0.5) * .random(in: 0.25...0.7) + .random(in: -0.05...0.05),
            swayAmp: .random(in: 0.01...0.045),
            swayFreq: .random(in: 0.7...1.6),
            spin: .random(in: -420...420),
            color: palette.randomElement()!,
            isCircle: Bool.random()
        )
    }

    private var maxLife: Double {
        particles.map { $0.delay + $0.rise + $0.fall }.max() ?? 2.5
    }

    @State private var start = Date.now

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { context in
                let now = context.date.timeIntervalSince(start)
                ZStack {
                    ForEach(particles) { p in
                        let t = now - p.delay
                        let life = p.rise + p.fall
                        // Height above the bottom edge, 0...1 of the view.
                        let up: CGFloat = {
                            guard t > 0 else { return -0.06 }
                            if t < p.rise {
                                // Decelerating launch.
                                let s = t / p.rise
                                let eased = CGFloat(1 - pow(1 - s, 2))
                                return -0.06 + (p.apex + 0.06) * eased
                            }
                            // Gentle accelerating drift back down.
                            let s = min(1, (t - p.rise) / p.fall)
                            return p.apex + (-0.12 - p.apex) * CGFloat(pow(s, 1.7))
                        }()
                        let progress = t <= 0 ? 0 : min(1, t / life)

                        Group {
                            if p.isCircle {
                                Circle().fill(p.color)
                            } else {
                                RoundedRectangle(cornerRadius: 2).fill(p.color)
                            }
                        }
                        .frame(width: p.size, height: p.size * (p.isCircle ? 1 : 1.6))
                        .rotationEffect(.degrees(p.spin * max(0, t)))
                        .opacity(t <= 0 ? 0 : (progress > 0.8 ? (1 - progress) / 0.2 : 1))
                        .position(
                            x: (p.x
                                + p.drift * CGFloat(progress)
                                + p.swayAmp * CGFloat(sin(max(0, t) * .pi * 2 * p.swayFreq)))
                                * geo.size.width,
                            y: (1 - up) * geo.size.height
                        )
                    }
                }
                .opacity(now > maxLife ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear { start = .now }
    }
}
