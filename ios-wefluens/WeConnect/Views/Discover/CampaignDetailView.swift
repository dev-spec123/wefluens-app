//
//  CampaignDetailView.swift
//  WeConnect
//

import SwiftUI

struct CampaignDetailView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    let campaign: Campaign
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                quickStats
                aboutCard
                deliverablesCard
            }
            .padding(.bottom, 120)
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.25))
                    .clipShape(Circle())
            }
            .padding(.leading, 18)
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            applyBar
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: campaign.colors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: campaign.symbol)
                .font(.system(size: 120, weight: .bold))
                .foregroundStyle(.white.opacity(0.15))
                .offset(x: 110, y: 20)

            VStack(alignment: .leading, spacing: 8) {
                Text(campaign.brand.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .tracking(2)
                Text(campaign.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(22)
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    private var quickStats: some View {
        HStack(spacing: 12) {
            stat(icon: "dollarsign.circle.fill", value: campaign.budget, label: l10n.t(.campaignDetailBudget))
            stat(icon: "calendar", value: campaign.deadline, label: l10n.t(.campaignDetailDeadline))
            stat(icon: "person.2.fill", value: "\(campaign.spotsLeft)", label: l10n.t(.campaignDetailSpots))
        }
        .padding(.horizontal, 18)
    }

    private func stat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.coral)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .cardStyle(cornerRadius: 18)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n.t(.campaignDetailAbout))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.ink(for: colorScheme))
            Text("\(campaign.brand) is looking for authentic creators to bring \(campaign.title) to life. We're seeking on-brand storytelling that resonates with engaged audiences and drives measurable impact across social.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                .lineSpacing(4)

            HStack(spacing: 8) {
                ForEach(campaign.tags, id: \.self) { tag in
                    TagChip(text: tag)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardStyle()
        .padding(.horizontal, 18)
    }

    private var deliverablesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(l10n.t(.campaignDetailDeliverables))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.ink(for: colorScheme))
            deliverable("2x Instagram Reels")
            deliverable("3x Story frames with link")
            deliverable("1x Usage rights for 30 days")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardStyle()
        .padding(.horizontal, 18)
    }

    private func deliverable(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.coral)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.ink(for: colorScheme))
            Spacer()
        }
    }

    private var applyBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(campaign.budget)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                Text(l10n.t(.campaignDetailEstimatedPayout))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }
            Spacer()
            Button {
            } label: {
                Text(l10n.t(.campaignDetailApply))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 15)
                    .background(Theme.sunset)
                    .clipShape(Capsule())
                    .shadow(color: Theme.coral.opacity(0.4), radius: 12, y: 6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    NavigationStack {
        CampaignDetailView(campaign: SampleData.campaigns[0])
    }
}
