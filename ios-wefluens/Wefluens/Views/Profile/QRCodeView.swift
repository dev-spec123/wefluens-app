//
//  QRCodeView.swift
//  Wefluens
//
//  Shows the current user's unique ID as a QR code that others
//  can scan to add them as a friend.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Profile header
                VStack(spacing: 12) {
                    userAvatar
                        .shadow(color: .black.opacity(0.12), radius: 14, y: 8)

                    Text(data.profile?.name ?? auth.userEmail ?? "You")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink(for: colorScheme))

                    if let handle = data.profile?.handle, !handle.isEmpty {
                        Text(handle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    }
                }
                .padding(.top, 20)

                // QR Code card
                if let uid = auth.userId {
                    qrCodeCard(for: uid)
                } else {
                    Text("Sign in to see your QR code")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                }

                // Instructions
                VStack(spacing: 6) {
                    Text("Scan to Add Friend")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink(for: colorScheme))
                    Text("Let others scan this code to send you a friend request.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                // Scan someone else's code
                NavigationLink {
                    QRScanView()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Scan QR Code")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.sunset)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Theme.coral.opacity(0.35), radius: 14, y: 8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationTitle("My QR Code")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Avatar

    @ViewBuilder
    private var userAvatar: some View {
        if let urlStr = data.profile?.avatarUrl, !urlStr.isEmpty,
           let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80).clipShape(Circle())
                case .failure, .empty:
                    fallbackAvatar
                @unknown default:
                    fallbackAvatar
                }
            }
            .frame(width: 80, height: 80)
        } else {
            fallbackAvatar
        }
    }

    private var fallbackAvatar: some View {
        Avatar(colors: [0xFF4D6D, 0xFF9A5A], initials: initials, size: 80, isOnline: true)
    }

    private var initials: String {
        let name = data.profile?.name ?? auth.userEmail ?? "?"
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.count > 1 ? parts.last?.first.map(String.init) ?? "" : ""
        let result = (first + last).uppercased()
        return result.isEmpty ? "?" : result
    }

    // MARK: - QR Code

    private func qrCodeCard(for uid: UUID) -> some View {
        VStack(spacing: 16) {
            Image(uiImage: generateQRCode(from: "wefluens://user/\(uid.uuidString)"))
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.hairline(for: colorScheme), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)

            Text(uid.uuidString.prefix(12).uppercased() + "...")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))
        }
    }

    /// Generate a QR code UIImage from a string using CoreImage.
    private func generateQRCode(from string: String) -> UIImage {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        let context = CIContext()
        // Scale up for sharp rendering
        let transform = CGAffineTransform(scaleX: 10, y: 10)

        guard let output = filter.outputImage?.transformed(by: transform),
              let cgImage = context.createCGImage(output, from: output.extent)
        else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    NavigationStack {
        QRCodeView()
            .environment(AuthManager())
            .environment(LocalizationManager())
            .environment(AppDataService(userId: nil))
    }
}
