//
//  QRScanView.swift
//  WeConnect
//
//  Scans a WeConnect QR code (wefluens://user/<uuid>) and sends a
//  friend request to that user via Supabase.
//

import SwiftUI
import AVFoundation
import Supabase

struct QRScanView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var isScanning = true
    @State private var scannedUserId: UUID?
    @State private var scannedUserName: String?
    @State private var requestStatus: RequestStatus = .idle
    @State private var errorMessage: String?

    enum RequestStatus {
        case idle
        case sending
        case sent
        case failed
    }

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreview(isScanning: $isScanning, onCodeFound: handleScannedCode)
                .ignoresSafeArea()

            // Overlay
            VStack {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Spacer()

                // Scan frame
                scanFrame
                    .padding(.bottom, 40)

                // Instructions
                Text(l10n.t(.qrScanHint))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.bottom, 80)
            }

            // Result overlay
            if scannedUserId != nil {
                resultOverlay
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Scan frame

    private var scanFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.5), lineWidth: 3)
                .frame(width: 240, height: 240)

            // Corner accents
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.coral)
                    .frame(width: 28, height: 3)
                    .rotationEffect(.degrees(Double(i) * 90))
                    .offset(
                        x: i % 2 == 0 ? 0 : (i == 1 ? -120 : 120),
                        y: i % 2 == 1 ? 0 : (i == 0 ? -120 : 120)
                    )
            }
        }
    }

    // MARK: - Result

    @ViewBuilder
    private var resultOverlay: some View {
        Color.black.opacity(0.7).ignoresSafeArea()

        VStack(spacing: 20) {
            switch requestStatus {
            case .idle, .sending:
                VStack(spacing: 16) {
                    if let name = scannedUserName {
                        Avatar(colors: [0x6C5CE7, 0xA29BFE], initials: nameInitials(name), size: 72, isOnline: true)
                        Text(name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    if requestStatus == .sending {
                        ProgressView().tint(.white)
                        Text(l10n.t(.qrSending))
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        Button {
                            Task { await sendFriendRequest() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.badge.plus")
                                Text(l10n.t(.qrSendRequest))
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Theme.sunset)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 40)

                        Button {
                            resetScan()
                        } label: {
                            Text(l10n.t(.adminCancel))
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }

            case .sent:
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color(hex: 0x2AD17E))
                    Text(l10n.t(.qrSentTitle))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text(l10n.t(.qrSentSub))
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)

                    Button {
                        dismiss()
                    } label: {
                        Text(l10n.t(.qrDone))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 40)
                }

            case .failed:
                VStack(spacing: 16) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.red)
                    Text(l10n.t(.qrFailedTitle))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text(errorMessage ?? l10n.t(.qrFailedSub))
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)

                    Button {
                        resetScan()
                    } label: {
                        Text(l10n.t(.qrTryAgain))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 40)
                }
            }
        }
    }

    // MARK: - Logic

    private func handleScannedCode(_ code: String) {
        // Expected format: wefluens://user/<uuid>
        guard code.hasPrefix("wefluens://user/") else { return }
        let uuidString = String(code.dropFirst("wefluens://user/".count))
        guard let uid = UUID(uuidString: uuidString) else { return }

        // Don't add yourself
        if uid == auth.userId { return }

        isScanning = false
        scannedUserId = uid
        requestStatus = .idle
    }

    @MainActor
    private func sendFriendRequest() async {
        guard let targetId = scannedUserId else { return }
        guard let myId = auth.userId else {
            requestStatus = .failed
            errorMessage = l10n.t(.qrNotSignedIn)
            return
        }
        requestStatus = .sending

        do {
            let insert = FriendRequestInsert(
                fromUserId: myId,
                toUserId: targetId,
                name: data.profile?.name ?? auth.userEmail ?? "User",
                handle: data.profile?.handle ?? "",
                role: data.profile?.role ?? "",
                requestMessage: "Hi! I'd like to add you as a friend."
            )
            try await supabase.from("friend_requests").insert(insert).execute()
            requestStatus = .sent
        } catch {
            requestStatus = .failed
            errorMessage = error.localizedDescription
        }
    }

    private func resetScan() {
        scannedUserId = nil
        scannedUserName = nil
        requestStatus = .idle
        errorMessage = nil
        isScanning = true
    }

    private func nameInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.count > 1 ? parts.last?.first.map(String.init) ?? "" : ""
        let result = (first + last).uppercased()
        return result.isEmpty ? "?" : result
    }
}

// MARK: - Friend Request Insert Model

nonisolated struct FriendRequestInsert: Encodable, Sendable {
    let fromUserId: UUID
    let toUserId: UUID
    let name: String
    let handle: String
    let role: String
    let requestMessage: String
    let status: String = "pending"

    enum CodingKeys: String, CodingKey {
        case name, handle, role, status
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case requestMessage = "request_message"
    }
}

// MARK: - Camera Preview

private struct CameraPreview: UIViewControllerRepresentable {
    @Binding var isScanning: Bool
    let onCodeFound: (String) -> Void

    func makeUIViewController(context: Context) -> CameraPreviewController {
        let controller = CameraPreviewController()
        controller.onCodeFound = onCodeFound
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraPreviewController, context: Context) {
        if isScanning {
            uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }
}

private final class CameraPreviewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeFound: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else {
            showPlaceholder()
            return
        }

        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = obj.stringValue
        else { return }
        onCodeFound?(code)
    }

    private func showPlaceholder() {
        let label = UILabel()
        label.text = "Install this app on your device via the Rork App to use the camera."
        label.textColor = .white.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])
    }
}

#Preview {
    QRScanView()
        .environment(AuthManager())
        .environment(LocalizationManager())
        .environment(AppDataService(userId: nil))
}
