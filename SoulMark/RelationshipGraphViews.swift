//
//  RelationshipGraphViews.swift
//  SoulMark
//

import PhotosUI
import SwiftUI

enum RelationshipOwnerDisplayName {
    static func resolve(_ displayName: String?, language: String? = nil) -> String {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmed.isEmpty else { return trimmed }
        let selectedLanguage = language ?? UserDefaults.standard.string(forKey: "soulMarkLanguage")
        return selectedLanguage == "en" ? "Me" : "我"
    }
}

struct RelationshipHeader: View {
    let onBackHome: () -> Void
    let onAddPerson: () -> Void
    let onOpenScenario: () -> Void
    let onOpenCategories: () -> Void

    var body: some View {
        SoulPageHeader(
            eyebrow: "Network / 02",
            title: localizedText("关系图谱", "Relationship Map"),
            subtitle: localizedText("看见每一段关系正在靠近，还是远离。", "See which relationships are moving closer and which are drifting away.")
        ) {
            HStack(spacing: 8) {
                Menu {
                    Button(action: onOpenCategories) {
                        Label(localizedText("关系分类", "Relationship Categories"), systemImage: "line.3.horizontal.decrease.circle.fill")
                    }

                    Button(action: onBackHome) {
                        Label(localizedText("返回首页", "Back Home"), systemImage: "house.fill")
                    }

                    Button(action: onOpenScenario) {
                        Label(localizedText("开始模拟", "Start Simulation"), systemImage: "figure.wave")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(SoulTheme.primaryText)
                        .frame(width: 42, height: 42)
                        .background(SoulTheme.cardFill, in: Circle())
                        .overlay(Circle().stroke(SoulTheme.cardStroke, lineWidth: 1))
                }

                SoulIconButton(systemImage: "person.badge.plus", isEmphasized: true, action: onAddPerson)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 4)
    }
}

struct PlaceholderPage: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        ZStack {
            RelationshipBackground()

            VStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(SoulTheme.accent)
                    .frame(width: 86, height: 86)
                    .background(SoulTheme.cardFill, in: Circle())
                    .overlay(Circle().stroke(SoulTheme.cardStroke, lineWidth: 1))

                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(primaryTextColor)

                Text(subtitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 36)
            }
            .padding(.bottom, 90)
        }
    }
}

struct RelationshipMapView: View {
    let people: [RelationshipPerson]
    let ownerDisplayName: String?
    let selectedPerson: RelationshipPerson?
    let onMovePerson: (RelationshipPerson.ID, CGPoint) -> Void
    let onOrganize: () -> Void
    let onSelect: (RelationshipPerson) -> Void
    let onAddPerson: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let center = CGPoint(x: 0.50, y: 0.50)

    var body: some View {
        GeometryReader { proxy in
            let viewport = proxy.size
            let canvas = CGSize(
                width: max(viewport.width * 1.32, 560),
                height: max(viewport.height * 1.15, 760)
            )
            let centerPoint = actualPoint(center, in: canvas)

            ZStack {
                ZStack {
                    ForEach(people) { person in
                        let point = actualPoint(person.position, in: canvas)
                        RelationshipLine(
                            from: centerPoint,
                            to: point,
                            person: person,
                            isSelected: selectedPerson == person
                        )
                    }

                    ForEach(people) { person in
                        let point = actualPoint(person.position, in: canvas)
                        RelationshipNode(
                            person: person,
                            isSelected: selectedPerson == person,
                            centerPoint: centerPoint,
                            point: point,
                            canvasSize: canvas,
                            scale: scale,
                            onMovePerson: onMovePerson,
                            onSelect: onSelect
                        )
                    }

                    CenterProfile(displayName: RelationshipOwnerDisplayName.resolve(ownerDisplayName))
                        .position(centerPoint)

                    if people.isEmpty {
                        Button(action: onAddPerson) {
                            Label(localizedText("添加第一个人", "Add Your First Person"), systemImage: "person.badge.plus")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 16)
                                .frame(height: 42)
                                .background(SoulTheme.accent, in: RoundedRectangle(cornerRadius: 8))
                                .shadow(color: SoulTheme.accent.opacity(0.25), radius: 10, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)
                        .position(x: centerPoint.x, y: centerPoint.y + 176)
                    }
                }
                .frame(width: canvas.width, height: canvas.height)
                .scaleEffect(scale)
                .offset(offset)
            }
            .frame(width: viewport.width, height: viewport.height)
            .contentShape(Rectangle())
            .simultaneousGesture(dragGesture)
            .simultaneousGesture(zoomGesture)
            .overlay(alignment: .topLeading) {
                if !people.isEmpty {
                    Button(action: onOrganize) {
                        Label(localizedText("整理", "Organize"), systemImage: "wand.and.stars")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(SoulTheme.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(SoulGlassCapsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    .padding(.leading, 16)
                }
            }
            .overlay(alignment: .topTrailing) {
                MapControlHint(scale: scale)
                    .padding(.top, 8)
                    .padding(.trailing, 16)
            }
        }
        .clipped()
    }

    private func actualPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 0.72), 1.75)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }
}

