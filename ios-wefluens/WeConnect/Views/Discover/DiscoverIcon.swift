//
//  DiscoverIcon.swift
//  WeConnect
//
//  Shared brand/campaign icon for the Discover surface and its admin editors.
//  Renders the uploaded `iconUrl` IMAGE when present, otherwise falls back to the
//  existing default look (gradient fill + SF-symbol). The default is NEVER deleted —
//  it's the fallback whenever a row has no uploaded icon.
//

import SwiftUI

struct DiscoverIcon: View {
    let iconUrl: String?
    let symbol: String
    let colors: [UInt]
    var size: CGFloat = 56
    var corner: CGFloat = 18
    var symbolSize: CGFloat = 26

    private var gradientFallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(LinearGradient(colors: colors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: symbol)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    var body: some View {
        Group {
            if let iconUrl, let url = URL(string: iconUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        // Loading / failed → the default look stands in.
                        gradientFallback
                    }
                }
            } else {
                gradientFallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner))
    }
}
