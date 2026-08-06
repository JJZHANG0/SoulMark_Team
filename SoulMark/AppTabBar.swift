//
//  AppTabBar.swift
//  SoulMark
//

import SwiftUI

struct AppTabBar: View {
    @Binding var selectedSection: AppSection
    @State private var draggedSelectionX: CGFloat?
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
        GeometryReader { proxy in
            let horizontalInset: CGFloat = 5
            let availableWidth = proxy.size.width - horizontalInset * 2
            let itemWidth = availableWidth / CGFloat(sections.count)
            let indicatorWidth = max(itemWidth - 5, 44)
            let restingCenterX = horizontalInset + (CGFloat(selectedIndex) + 0.5) * itemWidth
            let indicatorCenterX = clampedSelectionX(
                draggedSelectionX ?? restingCenterX,
                itemWidth: itemWidth,
                horizontalInset: horizontalInset
            )

            ZStack(alignment: .leading) {
                SoulLiquidGlassSelection()
                    .frame(width: indicatorWidth, height: 43)
                    .offset(x: indicatorCenterX - indicatorWidth / 2)
                    .animation(
                        draggedSelectionX == nil
                            ? .spring(response: 0.34, dampingFraction: 0.78)
                            : nil,
                        value: indicatorCenterX
                    )

                HStack(alignment: .center, spacing: 0) {
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
                .padding(.horizontal, horizontalInset)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .local)
                    .onChanged { value in
                        draggedSelectionX = clampedSelectionX(
                            value.location.x,
                            itemWidth: itemWidth,
                            horizontalInset: horizontalInset
                        )
                        selectNearestItem(
                            at: value.location.x,
                            itemWidth: itemWidth,
                            horizontalInset: horizontalInset
                        )
                    }
                    .onEnded { value in
                        selectNearestItem(
                            at: value.predictedEndLocation.x,
                            itemWidth: itemWidth,
                            horizontalInset: horizontalInset
                        )
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.76)) {
                            draggedSelectionX = nil
                        }
                    }
            )
        }
        .frame(height: 55)
        .background(SoulLiquidGlassBackground(cornerRadius: 26))
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func tabItem(_ section: AppSection) -> some View {
        let isSelected = selectedSection == section
        VStack(spacing: 2) {
            Image(systemName: section.systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(isSelected ? SoulTheme.accent : SoulTheme.secondaryText)
                .frame(height: 25)

            Text(section.title)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(isSelected ? SoulTheme.primaryText : SoulTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var selectedIndex: Int {
        sections.firstIndex(of: selectedSection) ?? 0
    }

    private func clampedSelectionX(
        _ x: CGFloat,
        itemWidth: CGFloat,
        horizontalInset: CGFloat
    ) -> CGFloat {
        min(
            max(x, horizontalInset + itemWidth / 2),
            horizontalInset + itemWidth * (CGFloat(sections.count) - 0.5)
        )
    }

    private func selectNearestItem(
        at x: CGFloat,
        itemWidth: CGFloat,
        horizontalInset: CGFloat
    ) {
        let rawIndex = Int(((x - horizontalInset) / itemWidth).rounded(.down))
        let index = min(max(rawIndex, 0), sections.count - 1)
        guard selectedSection != sections[index] else { return }
        withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
            selectedSection = sections[index]
        }
    }
}