private struct RelationshipLine: View {
    let from: CGPoint
    let to: CGPoint
    let person: RelationshipPerson
    let isSelected: Bool

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: from)
                path.addLine(to: to)
            }
            .stroke(
                person.category.color.opacity(isSelected ? 0.92 : 0.50),
                style: StrokeStyle(
                    lineWidth: isSelected ? 3.2 : max(1.0, person.strength * 3.0),
                    lineCap: .round,
                    dash: person.category.isDashed ? [5, 6] : []
                )
            )

            Text(person.category.displayTitle)
                .font(.system(size: isSelected ? 12 : 10, weight: .heavy, design: .rounded))
                .foregroundStyle(person.category.color.opacity(isSelected ? 1 : 0.70))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(SoulGlassCapsule())
                .rotationEffect(.degrees(labelAngle))
                .position(offsetLabelPoint)
        }
    }

    private var labelPoint: CGPoint {
        CGPoint(x: from.x + (to.x - from.x) * 0.58, y: from.y + (to.y - from.y) * 0.58)
    }

    private var offsetLabelPoint: CGPoint {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = max(sqrt(dx * dx + dy * dy), 1)
        let side: CGFloat = to.y < from.y ? -1 : 1
        let distance: CGFloat = isSelected ? 18 : 14

        return CGPoint(
            x: labelPoint.x + (-dy / length) * distance * side,
            y: labelPoint.y + (dx / length) * distance * side
        )
    }

    private var labelAngle: Double {
        let radians = atan2(to.y - from.y, to.x - from.x)
        let degrees = radians * 180 / .pi
        return degrees > 90 || degrees < -90 ? degrees + 180 : degrees
    }
}

private struct MapControlHint: View {
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 11, weight: .bold))

            Text("\(Int(scale * 100))%")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(SoulTheme.primaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(SoulGlassCapsule())
    }
}

private struct RelationshipNode: View {
    let person: RelationshipPerson
    let isSelected: Bool
    let centerPoint: CGPoint
    let point: CGPoint
    let canvasSize: CGSize
    let scale: CGFloat
    let onMovePerson: (RelationshipPerson.ID, CGPoint) -> Void
    let onSelect: (RelationshipPerson) -> Void

    var body: some View {
        HStack(spacing: 6) {
            if shouldPutTextFirst {
                label
            }

            ZStack(alignment: .bottomTrailing) {
                ContactAvatarView(
                    avatarPath: person.avatarURL,
                    color: person.category.color,
                    symbol: person.symbol,
                    size: avatarSize
                )
                    .contentShape(Circle())
                    .onTapGesture {
                        onSelect(person)
                    }
            }

            if !shouldPutTextFirst {
                label
            }
        }
        .padding(6)
        .background(
            isSelected ? SoulTheme.cardFill : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(person.category.color.opacity(0.42), lineWidth: 1)
            }
        }
        .position(x: point.x + CGFloat(labelLayout.horizontalDirection) * 46, y: point.y)
    }

    private var label: some View {
        VStack(alignment: shouldPutTextFirst ? .trailing : .leading, spacing: 2) {
            Text(person.name)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(SoulTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(person.displayNote)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(SoulTheme.secondaryText)
                .lineLimit(1)
        }
        .frame(width: 86, alignment: shouldPutTextFirst ? .trailing : .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(person)
        }
    }

    private var shouldPutTextFirst: Bool {
        labelLayout.horizontalDirection < 0
    }

    private var labelLayout: RelationshipLabelLayout {
        RelationshipLabelPlacement.layout(node: point, center: centerPoint)
    }

    private var avatarSize: CGFloat {
        isSelected ? 66 : 54
    }
}

