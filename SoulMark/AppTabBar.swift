//
//  AppTabBar.swift
//  SoulMark
//

import SwiftUI

struct AppTabBar: View {
    @Binding var selectedSection: AppSection
    @AppStorage("soulMarkLanguage") private var language = "zh"
    @AppStorage("soulMarkGenderTheme") private var genderTheme = "male"
    @AppStorage("soulMarkAppearanceMode") private var appearanceMode = "auto"

    private let sections: [AppSection] = [
        .home,
        .relationshipGraph,
        .scenarioSimulation,
        .journal,
        .profile
    ]

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(sections, id: \.title) { section in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        selectedSection = section
                    }
                } label: {
                    tabItem(section)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.title)
                .accessibilityAddTraits(selectedSection == section ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(height: 68)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(SoulTheme.cardFill.opacity(0.68), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(SoulTheme.cardStroke, lineWidth: 1)
        }
        .shadow(color: SoulTheme.shadow, radius: 24, x: 0, y: 14)
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func tabItem(_ section: AppSection) -> some View {
        let isSelected = selectedSection == section
        let isPrimary = section == .scenarioSimulation

        VStack(spacing: 4) {
            ZStack {
                if isPrimary {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(SoulTheme.visorSurface)
                        .frame(width: 44, height: 40)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(isSelected ? SoulTheme.energy.opacity(0.88) : Color.white.opacity(0.11), lineWidth: 1)
                        }
                        .shadow(color: isSelected ? SoulTheme.energy.opacity(0.28) : .clear, radius: 12, x: 0, y: 5)
                } else if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(SoulTheme.accentSoft)
                        .frame(width: 38, height: 30)
                }

                Image(systemName: section.systemImage)
                    .font(.system(size: isPrimary ? 19 : 17, weight: .bold))
                    .foregroundStyle(
                        isPrimary
                        ? (isSelected ? SoulTheme.energy : Color.white.opacity(0.62))
                        : (isSelected ? SoulTheme.accent : SoulTheme.secondaryText)
                    )
            }
            .frame(height: 40)

            Text(section.title)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(isSelected ? SoulTheme.primaryText : SoulTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}
