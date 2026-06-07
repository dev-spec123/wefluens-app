//
//  Components.swift
//  Wefluens
//
//  Small reusable UI building blocks. Adapts to light/dark mode.
//

import SwiftUI

/// Gradient avatar with optional SF Symbol, initials, and online dot.
struct Avatar: View {
    @Environment(\.colorScheme) private var colorScheme
    let colors: [UInt]
    var symbol: String? = nil
    var initials: String? = nil
    var size: CGFloat = 52
    var isOnline: Bool = false

    private var gradient: LinearGradient {
        LinearGradient(
            colors: colors.map { Color(hex: $0) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(gradient)
                .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))

            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            } else if let initials {
                Text(initials)
                    .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if isOnline {
                Circle()
                    .fill(Color(hex: 0x2AD17E))
                    .frame(width: size * 0.26, height: size * 0.26)
                    .overlay(Circle().stroke(Theme.paper(for: colorScheme), lineWidth: 2.5))
            }
        }
    }
}

/// Pill-shaped tag chip.
struct TagChip: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(filled ? .white : Theme.inkSecondary(for: colorScheme))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(filled ? AnyShapeStyle(Theme.sunset) : AnyShapeStyle(Theme.cardSubtle(for: colorScheme)))
            )
            .overlay(
                Capsule().stroke(filled ? Color.clear : Theme.hairline(for: colorScheme), lineWidth: 1)
            )
    }
}

/// Large screen title used at the top of each tab.
struct ScreenHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink(for: colorScheme))
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