private struct CenterProfile: View {
    let displayName: String

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(SoulTheme.energy.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [5, 7]))
                    .frame(width: 166, height: 166)

                Circle()
                    .fill(SoulTheme.visorSurface)
                    .frame(width: 126, height: 126)
                    .overlay(Circle().stroke(SoulTheme.energy.opacity(0.32), lineWidth: 1))

                Circle()
                    .fill(Color.white)
                    .frame(width: 88, height: 88)
                    .overlay {
                        Capsule()
                            .fill(Color.black.opacity(0.94))
                            .frame(width: 82, height: 34)
                            .overlay {
                                Capsule()
                                    .fill(SoulTheme.energy)
                                    .frame(width: 42, height: 3)
                            }
                            .offset(y: -3)
                    }
            }

            VStack(spacing: 2) {
                Text(displayName)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(SoulTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.56)
                    .frame(maxWidth: 180)

                Text(localizedText("你的关系坐标", "YOUR RELATIONSHIP ORIGIN"))
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(SoulTheme.energy)
            }
        }
    }
}

struct RelationshipFilterBar: View {
    @Binding var selectedFilter: RelationshipFilter
    @Binding var selectedCustomCategory: RelationshipCategory?
    let filters: [RelationshipFilter]
    let customCategories: [RelationshipCategory]
    let onAddRelationship: () -> Void
    let onDeleteRelationship: (RelationshipCategory) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters) { filter in
                    ZStack(alignment: .topTrailing) {
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                selectedFilter = filter
                                selectedCustomCategory = nil
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: filter.systemImage)
                                    .font(.system(size: 13, weight: .bold))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(filter.title)
                                        .font(.system(size: 16, weight: .bold))

                                    Text(filter.subtitle)
                                        .font(.system(size: 9, weight: .semibold))
                                        .lineLimit(1)
                                }
                            }
                            .foregroundStyle(SoulTheme.primaryText)
                            .frame(width: 106, height: 56)
                            .background(
                                Capsule()
                                    .fill(selectedFilter == filter && selectedCustomCategory == nil ? filter.tint.opacity(0.22) : SoulTheme.cardFill)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selectedFilter == filter && selectedCustomCategory == nil ? filter.tint.opacity(0.58) : SoulTheme.cardStroke, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        if let category = filter.category {
                            Button {
                                onDeleteRelationship(category)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(SoulTheme.danger, SoulTheme.cardFill)
                                    .frame(width: 28, height: 28)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .offset(x: 6, y: -6)
                        }
                    }
                }

                ForEach(customCategories) { category in
                    ZStack(alignment: .topTrailing) {
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                selectedFilter = .all
                                selectedCustomCategory = category
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: category.systemImage)
                                    .font(.system(size: 13, weight: .bold))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(category.shortTitle)
                                        .font(.system(size: 16, weight: .bold))
                                        .lineLimit(1)

                    Text(localizedText("自定义", "Custom"))
                                        .font(.system(size: 9, weight: .semibold))
                                }
                            }
                            .foregroundStyle(SoulTheme.primaryText)
                            .frame(width: 106, height: 56)
                            .background(
                                Capsule()
                                    .fill(selectedCustomCategory == category ? category.color.opacity(0.22) : SoulTheme.cardFill)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selectedCustomCategory == category ? category.color.opacity(0.58) : SoulTheme.cardStroke, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            onDeleteRelationship(category)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(SoulTheme.danger, SoulTheme.cardFill)
                                .frame(width: 28, height: 28)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .offset(x: 6, y: -6)
                    }
                }

                Button(action: onAddRelationship) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(SoulTheme.accent)
                        .frame(width: 56, height: 56)
                        .background(SoulTheme.cardFill, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(SoulTheme.accent.opacity(0.24), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(6)
        }
        .background(.ultraThinMaterial, in: Capsule())
        .background(SoulTheme.cardFill.opacity(0.72), in: Capsule())
        .overlay(Capsule().stroke(SoulTheme.cardStroke, lineWidth: 1))
    }
}

