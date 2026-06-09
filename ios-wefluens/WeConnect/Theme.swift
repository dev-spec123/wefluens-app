//
//  Theme.swift
//  WeConnect
//
//  Central design system: colors, gradients, typography helpers.
//  Supports light and dark mode.
//

import SwiftUI

/// App-wide color scheme mode.
enum ColorSchemeMode: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    var labelKey: L10n {
        switch self {
        case .light: return .themeLight
        case .dark: return .themeDark
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Observable theme manager that persists the chosen color scheme.
@Observable
final class ThemeManager {
    var mode: ColorSchemeMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey)
        }
    }

    private static let storageKey = "wefluens.colorscheme"

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        self.mode = stored.flatMap(ColorSchemeMode.init(rawValue:)) ?? .light
    }
}

/// Semantic colors that adapt to light/dark mode.
enum Theme {
    // --- Light palette ---
    private static let lightPaper = Color(hex: 0xF7F3EE)
    private static let lightCard  = Color.white
    private static let lightCardSubtle = Color(hex: 0xFBF8F4)
    private static let lightInk = Color(hex: 0x1C141A)
    private static let lightInkSecondary = Color(hex: 0x8B8189)
    private static let lightInkTertiary = Color(hex: 0xB6ADB3)

    // --- Dark palette ---
    private static let darkPaper = Color(hex: 0x0F0C0E)
    private static let darkCard  = Color(hex: 0x1C181B)
    private static let darkCardSubtle = Color(hex: 0x252023)
    private static let darkInk = Color(hex: 0xF0EBED)
    private static let darkInkSecondary = Color(hex: 0x9D95A0)
    private static let darkInkTertiary = Color(hex: 0x605A63)

    /// Resolve the current color scheme from the environment.
    private static func isDark(_ scheme: ColorScheme) -> Bool {
        scheme == .dark
    }

    // Surfaces
    static func paper(for scheme: ColorScheme) -> Color {
        isDark(scheme) ? darkPaper : lightPaper
    }
    static func card(for scheme: ColorScheme) -> Color {
        isDark(scheme) ? darkCard : lightCard
    }
    static func cardSubtle(for scheme: ColorScheme) -> Color {
        isDark(scheme) ? darkCardSubtle : lightCardSubtle
    }

    // Text
    static func ink(for scheme: ColorScheme) -> Color {
        isDark(scheme) ? darkInk : lightInk
    }
    static func inkSecondary(for scheme: ColorScheme) -> Color {
        isDark(scheme) ? darkInkSecondary : lightInkSecondary
    }
    static func inkTertiary(for scheme: ColorScheme) -> Color {
        isDark(scheme) ? darkInkTertiary : lightInkTertiary
    }

    // Brand (unchanged between modes)
    static let plum = Color(hex: 0x3A1B4A)
    static let coral = Color(hex: 0xFF4D6D)
    static let tangerine = Color(hex: 0xFF9A5A)
    static let coralDark = Color(hex: 0xFF6B82)

    /// Destructive actions (delete / remove).
    static let danger = Color(hex: 0xE5484D)

    // Hairline adapts
    static func hairline(for scheme: ColorScheme) -> Color {
        isDark(scheme) ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    /// Primary brand gradient (sunset).
    static let sunset = LinearGradient(
        colors: [coral, tangerine],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sunsetDark = LinearGradient(
        colors: [coralDark, tangerine],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Deep editorial gradient used on hero surfaces.
    static let dusk = LinearGradient(
        colors: [plum, coral],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let warmGlow = LinearGradient(
        colors: [tangerine.opacity(0.9), coral.opacity(0.9)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

extension View {
    /// Soft elevated card styling used across the app — adapts to color scheme.
    func cardStyle(cornerRadius: CGFloat = 22) -> some View {
        modifier(CardModifier(cornerRadius: cornerRadius))
    }
}

private struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(Theme.card(for: colorScheme))
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Theme.hairline(for: colorScheme), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 18, x: 0, y: 10)
    }
}
