//
//  InviteCodesView.swift
//  WeConnect
//
//  Admin invite-code management (Developer panel). Mint codes (with max-uses +
//  optional expiry + label), see their status/usage, copy, and revoke. English-only
//  (admin tool). All RPCs are is_admin-gated server-side.
//

import SwiftUI
import UIKit

struct InviteCodesView: View {
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme

    @State private var codes: [InviteCodeRow] = []
    @State private var isLoading = true
    @State private var busy = false
    @State private var errorText: String?

    // New-code form
    @State private var maxUses = 1
    @State private var label = ""
    @State private var setExpiry = false
    @State private var expiryDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let errorText {
                    Text(errorText)
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(.red)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
                }

                generator
                list
            }
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 28)
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Invite Codes")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(Theme.ink(for: colorScheme).opacity(0.92)).clipShape(Capsule())
                    .padding(.bottom, 24).transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task { await reload() }
    }

    // MARK: - Generator

    private var generator: some View {
        VStack(alignment: .leading, spacing: 12) {
            header("NEW CODE")
            VStack(spacing: 0) {
                HStack {
                    Text("Max uses").font(.system(size: 15)).foregroundStyle(Theme.ink(for: colorScheme))
                    Spacer()
                    Stepper(value: $maxUses, in: 1...1000) {
                        Text("\(maxUses)").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.coral)
                    }
                    .fixedSize()
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                rowDivider
                HStack {
                    Toggle(isOn: $setExpiry) {
                        Text("Set expiry").font(.system(size: 15)).foregroundStyle(Theme.ink(for: colorScheme))
                    }.tint(Theme.coral)
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                if setExpiry {
                    rowDivider
                    DatePicker("Expires", selection: $expiryDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.compact).tint(Theme.coral)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                }
                rowDivider
                TextField("Label (optional, e.g. 'Beta round')", text: $label)
                    .font(.system(size: 15)).autocorrectionDisabled()
                    .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .cardStyle()

            Button { generate() } label: {
                HStack(spacing: 8) {
                    if busy { ProgressView().tint(.white) }
                    else { Image(systemName: "plus.circle.fill") }
                    Text("Generate code").font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(Theme.sunset).clipShape(Capsule())
            }
            .buttonStyle(.plain).disabled(busy)
        }
    }

    // MARK: - List

    private var list: some View {
        VStack(alignment: .leading, spacing: 12) {
            header("CODES")
            if isLoading {
                ProgressView().tint(Theme.coral).frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if codes.isEmpty {
                Text("No codes yet.").font(.system(size: 14))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .padding(.horizontal, 14).padding(.vertical, 10)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(codes.enumerated()), id: \.element.id) { index, code in
                        codeRow(code)
                        if index < codes.count - 1 { rowDivider }
                    }
                }
                .cardStyle()
            }
        }
    }

    private func codeRow(_ c: InviteCodeRow) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(c.code)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.ink(for: colorScheme))
                    statusBadge(c.status)
                }
                Text(subtitle(c))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Button {
                UIPasteboard.general.string = c.code
                show("Copied \(c.code)")
            } label: {
                Image(systemName: "doc.on.doc").font(.system(size: 15)).foregroundStyle(Theme.coral)
            }
            .buttonStyle(.plain)
            if c.status == "active" {
                Button { revoke(c) } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundStyle(Theme.inkTertiary(for: colorScheme))
                }
                .buttonStyle(.plain).disabled(busy)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func statusBadge(_ status: String) -> some View {
        let color: Color = status == "active" ? Color(hex: 0x2AD17E) : Theme.inkTertiary(for: colorScheme)
        return Text(status.uppercased())
            .font(.system(size: 9, weight: .bold)).tracking(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.14)).clipShape(Capsule())
    }

    private func subtitle(_ c: InviteCodeRow) -> String {
        var parts = ["\(c.uses)/\(c.maxUses) used"]
        if let label = c.label, !label.isEmpty { parts.append(label) }
        if let exp = c.expiresAt {
            parts.append("exp " + exp.formatted(.dateTime.month().day()))
        }
        return parts.joined(separator: " · ")
    }

    private func header(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .bold))
            .foregroundStyle(Theme.inkTertiary(for: colorScheme)).tracking(1).padding(.leading, 4)
    }

    private var rowDivider: some View {
        Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 14)
    }

    // MARK: - Actions

    @MainActor private func reload() async {
        do { codes = try await data.adminListInviteCodes(); errorText = nil }
        catch { errorText = "Couldn't load codes: \(error.localizedDescription)" }
        isLoading = false
    }

    private func generate() {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                let code = try await data.adminCreateInviteCode(
                    maxUses: maxUses,
                    expiresAt: setExpiry ? expiryDate : nil,
                    label: label)
                UIPasteboard.general.string = code
                label = ""
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                show("Created \(code) — copied")
                await reload()
            } catch { errorText = "Couldn't create code: \(error.localizedDescription)" }
        }
    }

    private func revoke(_ c: InviteCodeRow) {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do { try await data.adminRevokeInviteCode(id: c.id); await reload() }
            catch { errorText = "Couldn't revoke: \(error.localizedDescription)" }
        }
    }

    private func show(_ message: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.25)) { toast = nil }
        }
    }
}
