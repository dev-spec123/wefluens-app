//
//  Components.swift
//  WeConnect
//
//  Small reusable UI building blocks. Adapts to light/dark mode.
//

import SwiftUI

/// Gradient avatar with optional remote image, SF Symbol, initials, and online dot.
/// When `imageURL` is a valid non-empty URL the real photo is shown (clipped to a
/// circle); otherwise it falls back to the gradient + symbol/initials placeholder.
struct Avatar: View {
    @Environment(\.colorScheme) private var colorScheme
    let colors: [UInt]
    var symbol: String? = nil
    var initials: String? = nil
    var imageURL: String? = nil
    var size: CGFloat = 52
    var isOnline: Bool = false

    private var gradient: LinearGradient {
        LinearGradient(
            colors: colors.map { Color(hex: $0) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var resolvedURL: URL? {
        guard let imageURL, !imageURL.isEmpty else { return nil }
        return URL(string: imageURL)
    }

    var body: some View {
        ZStack {
            if let url = resolvedURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
        .overlay(alignment: .bottomTrailing) {
            if isOnline {
                Circle()
                    .fill(Color(hex: 0x2AD17E))
                    .frame(width: size * 0.26, height: size * 0.26)
                    .overlay(Circle().stroke(Theme.paper(for: colorScheme), lineWidth: 2.5))
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(gradient)
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
