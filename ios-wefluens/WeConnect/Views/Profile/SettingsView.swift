//
//  SettingsView.swift
//  WeConnect
//

import SwiftUI

struct SettingsView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(ThemeManager.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                appearanceSection
                languageSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationTitle(l10n.t(.settingsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(l10n.t(.settingsDone)) { dismiss() }
                    .foregroundStyle(Theme.coral)
            }
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n.t(.settingsAppearance).uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                .tracking(1)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(ColorSchemeMode.allCases.enumerated()), id: \.element.id) { index, mode in
                    appearanceRow(mode)
                    if index < ColorSchemeMode.allCases.count - 1 {
                        Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 14)
                    }
                }
            }
            .padding(.vertical, 4)
            .cardStyle()

            Text(l10n.t(.settingsAppearanceFooter))
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                .padding(.horizontal, 4)
        }
    }

    private func appearanceRow(_ mode: ColorSchemeMode) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                theme.mode = mode
            }
        } label: {
            HStack(spacing: 14) {
                Text(l10n.t(mode.labelKey))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                Spacer()
                if theme.mode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.coral)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n.t(.settingsLanguage).uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                .tracking(1)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, lang in
                    languageRow(lang)
                    if index < AppLanguage.allCases.count - 1 {
                        Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 60)
                    }
                }
            }
            .padding(.vertical, 4)
            .cardStyle()

            Text(l10n.t(.settingsLanguageFooter))
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                .padding(.horizontal, 4)
        }
    }

    private func languageRow(_ lang: AppLanguage) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                l10n.language = lang
            }
        } label: {
            HStack(spacing: 14) {
                Text(lang.flag)
                    .font(.system(size: 24))
                    .frame(width: 36, height: 36)
                Text(lang.nativeName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                Spacer()
                if l10n.language == lang {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.coral)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .environment(LocalizationManager())
        .environment(ThemeManager())
}