struct RelationshipCategoriesSheet: View {
    @Binding var selectedFilter: RelationshipFilter
    @Binding var selectedCustomCategory: RelationshipCategory?
    let filters: [RelationshipFilter]
    let customCategories: [RelationshipCategory]
    let onAddRelationship: () -> Void
    let onDeleteRelationship: (RelationshipCategory) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            SoulBackground()

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizedText("关系分类", "Relationship Categories"))
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(SoulTheme.primaryText)

                        Text(localizedText("筛选、添加或删除关系类型", "Filter, add, or remove relationship types"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(SoulTheme.secondaryText)
                    }

                    Spacer()

                    SoulIconButton(systemImage: "xmark") {
                        dismiss()
                    }
                }

                RelationshipFilterBar(
                    selectedFilter: $selectedFilter,
                    selectedCustomCategory: $selectedCustomCategory,
                    filters: filters,
                    customCategories: customCategories,
                    onAddRelationship: onAddRelationship,
                    onDeleteRelationship: onDeleteRelationship
                )

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .onChange(of: selectedFilter) { _, _ in
            dismiss()
        }
        .onChange(of: selectedCustomCategory) { _, newValue in
            if newValue != nil {
                dismiss()
            }
        }
    }
}

struct MembershipUpgradeSheet: View {
    let currentPeopleCount: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            SoulBackground()

            VStack(spacing: 18) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 74, height: 74)
                    .background(SoulTheme.accent, in: Circle())
                    .shadow(color: SoulTheme.accent.opacity(0.28), radius: 14, x: 0, y: 8)

                VStack(spacing: 7) {
                    Text(localizedText("解锁更多关系位置", "Unlock More Relationship Slots"))
                        .font(.system(size: 23, weight: .heavy, design: .rounded))
                        .foregroundStyle(SoulTheme.primaryText)
                        .multilineTextAlignment(.center)

                    Text(localizedText(
                        "免费版可添加 5 人。你已经使用 \(currentPeopleCount)/\(FreeRelationshipPolicy.maximumPeople) 个位置。",
                        "The free plan includes 5 people. You are using \(currentPeopleCount)/\(FreeRelationshipPolicy.maximumPeople) slots."
                    ))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(SoulTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                }

                Label(localizedText("会员功能将在后续版本开放", "Membership will arrive in a future version"), systemImage: "info.circle.fill")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(SoulTheme.energy)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(SoulTheme.energySoft, in: RoundedRectangle(cornerRadius: 8))

                Button {
                    dismiss()
                } label: {
                    Text(localizedText("我知道了", "Got It"))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(SoulTheme.accent, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
    }
}

struct RelationshipDetailSheet: View {
    let person: RelationshipPerson
    let availableCategories: [RelationshipCategory]
    let onCategoryChange: (RelationshipCategory) -> Void
    let onDeletePerson: () -> Void
    let onStartScenario: () -> Void
    let onAvatarChange: (Data) -> Void
    let onAvatarDelete: () -> Void
    @State private var pendingCategory: RelationshipCategory?
    @State private var isConfirmingDeletePerson = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        ContactAvatarView(
                            avatarPath: person.avatarURL,
                            color: person.category.color,
                            symbol: person.symbol,
                            size: 64
                        )

                        Image(systemName: "camera.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(width: 24, height: 24)
                            .background(SoulTheme.accent, in: Circle())
                            .overlay(Circle().stroke(SoulTheme.cardFill, lineWidth: 2))
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(primaryTextColor)

                    Text(person.displayNote)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                }

                Spacer()

                Text(person.category.displayTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(person.category.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(person.category.color.opacity(0.12), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(localizedText("关系记忆", "Relationship Memory"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(primaryTextColor)

                Text(person.displayMemory)
                    .font(.system(size: 15))
                    .foregroundStyle(secondaryTextColor)
                    .lineSpacing(3)
            }

            HStack(spacing: 12) {
                RelationshipMetric(title: localizedText("亲密度", "Closeness"), value: "\(Int(person.strength * 100))%")
                RelationshipMetric(title: localizedText("关系类型", "Relationship"), value: person.category.displayTitle)
                RelationshipMetric(title: localizedText("建议", "Suggestion"), value: person.strength > 0.7 ? localizedText("保持联系", "Keep in touch") : localizedText("轻触达", "Light check-in"))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(localizedText("更改关系", "Change Relationship"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(primaryTextColor)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableCategories) { category in
                            Button {
                                pendingCategory = category
                            } label: {
                                Text(category.shortTitle)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(person.category == category ? SoulTheme.primaryText : category.color)
                                    .padding(.horizontal, 14)
                                    .frame(height: 38)
                                    .background(
                                        Capsule()
                                            .fill(person.category == category ? category.color.opacity(0.24) : category.color.opacity(0.12))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if person.avatarURL != nil {
                Button(role: .destructive, action: onAvatarDelete) {
                    Label(localizedText("删除头像", "Remove Photo"), systemImage: "person.crop.circle.badge.minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(SoulTheme.danger)
                }
                .buttonStyle(.plain)
            }

            Button(action: onStartScenario) {
                Label(localizedText("与 \(person.name) 情景模拟", "Simulate with \(person.name)"), systemImage: "figure.wave")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(SoulTheme.accent, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                isConfirmingDeletePerson = true
            } label: {
                Label(localizedText("从关系图谱删除此人", "Remove this person from map"), systemImage: "trash.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(SoulTheme.danger)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(SoulTheme.danger.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(24)
        .background(SoulTheme.pageGradient)
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw ContactAvatarImageProcessor.ProcessingError.invalidImage
                    }
                    onAvatarChange(try ContactAvatarImageProcessor.prepare(data))
                } catch {
                    photoErrorMessage = localizedText(
                        "无法读取这张图片，请选择另一张。",
                        "This photo could not be read. Choose another one."
                    )
                }
            }
        }
        .alert(
            localizedText("头像没有更新", "Photo Not Updated"),
            isPresented: Binding(
                get: { photoErrorMessage != nil },
                set: { if !$0 { photoErrorMessage = nil } }
            )
        ) {
            Button(localizedText("知道了", "OK")) { photoErrorMessage = nil }
        } message: {
            Text(photoErrorMessage ?? "")
        }
        .confirmationDialog(
            localizedText("确认更改关系？", "Confirm relationship change?"),
            isPresented: Binding(
                get: { pendingCategory != nil },
                set: { if !$0 { pendingCategory = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pendingCategory {
                Button(localizedText("确认改为\(pendingCategory.displayTitle)", "Confirm: \(pendingCategory.displayTitle)")) {
                    onCategoryChange(pendingCategory)
                    self.pendingCategory = nil
                }
            }

            Button(localizedText("取消", "Cancel"), role: .cancel) {
                pendingCategory = nil
            }
        } message: {
            if let pendingCategory {
                Text(localizedText("将 \(person.name) 与你的关系改为\(pendingCategory.displayTitle)。", "Change your relationship with \(person.name) to \(pendingCategory.displayTitle)."))
            }
        }
        .confirmationDialog(
            localizedText("删除这个人？", "Delete this person?"),
            isPresented: $isConfirmingDeletePerson,
            titleVisibility: .visible
        ) {
            Button(localizedText("确认删除\(person.name)", "Delete \(person.name)"), role: .destructive) {
                onDeletePerson()
            }

            Button(localizedText("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(localizedText("删除后，\(person.name) 会从关系图谱里移除。", "\(person.name) will be removed from the relationship map."))
        }
    }
}

private struct RelationshipMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondaryTextColor)

            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(SoulTheme.subtleFill, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct AddPersonSheet: View {
    let availableCategories: [RelationshipCategory]
    let onAdd: (String, String, RelationshipCategory, Data?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var note = ""
    @State private var selectedCategory: RelationshipCategory
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var photoErrorMessage: String?

    init(
        availableCategories: [RelationshipCategory],
        onAdd: @escaping (String, String, RelationshipCategory, Data?) -> Void
    ) {
        self.availableCategories = availableCategories
        self.onAdd = onAdd
        _selectedCategory = State(initialValue: availableCategories.first ?? .friend)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(localizedText("添加人物", "Add Person"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(SoulTheme.primaryText)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(SoulTheme.primaryText)
                        .frame(width: 34, height: 34)
                        .background(SoulTheme.cardFill, in: Circle())
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                TextField(localizedText("名字", "Name"), text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField(localizedText("一句关系备注", "One-line relationship note"), text: $note)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 14) {
                ContactAvatarView(
                    avatarPath: nil,
                    color: selectedCategory.color,
                    symbol: avatarData == nil ? "person.fill" : "checkmark",
                    size: 58
                )
                .overlay {
                    if let avatarData, let image = UIImage(data: avatarData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(
                            avatarData == nil
                                ? localizedText("添加头像（可跳过）", "Add photo (optional)")
                                : localizedText("更换头像", "Change photo"),
                            systemImage: "photo.on.rectangle"
                        )
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(SoulTheme.accent)
                    }

                    if avatarData != nil {
                        Button(localizedText("移除已选头像", "Remove selected photo")) {
                            avatarData = nil
                            selectedPhotoItem = nil
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SoulTheme.secondaryText)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(localizedText("选择关系", "Choose Relationship"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(SoulTheme.primaryText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableCategories) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Text(category.shortTitle)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(selectedCategory == category ? SoulTheme.primaryText : category.color)
                                    .padding(.horizontal, 14)
                                    .frame(height: 40)
                                    .background(
                                        Capsule()
                                            .fill(selectedCategory == category ? category.color.opacity(0.24) : category.color.opacity(0.12))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Button {
                onAdd(name, note, selectedCategory, avatarData)
                dismiss()
            } label: {
                Label(localizedText("添加到图谱", "Add to Map"), systemImage: "person.badge.plus")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canSubmit ? SoulTheme.accent : Color.gray.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
            }
            .disabled(!canSubmit)

            Spacer()
        }
        .padding(24)
        .background(SoulTheme.pageGradient)
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw ContactAvatarImageProcessor.ProcessingError.invalidImage
                    }
                    avatarData = try ContactAvatarImageProcessor.prepare(data)
                } catch {
                    avatarData = nil
                    photoErrorMessage = localizedText(
                        "无法读取这张图片，请选择另一张。",
                        "This photo could not be read. Choose another one."
                    )
                }
            }
        }
        .alert(
            localizedText("头像没有添加", "Photo Not Added"),
            isPresented: Binding(
                get: { photoErrorMessage != nil },
                set: { if !$0 { photoErrorMessage = nil } }
            )
        ) {
            Button(localizedText("知道了", "OK")) { photoErrorMessage = nil }
        } message: {
            Text(photoErrorMessage ?? "")
        }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct AddRelationshipSheet: View {
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(localizedText("自定义关系", "Custom Relationship"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(SoulTheme.primaryText)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(SoulTheme.primaryText)
                        .frame(width: 34, height: 34)
                        .background(SoulTheme.cardFill, in: Circle())
                }
            }

            TextField(localizedText("例如：兄弟、闺蜜、导师", "Example: Brother, Best Friend, Mentor"), text: $name)
                .textFieldStyle(.roundedBorder)

            Button {
                onAdd(name.trimmingCharacters(in: .whitespacesAndNewlines))
                dismiss()
            } label: {
                Label(localizedText("添加关系", "Add Relationship"), systemImage: "tag.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canSubmit ? SoulTheme.accent : Color.gray.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
            }
            .disabled(!canSubmit)

            Spacer()
        }
        .padding(24)
        .background(SoulTheme.pageGradient)
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct RelationshipBackground: View {
    var body: some View {
        SoulBackground()
    }
}
