//
//  ContentView.swift
//  SoulMark
//
//  Created by JJ Zhang on 2026/8/3.
//

import SwiftUI

private let primaryTextColor = Color(red: 0.13, green: 0.14, blue: 0.17)
private let secondaryTextColor = Color(red: 0.32, green: 0.33, blue: 0.38)

private enum AppSection {
    case home
    case relationshipGraph
    case scenarioSimulation
    case journal
    case profile

    var title: String {
        let isEnglish = UserDefaults.standard.string(forKey: "soulMarkLanguage") == "en"
        return switch self {
        case .home: isEnglish ? "Home" : "首页"
        case .relationshipGraph: isEnglish ? "Map" : "关系图谱"
        case .scenarioSimulation: isEnglish ? "Simulation" : "情景模拟"
        case .journal: isEnglish ? "Review" : "记录"
        case .profile: isEnglish ? "Me" : "我的"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .relationshipGraph: "point.3.connected.trianglepath.dotted"
        case .scenarioSimulation: "figure.wave"
        case .journal: "text.bubble.fill"
        case .profile: "person.crop.circle"
        }
    }
}

struct ContentView: View {
    @State private var selectedSection: AppSection = .scenarioSimulation
    @State private var selectedFilter: RelationshipFilter = .all
    @State private var selectedCustomCategory: RelationshipCategory?
    @State private var selectedPerson: RelationshipPerson?
    @State private var people = RelationshipSampleData.people
    @State private var customCategories: [RelationshipCategory] = []
    @State private var isAddingPerson = false
    @State private var isAddingRelationship = false
    @State private var pendingDeletedCategory: RelationshipCategory?
    @State private var deletedCategories: Set<RelationshipCategory> = []
    @State private var graphLayoutRevision = UUID()
    @State private var scenarioFocusedPersonID: RelationshipPerson.ID?
    @AppStorage("soulMarkLanguage") private var language = "zh"
    @AppStorage("soulMarkAppearanceMode") private var appearanceMode = "auto"

    private var availableCategories: [RelationshipCategory] {
        RelationshipCategory.builtIns.filter { !deletedCategories.contains($0) } + customCategories
    }

    private var availableFilters: [RelationshipFilter] {
        RelationshipFilter.allCases.filter { filter in
            guard let category = filter.category else { return true }
            return !deletedCategories.contains(category)
        }
    }

    private var visiblePeople: [RelationshipPerson] {
        if let selectedCustomCategory {
            return selectedCustomCategory.filteredPeople(from: people)
        }
        return selectedFilter.filteredPeople(from: people)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            currentPage

            AppTabBar(selectedSection: $selectedSection)
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(isSoulNightMode() ? .dark : .light)
    }

    @ViewBuilder
    private var currentPage: some View {
        switch selectedSection {
        case .home:
            IntegratedHomePage(
                onOpenRelationshipGraph: {
                    selectedSection = .relationshipGraph
                },
                onOpenScenario: {
                    selectedSection = .scenarioSimulation
                },
                onOpenJournal: {
                    selectedSection = .journal
                }
            )
        case .relationshipGraph:
            relationshipGraphPage
        case .scenarioSimulation:
            ScenarioSimulationView(
                relationshipPeople: people,
                focusedPersonID: scenarioFocusedPersonID
            )
        case .journal:
            ConversationReviewPage()
        case .profile:
            IntegratedProfilePage()
        }
    }

    private var relationshipGraphPage: some View {
        ZStack(alignment: .bottom) {
            RelationshipBackground()

            VStack(spacing: 0) {
                RelationshipHeader(
                    onBackHome: {
                        selectedSection = .home
                    },
                    onAddPerson: {
                        isAddingPerson = true
                    },
                    onOpenScenario: {
                        selectedSection = .scenarioSimulation
                    }
                )

                RelationshipMapView(
                    people: visiblePeople,
                    selectedPerson: selectedPerson,
                    onMovePerson: { id, position in
                        people.updatePosition(for: id, to: position)
                        if selectedPerson?.id == id {
                            selectedPerson = people.first { $0.id == id }
                        }
                    },
                    onOrganize: {
                        withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                            people.organizePositions()
                            graphLayoutRevision = UUID()
                            if let selectedPerson {
                                self.selectedPerson = people.first { $0.id == selectedPerson.id }
                            }
                        }
                    },
                    onSelect: { person in
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            selectedPerson = person
                        }
                    }
                )
                .id(graphLayoutRevision)
                .padding(.top, 8)
                .padding(.bottom, 154)
            }

            RelationshipFilterBar(
                selectedFilter: $selectedFilter,
                selectedCustomCategory: $selectedCustomCategory,
                filters: availableFilters,
                customCategories: customCategories,
                onAddRelationship: {
                    isAddingRelationship = true
                },
                onDeleteRelationship: { category in
                    pendingDeletedCategory = category
                }
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 106)
            .onChange(of: selectedFilter) { _, _ in
                selectedPerson = nil
            }
            .onChange(of: selectedCustomCategory) { _, _ in
                selectedPerson = nil
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(item: $selectedPerson) { person in
            RelationshipDetailSheet(
                person: person,
                availableCategories: availableCategories,
                onCategoryChange: { category in
                    people.updateRelationship(for: person.id, to: category)
                    selectedPerson = people.first { $0.id == person.id }
                },
                onDeletePerson: {
                    people.deletePerson(person.id)
                    selectedPerson = nil
                },
                onStartScenario: {
                    scenarioFocusedPersonID = person.id
                    selectedPerson = nil
                    selectedSection = .scenarioSimulation
                }
            )
            .presentationDetents([.height(450), .medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isAddingPerson) {
            AddPersonSheet(availableCategories: availableCategories) { name, note, category in
                people.addPerson(name: name, note: note, category: category)
            }
            .presentationDetents([.height(430), .medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isAddingRelationship) {
            AddRelationshipSheet { name in
                let category = RelationshipCategory.custom(name)
                if !customCategories.contains(category) {
                    customCategories.append(category)
                }
                selectedFilter = .all
                selectedCustomCategory = category
            }
            .presentationDetents([.height(260)])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            localizedText("删除这个关系？", "Delete this relationship?"),
            isPresented: Binding(
                get: { pendingDeletedCategory != nil },
                set: { if !$0 { pendingDeletedCategory = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pendingDeletedCategory {
                Button(localizedText("删除\(pendingDeletedCategory.displayTitle)", "Delete \(pendingDeletedCategory.displayTitle)"), role: .destructive) {
                    people.deleteRelationship(pendingDeletedCategory)
                    if customCategories.contains(pendingDeletedCategory) {
                        customCategories.removeAll { $0 == pendingDeletedCategory }
                    } else {
                        deletedCategories.insert(pendingDeletedCategory)
                    }
                    if selectedFilter.category == pendingDeletedCategory {
                        selectedFilter = .all
                    }
                    if selectedCustomCategory == pendingDeletedCategory {
                        selectedCustomCategory = nil
                        selectedFilter = .all
                    }
                    selectedPerson = nil
                    self.pendingDeletedCategory = nil
                }
            }

            Button(localizedText("取消", "Cancel"), role: .cancel) {
                pendingDeletedCategory = nil
            }
        } message: {
            if pendingDeletedCategory != nil {
                Text(localizedText("这个关系下的人会一起从关系图谱中移除。", "People under this relationship will also be removed from the map."))
            }
        }
    }
}

private func localizedText(_ chinese: String, _ english: String) -> String {
    UserDefaults.standard.string(forKey: "soulMarkLanguage") == "en" ? english : chinese
}

private func isSoulNightMode() -> Bool {
    let mode = UserDefaults.standard.string(forKey: "soulMarkAppearanceMode") ?? "auto"
    if mode == "night" { return true }
    if mode == "day" { return false }

    let hour = Calendar.current.component(.hour, from: Date())
    return hour < 7 || hour >= 19
}

private enum SoulTheme {
    static var isNight: Bool {
        isSoulNightMode()
    }

    static var isMale: Bool {
        (UserDefaults.standard.string(forKey: "soulMarkGenderTheme") ?? "male") == "male"
    }

    static var background: Color {
        if isNight {
            return isMale ? Color(red: 0.07, green: 0.09, blue: 0.12) : Color(red: 0.11, green: 0.09, blue: 0.12)
        }

        return isMale ? Color(red: 0.93, green: 0.95, blue: 0.98) : Color(red: 0.99, green: 0.95, blue: 0.97)
    }

    static var surface: Color {
        if isNight {
            return isMale ? Color(red: 0.13, green: 0.16, blue: 0.20) : Color(red: 0.18, green: 0.14, blue: 0.18)
        }

        return Color(red: 0.98, green: 0.99, blue: 1.0)
    }

    static var primaryText: Color {
        isNight ? Color(red: 0.93, green: 0.95, blue: 0.98) : primaryTextColor
    }

    static var secondaryText: Color {
        isNight ? Color(red: 0.67, green: 0.70, blue: 0.76) : secondaryTextColor
    }

    static var accent: Color {
        if isMale {
            return isNight ? Color(red: 0.30, green: 0.58, blue: 0.95) : Color(red: 0.22, green: 0.48, blue: 0.82)
        }

        return isNight ? Color(red: 0.95, green: 0.36, blue: 0.62) : Color(red: 0.92, green: 0.42, blue: 0.62)
    }

    static var support: Color {
        if isMale {
            return isNight ? Color(red: 0.38, green: 0.47, blue: 0.62) : Color(red: 0.67, green: 0.75, blue: 0.86)
        }

        return isNight ? Color(red: 0.50, green: 0.40, blue: 0.50) : Color(red: 0.92, green: 0.76, blue: 0.83)
    }
}

private struct IntegratedHomePage: View {
    @AppStorage("soulMarkLanguage") private var language = "zh"
    @AppStorage("soulMarkGenderTheme") private var genderTheme = "male"
    @AppStorage("soulMarkAppearanceMode") private var appearanceMode = "auto"
    @State private var showingSettings = false

    let onOpenRelationshipGraph: () -> Void
    let onOpenScenario: () -> Void
    let onOpenJournal: () -> Void

    var body: some View {
        ZStack {
            SoulTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    heroCard
                    quickActions
                    snapshotCard
                    progressCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 112)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SoulSettingsSheet()
                .presentationDetents([.medium])
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(localizedText("早上好", "Good morning"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SoulTheme.secondaryText)

                Text("SoulMark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(SoulTheme.primaryText)
            }

            Spacer()

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SoulTheme.primaryText)
                    .frame(width: 42, height: 42)
                    .background(SoulTheme.surface.opacity(0.92), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizedText("今日关系能量", "Today's Relationship Energy"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(SoulTheme.primaryText)

                    Text(localizedText("先从一个轻量练习开始，让今天的表达更清楚一点。", "Start with a light practice so your words feel clearer today."))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(SoulTheme.secondaryText)
                }

                Spacer()

                Circle()
                    .fill(LinearGradient(colors: [SoulTheme.accent.opacity(0.28), SoulTheme.support.opacity(0.18), SoulTheme.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 62, height: 62)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(SoulTheme.accent)
                    )
            }

            Button(action: onOpenScenario) {
                Label(localizedText("开始情景模拟", "Start Simulation"), systemImage: "mic.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(SoulTheme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(SoulCardBackground())
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            SoulActionCard(
                title: localizedText("关系图谱", "Relationship Map"),
                subtitle: localizedText("查看连接", "View connections"),
                icon: "point.3.connected.trianglepath.dotted",
                action: onOpenRelationshipGraph
            )

            SoulActionCard(
                title: localizedText("沟通复盘", "Review"),
                subtitle: localizedText("整理记录", "Organize notes"),
                icon: "text.bubble.fill",
                action: onOpenJournal
            )
        }
    }

    private var snapshotCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedText("关系快照", "Relationship Snapshot"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(SoulTheme.primaryText)

            ForEach(samplePeople, id: \.0) { person in
                HStack(spacing: 12) {
                    Circle()
                        .fill(LinearGradient(colors: [SoulTheme.accent.opacity(0.35), SoulTheme.support.opacity(0.24)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 42, height: 42)
                        .overlay(Text(String(person.0.prefix(1))).font(.system(size: 18, weight: .bold)).foregroundStyle(SoulTheme.primaryText))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.0)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(SoulTheme.primaryText)
                        Text(person.1)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SoulTheme.secondaryText)
                    }

                    Spacer()
                }
                .padding(12)
                .background(SoulTheme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(16)
        .background(SoulCardBackground())
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedText("最近记录", "Recent Notes"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(SoulTheme.primaryText)

            Text(localizedText("情景模拟、复盘和心情都会沉淀在这里。", "Simulations, reviews, and moods will collect here."))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SoulTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(SoulCardBackground())
    }

    private var samplePeople: [(String, String)] {
        [
            ("Wren", localizedText("知己", "Confidant")),
            ("Owen", localizedText("好友", "Friend")),
            ("Rhea", localizedText("朋友", "Friend"))
        ]
    }
}

private struct IntegratedProfilePage: View {
    @AppStorage("soulMarkLanguage") private var language = "zh"
    @AppStorage("soulMarkGenderTheme") private var genderTheme = "male"
    @AppStorage("soulMarkAppearanceMode") private var appearanceMode = "auto"
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            SoulTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    profileHeader
                    statsGrid
                    settingsCard
                    menuCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 112)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SoulSettingsSheet()
                .presentationDetents([.medium])
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(LinearGradient(colors: [SoulTheme.accent.opacity(0.28), SoulTheme.support.opacity(0.18), SoulTheme.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 92, height: 92)
                .overlay(
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 58))
                        .foregroundStyle(SoulTheme.accent)
                )

            Text("Yang Zirui")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(SoulTheme.primaryText)

            Text(localizedText("关系洞察等级 Lv.1", "Relationship Insight Lv.1"))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(SoulTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(SoulCardBackground())
    }

    private var statsGrid: some View {
        HStack(spacing: 12) {
            SoulStatCard(title: localizedText("记录", "Notes"), value: "3", icon: "text.bubble.fill")
            SoulStatCard(title: localizedText("连接", "People"), value: "12", icon: "person.2.fill")
            SoulStatCard(title: localizedText("等级", "Level"), value: "1", icon: "sparkles")
        }
    }

    private var settingsCard: some View {
        Button {
            showingSettings = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(SoulTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(SoulTheme.accent.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(localizedText("语言与外观", "Language & Appearance"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(SoulTheme.primaryText)

                    Text(localizedText("语言、性别配色、自动日夜模式", "Language, gender-based palette, automatic day/night"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SoulTheme.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(SoulTheme.secondaryText)
            }
            .padding(16)
            .background(SoulCardBackground())
        }
        .buttonStyle(.plain)
    }

    private var menuCard: some View {
        VStack(spacing: 10) {
            SoulMenuRow(title: localizedText("成就徽章", "Achievements"), subtitle: localizedText("查看你的练习成果", "View your practice progress"), icon: "rosette")
            SoulMenuRow(title: localizedText("数据仓库", "Data Vault"), subtitle: localizedText("记录与关系数据总览", "Notes and relationship overview"), icon: "externaldrive.fill")
            SoulMenuRow(title: localizedText("隐私与安全", "Privacy & Security"), subtitle: localizedText("控制数据和权限", "Control data and permissions"), icon: "lock.shield.fill")
        }
        .padding(14)
        .background(SoulCardBackground())
    }
}

private struct SoulSettingsSheet: View {
    @AppStorage("soulMarkLanguage") private var language = "zh"
    @AppStorage("soulMarkGenderTheme") private var genderTheme = "male"
    @AppStorage("soulMarkAppearanceMode") private var appearanceMode = "auto"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(localizedText("语言", "Language")) {
                    Picker(localizedText("语言", "Language"), selection: $language) {
                        Text(localizedText("中文", "Chinese")).tag("zh")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.segmented)
                }

                Section(localizedText("性别", "Gender")) {
                    Picker(localizedText("性别", "Gender"), selection: $genderTheme) {
                        Text(localizedText("男", "Male")).tag("male")
                        Text(localizedText("女", "Female")).tag("female")
                    }
                    .pickerStyle(.segmented)
                }

                Section(localizedText("显示模式", "Display Mode")) {
                    Picker(localizedText("模式", "Mode"), selection: $appearanceMode) {
                        Text(localizedText("自动", "Auto")).tag("auto")
                        Text(localizedText("日间", "Day")).tag("day")
                        Text(localizedText("夜间", "Night")).tag("night")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .scrollContentBackground(.hidden)
            .background(SoulTheme.background)
            .navigationTitle(localizedText("个性化", "Personalization"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localizedText("完成", "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct SoulActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(SoulTheme.accent)
                    .frame(width: 38, height: 38)
                    .background(SoulTheme.accent.opacity(0.14), in: Circle())

                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(SoulTheme.primaryText)

                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SoulTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(SoulCardBackground())
        }
        .buttonStyle(.plain)
    }
}

private struct SoulStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(SoulTheme.accent)

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(SoulTheme.primaryText)

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SoulTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(SoulCardBackground())
    }
}

private struct SoulMenuRow: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(SoulTheme.accent)
                .frame(width: 38, height: 38)
                .background(SoulTheme.accent.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(SoulTheme.primaryText)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SoulTheme.secondaryText)
            }

            Spacer()
        }
        .padding(10)
    }
}

private struct SoulCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(SoulTheme.surface.opacity(0.92))
            .shadow(color: SoulTheme.isNight ? .black.opacity(0.30) : .black.opacity(0.06), radius: 14, x: 0, y: 8)
    }
}

enum RelationshipFilter: String, CaseIterable, Identifiable {
    case all
    case confidant
    case friend
    case family
    case collaborator
    case classmate
    case newContact
    case lightTie
    case distant

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: localizedText("全部", "All")
        case .confidant: localizedText("知己", "Close")
        case .friend: localizedText("好友", "Friend")
        case .family: localizedText("家庭", "Family")
        case .collaborator: localizedText("合作", "Work")
        case .classmate: localizedText("同路", "Peer")
        case .newContact: localizedText("新识", "New")
        case .lightTie: localizedText("浅交", "Light")
        case .distant: localizedText("远联", "Distant")
        }
    }

    var subtitle: String {
        switch self {
        case .all: localizedText("关系全景", "Full view")
        case .confidant: localizedText("深度联结", "Deep bond")
        case .friend: localizedText("舒适同频", "Easy rhythm")
        case .family: localizedText("亲密家人", "Close family")
        case .collaborator: localizedText("一起做事", "Do things together")
        case .classmate: localizedText("同频同行", "Shared path")
        case .newContact: localizedText("刚刚认识", "Recently met")
        case .lightTie: localizedText("轻度联系", "Light contact")
        case .distant: localizedText("很久未见", "Long time no see")
        }
    }

    var category: RelationshipCategory? {
        switch self {
        case .all: nil
        case .confidant: .confidant
        case .friend: .friend
        case .family: .family
        case .collaborator: .collaborator
        case .classmate: .classmate
        case .newContact: .newContact
        case .lightTie: .lightTie
        case .distant: .distant
        }
    }

    var tint: Color {
        category?.color ?? Color(red: 0.95, green: 0.58, blue: 0.70)
    }

    var systemImage: String {
        switch self {
        case .all: "circle.grid.2x2.fill"
        case .confidant: "heart.fill"
        case .friend: "sparkles"
        case .family: "house.fill"
        case .collaborator: "hammer.fill"
        case .classmate: "point.topleft.down.curvedto.point.bottomright.up"
        case .newContact: "person.badge.plus"
        case .lightTie: "paperplane.fill"
        case .distant: "moon.stars.fill"
        }
    }

    func filteredPeople(from people: [RelationshipPerson]) -> [RelationshipPerson] {
        guard let category else { return people }
        return people.filter { $0.category == category }
    }
}

enum RelationshipCategory: Identifiable, Equatable, Hashable {
    case confidant
    case friend
    case family
    case collaborator
    case classmate
    case newContact
    case lightTie
    case distant
    case custom(String)

    static let builtIns: [RelationshipCategory] = [
        .confidant,
        .friend,
        .family,
        .collaborator,
        .classmate,
        .newContact,
        .lightTie,
        .distant
    ]

    var id: String {
        switch self {
        case .confidant: "confidant"
        case .friend: "friend"
        case .family: "family"
        case .collaborator: "collaborator"
        case .classmate: "classmate"
        case .newContact: "new-contact"
        case .lightTie: "light-tie"
        case .distant: "distant"
        case .custom(let name): "custom-\(name)"
        }
    }

    var displayTitle: String {
        switch self {
        case .confidant: localizedText("知己", "Confidant")
        case .friend: localizedText("好友", "Friend")
        case .family: localizedText("家人", "Family")
        case .collaborator: localizedText("合作伙伴", "Collaborator")
        case .classmate: localizedText("同路人", "Peer")
        case .newContact: localizedText("新认识", "New Contact")
        case .lightTie: localizedText("浅交", "Light Tie")
        case .distant: localizedText("远联系", "Distant Tie")
        case .custom(let name): name
        }
    }

    var shortTitle: String {
        switch self {
        case .confidant: localizedText("知己", "Close")
        case .friend: localizedText("好友", "Friend")
        case .family: localizedText("家人", "Family")
        case .collaborator: localizedText("合作", "Work")
        case .classmate: localizedText("同路", "Peer")
        case .newContact: localizedText("新识", "New")
        case .lightTie: localizedText("浅交", "Light")
        case .distant: localizedText("远联", "Distant")
        case .custom(let name): name
        }
    }

    var color: Color {
        switch self {
        case .confidant: Color(red: 0.93, green: 0.38, blue: 0.62)
        case .friend: Color(red: 0.93, green: 0.58, blue: 0.12)
        case .family: Color(red: 0.18, green: 0.48, blue: 0.70)
        case .collaborator: Color(red: 0.50, green: 0.46, blue: 0.35)
        case .classmate: Color(red: 0.18, green: 0.34, blue: 0.28)
        case .newContact: Color(red: 0.73, green: 0.68, blue: 0.56)
        case .lightTie: Color(red: 0.73, green: 0.68, blue: 0.56)
        case .distant: Color(red: 0.78, green: 0.74, blue: 0.66)
        case .custom: Color(red: 0.54, green: 0.43, blue: 0.82)
        }
    }

    var isDashed: Bool {
        switch self {
        case .newContact, .lightTie, .distant:
            true
        default:
            false
        }
    }

    var systemImage: String {
        switch self {
        case .confidant: "heart.fill"
        case .friend: "sparkles"
        case .family: "house.fill"
        case .collaborator: "hammer.fill"
        case .classmate: "point.topleft.down.curvedto.point.bottomright.up"
        case .newContact: "person.badge.plus"
        case .lightTie: "paperplane.fill"
        case .distant: "moon.stars.fill"
        case .custom: "tag.fill"
        }
    }

    func filteredPeople(from people: [RelationshipPerson]) -> [RelationshipPerson] {
        people.filter { $0.category == self }
    }
}

struct RelationshipPerson: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let note: String
    var category: RelationshipCategory
    let strength: Double
    var position: CGPoint
    let avatarColors: [Color]
    let symbol: String
    let memory: String

    static func == (lhs: RelationshipPerson, rhs: RelationshipPerson) -> Bool {
        lhs.id == rhs.id
    }

    var displayNote: String {
        switch name {
        case "Torin": localizedText(note, "Long time no contact")
        case "Wren": localizedText(note, "Deep listener")
        case "Rhea": localizedText(note, "Warm and free")
        case "Jasper": localizedText(note, "Thought partner")
        case "Hugo": localizedText(note, "Someone from the past")
        case "Feel": localizedText(note, "Playful idea buddy")
        case "Zora": localizedText(note, "Light short-term companion")
        case "Lune": localizedText(note, "Brief encounter")
        case "Beau": localizedText(note, "Cared-for family member")
        case "Owen": localizedText(note, "Easygoing playmate")
        case "Silas": localizedText(note, "Inspires new thinking")
        case "Vivi": localizedText(note, "Shared memories")
        case "Kai": localizedText(note, "Inspiration observer")
        case "Marduk": localizedText(note, "Old acquaintance far away")
        default: note
        }
    }

    var displayMemory: String {
        switch name {
        case "Torin": localizedText(memory, "You met during school days and still think of them sometimes.")
        case "Wren": localizedText(memory, "A recent long talk helped you clarify your goals again.")
        case "Rhea": localizedText(memory, "They can make difficult things feel lighter.")
        case "Jasper": localizedText(memory, "You often exchange different perspectives on the same question.")
        case "Hugo": localizedText(memory, "You once completed an important milestone together.")
        case "Feel": localizedText(memory, "Good for playing, brainstorming, and creating joy together.")
        case "Zora": localizedText(memory, "Being together feels low-pressure, with occasional updates.")
        case "Lune": localizedText(memory, "The tie is still light, but carries a gentle family feeling.")
        case "Beau": localizedText(memory, "A steady presence in your family circle.")
        case "Owen": localizedText(memory, "You do not need to explain too much around him.")
        case "Silas": localizedText(memory, "He often brings you new paths of thinking.")
        case "Vivi": localizedText(memory, "Some memories remain, while interaction slowly becomes less frequent.")
        case "Kai": localizedText(memory, "You notice their updates, but rarely contact them directly.")
        case "Marduk": localizedText(memory, "The name is still on the map, but the relationship has become light.")
        default: memory
        }
    }
}

struct ScenarioParticipant: Identifiable, Equatable {
    let id: String
    let name: String
    let note: String
    let relationshipLabel: String
    let color: Color
    let symbol: String
    let isCustom: Bool

    static func from(_ person: RelationshipPerson) -> ScenarioParticipant {
        ScenarioParticipant(
            id: person.id.uuidString,
            name: person.name,
            note: person.displayNote,
            relationshipLabel: person.category.shortTitle,
            color: person.category.color,
            symbol: person.symbol,
            isCustom: false
        )
    }

    static func custom(name: String, note: String, relationshipLabel: String) -> ScenarioParticipant {
        ScenarioParticipant(
            id: "custom-\(UUID().uuidString)",
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? localizedText("自定义模拟对象", "Custom simulation partner") : note.trimmingCharacters(in: .whitespacesAndNewlines),
            relationshipLabel: relationshipLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? localizedText("自定义", "Custom") : relationshipLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            color: Color(red: 0.54, green: 0.43, blue: 0.82),
            symbol: "person.crop.circle.badge.questionmark",
            isCustom: true
        )
    }
}

struct ScenarioMode: Identifiable, Equatable {
    let id: String
    let title: String
    let guidance: String
    let systemImage: String
    let isCustom: Bool

    static let defaultModes: [ScenarioMode] = [
        ScenarioMode(id: "conflict", title: "冲突沟通", guidance: "先说事实，再说感受，最后提出你希望的改变。", systemImage: "bolt.heart.fill", isCustom: false),
        ScenarioMode(id: "apology", title: "道歉修复", guidance: "先承认影响，再解释原因，不急着为自己辩护。", systemImage: "heart.text.square.fill", isCustom: false),
        ScenarioMode(id: "boundary", title: "设立边界", guidance: "把边界说清楚，同时保留对对方的尊重。", systemImage: "hand.raised.fill", isCustom: false),
        ScenarioMode(id: "interview", title: "面试练习", guidance: "回答保持具体，用一个真实经历支撑观点。", systemImage: "person.text.rectangle.fill", isCustom: false)
    ]

    var displayTitle: String {
        switch id {
        case "conflict": localizedText(title, "Conflict Talk")
        case "apology": localizedText(title, "Repair Apology")
        case "boundary": localizedText(title, "Set Boundaries")
        case "interview": localizedText(title, "Interview Practice")
        default: title
        }
    }

    var displayGuidance: String {
        switch id {
        case "conflict": localizedText(guidance, "Start with facts, then feelings, then the change you hope for.")
        case "apology": localizedText(guidance, "Acknowledge the impact first, then explain without rushing to defend yourself.")
        case "boundary": localizedText(guidance, "Make the boundary clear while keeping respect for the other person.")
        case "interview": localizedText(guidance, "Keep your answer specific and support it with one real experience.")
        default: guidance
        }
    }
}

struct RecordingTimer: Equatable {
    private(set) var elapsedSeconds = 0
    private(set) var isRunning = false

    var displayText: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    mutating func start() {
        elapsedSeconds = 0
        isRunning = true
    }

    mutating func stop() {
        isRunning = false
    }

    mutating func cancel() {
        elapsedSeconds = 0
        isRunning = false
    }

    mutating func finish() -> Int {
        let submittedSeconds = elapsedSeconds
        elapsedSeconds = 0
        isRunning = false
        return submittedSeconds
    }

    mutating func tick() {
        guard isRunning else { return }
        elapsedSeconds += 1
    }
}

extension Array where Element == ScenarioMode {
    mutating func addCustomMode(title: String, guidance: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let trimmedGuidance = guidance.trimmingCharacters(in: .whitespacesAndNewlines)
        append(
            ScenarioMode(
                id: "custom-\(UUID().uuidString)",
                title: trimmedTitle,
                guidance: trimmedGuidance.isEmpty ? localizedText("按你设定的情景自由练习表达。", "Practice freely in the situation you created.") : trimmedGuidance,
                systemImage: "slider.horizontal.3",
                isCustom: true
            )
        )
    }
}

extension Array where Element == ScenarioParticipant {
    mutating func deleteCustomParticipant(_ id: ScenarioParticipant.ID) {
        removeAll { participant in
            participant.id == id && participant.isCustom
        }
    }
}

struct ScenarioMessage: Identifiable, Equatable {
    let id = UUID()
    let speaker: String
    let text: String
    let isUser: Bool

    static let sample: [ScenarioMessage] = [
        ScenarioMessage(speaker: "AI", text: localizedText("我会按真实语气回应，也会提醒你表达是否清楚。", "I will respond naturally and help you notice whether your message is clear."), isUser: false),
        ScenarioMessage(speaker: localizedText("你", "You"), text: localizedText("我想练习一次比较难开口的沟通。", "I want to practice a conversation that feels hard to start."), isUser: true)
    ]
}

struct ScenarioConversationSession: Identifiable, Equatable {
    let id = UUID()
    let participantID: ScenarioParticipant.ID?
    let participantName: String
    let date: Date
    let messages: [ScenarioMessage]

    var dateText: String {
        date.formatted(date: .numeric, time: .shortened)
    }

    func matches(_ query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return true }

        return participantName.localizedCaseInsensitiveContains(trimmedQuery) ||
        messages.contains { message in
            message.speaker.localizedCaseInsensitiveContains(trimmedQuery) ||
            message.text.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }
}

enum ReviewSource: String, CaseIterable, Identifiable {
    case scenario
    case wechat
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scenario: localizedText("情景模拟", "Simulation")
        case .wechat: localizedText("微信聊天", "WeChat Chat")
        case .manual: localizedText("手动记录", "Manual Note")
        }
    }

    var systemImage: String {
        switch self {
        case .scenario: "figure.wave"
        case .wechat: "message.fill"
        case .manual: "square.and.pencil"
        }
    }
}

struct ConversationReviewRecord: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let source: ReviewSource
    let date: Date
    let transcript: String
    let score: Int
    let reason: String
    let advice: String

    static func make(title: String, source: ReviewSource, transcript: String, date: Date = Date()) -> ConversationReviewRecord {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let clarityBonus = trimmedTranscript.contains("我") ? 8 : 0
        let actionBonus = trimmedTranscript.contains("下次") || trimmedTranscript.contains("希望") ? 8 : 0
        let lengthBonus = min(trimmedTranscript.count / 18, 16)
        let score = min(96, 64 + clarityBonus + actionBonus + lengthBonus)

        return ConversationReviewRecord(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? localizedText("未命名复盘", "Untitled Review") : title.trimmingCharacters(in: .whitespacesAndNewlines),
            source: source,
            date: date,
            transcript: trimmedTranscript,
            score: score,
            reason: localizedText("分数主要来自表达清晰度、是否说明感受、是否提出下一步行动。", "The score mainly reflects clarity, whether feelings were explained, and whether a next step was proposed."),
            advice: score >= 85 ? localizedText("整体表达较完整，可以继续练习更自然的语气。", "The message is mostly complete. Keep practicing a more natural tone.") : localizedText("建议补充你的感受和具体需求，让对方更容易回应。", "Add your feelings and specific needs so the other person can respond more easily.")
        )
    }

    func matches(source selectedSource: ReviewSource?, query: String) -> Bool {
        if let selectedSource, source != selectedSource {
            return false
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return true }

        return title.localizedCaseInsensitiveContains(trimmedQuery) ||
        transcript.localizedCaseInsensitiveContains(trimmedQuery) ||
        source.title.localizedCaseInsensitiveContains(trimmedQuery)
    }
}

enum RelationshipSampleData {
    static let people: [RelationshipPerson] = [
        .init(name: "Torin", note: "很久未曾联系", category: .distant, strength: 0.28, position: CGPoint(x: 0.16, y: 0.16), avatarColors: [.mint.opacity(0.35), .orange.opacity(0.28)], symbol: "leaf.fill", memory: "学生时期认识，偶尔想起对方。"),
        .init(name: "Wren", note: "能够深度倾诉", category: .confidant, strength: 0.88, position: CGPoint(x: 0.24, y: 0.34), avatarColors: [.cyan, .orange], symbol: "sunset.fill", memory: "最近一次长聊让你重新梳理了自己的目标。"),
        .init(name: "Rhea", note: "热烈且自由", category: .confidant, strength: 0.82, position: CGPoint(x: 0.78, y: 0.23), avatarColors: [.orange, .pink], symbol: "figure.run", memory: "总能把低落的事情讲得轻一点。"),
        .init(name: "Jasper", note: "思想交流伙伴", category: .friend, strength: 0.64, position: CGPoint(x: 0.80, y: 0.38), avatarColors: [.blue.opacity(0.6), .green.opacity(0.45)], symbol: "book.closed.fill", memory: "你们常在一个问题上交换不同角度。"),
        .init(name: "Hugo", note: "停留在过去的人", category: .collaborator, strength: 0.38, position: CGPoint(x: 0.82, y: 0.51), avatarColors: [.brown, .teal.opacity(0.4)], symbol: "moon.fill", memory: "曾经一起完成过一个重要节点。"),
        .init(name: "Feel", note: "脑洞丰富的玩伴", category: .friend, strength: 0.72, position: CGPoint(x: 0.76, y: 0.64), avatarColors: [.yellow, .red.opacity(0.65)], symbol: "sparkles", memory: "适合一起玩、发散想法、制造快乐。"),
        .init(name: "Zora", note: "轻松短暂的相伴", category: .classmate, strength: 0.48, position: CGPoint(x: 0.64, y: 0.74), avatarColors: [.blue, .yellow.opacity(0.7)], symbol: "face.smiling", memory: "相处没有压力，偶尔同步近况。"),
        .init(name: "Lune", note: "一面之缘", category: .family, strength: 0.42, position: CGPoint(x: 0.50, y: 0.82), avatarColors: [.yellow, .green.opacity(0.5)], symbol: "heart.circle.fill", memory: "关系还浅，但带着温柔的家庭感。"),
        .init(name: "Beau", note: "被照顾的小家人", category: .family, strength: 0.58, position: CGPoint(x: 0.67, y: 0.90), avatarColors: [.orange.opacity(0.35), .white], symbol: "house.fill", memory: "家庭里的安定存在。"),
        .init(name: "Owen", note: "轻松自在的玩伴", category: .friend, strength: 0.78, position: CGPoint(x: 0.35, y: 0.78), avatarColors: [.red, .orange.opacity(0.6)], symbol: "gamecontroller.fill", memory: "和他在一起时不用解释太多。"),
        .init(name: "Silas", note: "予思路启发", category: .classmate, strength: 0.52, position: CGPoint(x: 0.20, y: 0.66), avatarColors: [.pink.opacity(0.75), .yellow.opacity(0.55)], symbol: "pencil.and.outline", memory: "他常带来新的思考路径。"),
        .init(name: "Vivi", note: "共同回忆", category: .lightTie, strength: 0.34, position: CGPoint(x: 0.16, y: 0.51), avatarColors: [.green, .blue.opacity(0.45)], symbol: "mountain.2.fill", memory: "一些记忆还在，但互动慢慢变少。"),
        .init(name: "Kai", note: "灵感观察者", category: .lightTie, strength: 0.30, position: CGPoint(x: 0.70, y: 0.14), avatarColors: [.gray.opacity(0.45), .yellow.opacity(0.35)], symbol: "eye.fill", memory: "你会留意他的动态，但不常直接联系。"),
        .init(name: "Marduk", note: "远方的旧识", category: .distant, strength: 0.24, position: CGPoint(x: 0.48, y: 0.10), avatarColors: [.purple.opacity(0.25), .white], symbol: "circle.dashed", memory: "名字还在图谱里，关系已经很轻。")
    ]
}

extension Array where Element == RelationshipPerson {
    func scenarioParticipants(limit: Int? = nil) -> [ScenarioParticipant] {
        let sortedPeople = sorted { left, right in
            if left.strength != right.strength {
                return left.strength > right.strength
            }

            return left.name < right.name
        }

        if let limit {
            return sortedPeople.prefix(limit).map(ScenarioParticipant.from)
        }

        return sortedPeople.map(ScenarioParticipant.from)
    }

    mutating func updateRelationship(for id: RelationshipPerson.ID, to category: RelationshipCategory) {
        guard let index = firstIndex(where: { $0.id == id }) else { return }
        self[index].category = category
    }

    mutating func deleteRelationship(_ category: RelationshipCategory) {
        removeAll { $0.category == category }
    }

    mutating func deletePerson(_ id: RelationshipPerson.ID) {
        removeAll { $0.id == id }
    }

    mutating func updatePosition(for id: RelationshipPerson.ID, to position: CGPoint) {
        guard let index = firstIndex(where: { $0.id == id }) else { return }
        self[index].position = CGPoint(
            x: Swift.min(Swift.max(position.x, 0.10), 0.90),
            y: Swift.min(Swift.max(position.y, 0.08), 0.92)
        )
    }

    mutating func organizePositions() {
        let orderedIndices = indices.sorted { left, right in
            let leftRank = categoryRank(self[left].category)
            let rightRank = categoryRank(self[right].category)

            if leftRank != rightRank {
                return leftRank < rightRank
            }

            if self[left].strength != self[right].strength {
                return self[left].strength > self[right].strength
            }

            return self[left].name < self[right].name
        }

        guard !orderedIndices.isEmpty else { return }

        for (order, index) in orderedIndices.enumerated() {
            let angle = (-Double.pi / 2) + (Double(order) / Double(orderedIndices.count)) * Double.pi * 2
            let ringOffset = order.isMultiple(of: 2) ? 0.00 : 0.05
            let radiusX = 0.33 + ringOffset
            let radiusY = 0.37 + ringOffset
            self[index].position = CGPoint(
                x: Swift.min(Swift.max(0.50 + cos(angle) * radiusX, 0.12), 0.88),
                y: Swift.min(Swift.max(0.51 + sin(angle) * radiusY, 0.12), 0.90)
            )
        }
    }

    mutating func addPerson(name: String, note: String, category: RelationshipCategory) {
        let nextIndex = count
        let angle = (Double(nextIndex) * 0.73).truncatingRemainder(dividingBy: Double.pi * 2)
        let radiusX = 0.34
        let radiusY = 0.39
        let position = CGPoint(
            x: Swift.min(Swift.max(0.50 + cos(angle) * radiusX, 0.12), 0.88),
            y: Swift.min(Swift.max(0.50 + sin(angle) * radiusY, 0.10), 0.92)
        )

        append(
            RelationshipPerson(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? localizedText("新的关系", "New relationship") : note.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                strength: 0.46,
                position: position,
                avatarColors: [category.color.opacity(0.86), Color.white.opacity(0.52)],
                symbol: "person.fill",
                memory: localizedText("这是你刚刚添加到关系图谱中的人。", "This is someone you just added to the relationship map.")
            )
        )
    }

    private func categoryRank(_ category: RelationshipCategory) -> Int {
        if let index = RelationshipCategory.builtIns.firstIndex(of: category) {
            return index
        }

        return RelationshipCategory.builtIns.count
    }
}

private struct RelationshipHeader: View {
    let onBackHome: () -> Void
    let onAddPerson: () -> Void
    let onOpenScenario: () -> Void

    var body: some View {
        HStack {
            Button(action: onBackHome) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(localizedText("关系图谱", "Relationship Map"))
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(primaryTextColor)

            Spacer()

            HStack(spacing: 4) {
                Button(action: onOpenScenario) {
                    Image(systemName: "figure.wave")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color(red: 0.90, green: 0.40, blue: 0.58))
                        .frame(width: 38, height: 44)
                }

                Button(action: onAddPerson) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color(red: 0.30, green: 0.54, blue: 0.78))
                        .frame(width: 38, height: 44)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

private struct PlaceholderPage: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        ZStack {
            RelationshipBackground()

            VStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(Color(red: 0.90, green: 0.40, blue: 0.58))
                    .frame(width: 86, height: 86)
                    .background(Color.white.opacity(0.68), in: Circle())

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

private struct ConversationReviewPage: View {
    @State private var records: [ConversationReviewRecord] = [
        .make(
            title: localizedText("和 Wren 的情景模拟", "Simulation with Wren"),
            source: .scenario,
            transcript: localizedText("我想告诉你，我最近有点压力。希望下次我们可以提前说清楚时间，这样我会更安心。", "I want to tell you that I have been under some pressure lately. I hope next time we can clarify the timing earlier so I can feel more at ease.")
        ),
        .make(
            title: localizedText("微信聊天复盘", "WeChat Review"),
            source: .wechat,
            transcript: localizedText("我昨天没有及时回复你，是因为我在赶项目。下次我会提前告诉你，不让你一直等。", "I did not reply in time yesterday because I was rushing a project. Next time I will tell you earlier so you are not left waiting.")
        )
    ]
    @State private var isAddingRecord = false
    @State private var selectedSource: ReviewSource?
    @State private var searchText = ""

    private var filteredRecords: [ConversationReviewRecord] {
        records.filter { $0.matches(source: selectedSource, query: searchText) }
    }

    private var averageScore: Int {
        guard !filteredRecords.isEmpty else { return 0 }
        return filteredRecords.map(\.score).reduce(0, +) / filteredRecords.count
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            RelationshipBackground()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizedText("复盘记录", "Review Records"))
                            .font(.system(size: 27, weight: .bold))
                            .foregroundStyle(primaryTextColor)

                        Text(localizedText("把情景模拟、微信聊天或手动记录放进来复盘", "Add simulations, WeChat chats, or manual notes for review"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(secondaryTextColor)
                    }

                    Spacer()

                    Button {
                        isAddingRecord = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(width: 42, height: 42)
                            .background(Color(red: 0.30, green: 0.54, blue: 0.78), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 12)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            ReviewMetricCard(title: localizedText("平均分", "Average"), value: "\(averageScore)", systemImage: "chart.line.uptrend.xyaxis")
                            ReviewMetricCard(title: localizedText("筛选结果", "Results"), value: "\(filteredRecords.count)", systemImage: "text.bubble.fill")
                        }

                        ReviewFilterPanel(
                            selectedSource: $selectedSource,
                            searchText: $searchText
                        )

                        if filteredRecords.isEmpty {
                            EmptyReviewState()
                        }

                        ForEach(filteredRecords) { record in
                            ConversationReviewCard(
                                record: record,
                                onDelete: {
                                    records.removeAll { $0.id == record.id }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 116)
                }
            }
        }
        .sheet(isPresented: $isAddingRecord) {
            AddReviewRecordSheet { title, source, transcript in
                records.insert(
                    ConversationReviewRecord.make(
                        title: title,
                        source: source,
                        transcript: transcript
                    ),
                    at: 0
                )
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct ReviewMetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.30, green: 0.54, blue: 0.78))
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.74), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(primaryTextColor)

                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(secondaryTextColor)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ReviewFilterPanel: View {
    @Binding var selectedSource: ReviewSource?
    @Binding var searchText: String

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ReviewSourceFilterButton(
                        title: localizedText("全部", "All"),
                        systemImage: "square.grid.2x2.fill",
                        isSelected: selectedSource == nil
                    ) {
                        selectedSource = nil
                    }

                    ForEach(ReviewSource.allCases) { source in
                        ReviewSourceFilterButton(
                            title: source.title,
                            systemImage: source.systemImage,
                            isSelected: selectedSource == source
                        ) {
                            selectedSource = source
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(secondaryTextColor)

                TextField(localizedText("搜索对象、标题或聊天内容", "Search person, title, or chat content"), text: $searchText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(primaryTextColor)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(12)
        .background(Color.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ReviewSourceFilterButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isSelected ? Color.white : primaryTextColor)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(
                    isSelected
                    ? Color(red: 0.30, green: 0.54, blue: 0.78)
                    : Color.white.opacity(0.74),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyReviewState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(secondaryTextColor)

            Text(localizedText("没有找到相关复盘", "No matching reviews"))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(primaryTextColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ConversationReviewCard: View {
    let record: ConversationReviewRecord
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: record.source.systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 38, height: 38)
                    .background(sourceColor, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(2)

                    Text("\(record.source.title) · \(record.date.formatted(date: .numeric, time: .shortened))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(secondaryTextColor)
                }

                Spacer()

                HStack(spacing: 8) {
                    VStack(spacing: 0) {
                        Text("\(record.score)")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(primaryTextColor)

                        Text(localizedText("分", "pts"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(secondaryTextColor)
                    }
                    .frame(width: 54, height: 54)
                    .background(scoreBackground, in: Circle())

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 0.62, green: 0.12, blue: 0.18))
                            .frame(width: 32, height: 32)
                            .background(Color(red: 0.98, green: 0.82, blue: 0.82), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(record.transcript)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(primaryTextColor)
                .lineSpacing(3)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 10))

            ReviewInsightRow(title: localizedText("评分原因", "Score Reason"), text: record.reason, systemImage: "checkmark.seal.fill")
            ReviewInsightRow(title: localizedText("复盘建议", "Review Advice"), text: record.advice, systemImage: "lightbulb.fill")
        }
        .padding(15)
        .background(Color(red: 1.00, green: 0.96, blue: 0.91), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(red: 0.88, green: 0.72, blue: 0.84).opacity(0.72), lineWidth: 1)
        )
    }

    private var sourceColor: Color {
        switch record.source {
        case .scenario: Color(red: 0.90, green: 0.40, blue: 0.58)
        case .wechat: Color(red: 0.22, green: 0.68, blue: 0.35)
        case .manual: Color(red: 0.30, green: 0.54, blue: 0.78)
        }
    }

    private var scoreBackground: Color {
        record.score >= 85 ? Color(red: 0.70, green: 0.88, blue: 0.55) : Color(red: 0.98, green: 0.76, blue: 0.38)
    }
}

private struct ReviewInsightRow: View {
    let title: String
    let text: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(red: 0.94, green: 0.59, blue: 0.12))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(primaryTextColor)

                Text(text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(secondaryTextColor)
                    .lineSpacing(2)
            }
        }
    }
}

private struct AddReviewRecordSheet: View {
    let onAdd: (String, ReviewSource, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var source: ReviewSource = .scenario
    @State private var transcript = ""

    private var canSubmit: Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizedText("来源", "Source"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(secondaryTextColor)

                    HStack(spacing: 8) {
                        ForEach(ReviewSource.allCases) { item in
                            Button {
                                source = item
                            } label: {
                                Label(item.title, systemImage: item.systemImage)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(source == item ? Color.white : primaryTextColor)
                                    .padding(.horizontal, 10)
                                    .frame(height: 34)
                                    .background(
                                        source == item
                                        ? Color(red: 0.30, green: 0.54, blue: 0.78)
                                        : Color.white.opacity(0.72),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(localizedText("标题", "Title"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(secondaryTextColor)

                    TextField(localizedText("例如：和朋友的误会复盘", "Example: A misunderstanding with a friend"), text: $title)
                        .font(.system(size: 15, weight: .semibold))
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(localizedText("聊天记录", "Chat Record"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(secondaryTextColor)

                    TextEditor(text: $transcript)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 210)
                        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(alignment: .topLeading) {
                            if transcript.isEmpty {
                                Text(localizedText("粘贴情景模拟、微信或你手动整理的聊天内容", "Paste a simulation, WeChat chat, or manually organized chat record"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.56, green: 0.56, blue: 0.56))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 18)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Button {
                    onAdd(title, source, transcript)
                    dismiss()
                } label: {
                    Label(localizedText("生成复盘", "Generate Review"), systemImage: "sparkles")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            canSubmit
                            ? Color(red: 0.90, green: 0.40, blue: 0.58)
                            : Color.gray.opacity(0.35),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                }
                .disabled(!canSubmit)
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Color(red: 0.99, green: 0.96, blue: 0.93))
            .navigationTitle(localizedText("添加复盘", "Add Review"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct AppTabBar: View {
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
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(sections, id: \.title) { section in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        selectedSection = section
                    }
                } label: {
                    if section == .scenarioSimulation {
                        VStack(spacing: 2) {
                            ZStack {
                                Circle()
                                    .fill(
                                        selectedSection == section
                                        ? accentColor
                                        : inactiveBubbleColor
                                    )
                                    .frame(width: 62, height: 62)

                                Image(systemName: section.systemImage)
                                    .font(.system(size: 29, weight: .bold))
                                    .foregroundStyle(Color.white)
                            }

                            Text(section.title)
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundStyle(primaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .offset(y: -14)
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: section.systemImage)
                                .font(.system(size: 22, weight: .semibold))

                            Text(section.title)
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(selectedSection == section ? primaryText : secondaryText)
                        .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .frame(height: 86)
        .background(barBackground)
    }

    private var isNight: Bool {
        isSoulNightMode()
    }

    private var accentColor: Color {
        if genderTheme == "male" {
            return isNight ? Color(red: 0.30, green: 0.58, blue: 0.95) : Color(red: 0.22, green: 0.48, blue: 0.82)
        }

        return isNight ? Color(red: 0.95, green: 0.36, blue: 0.62) : Color(red: 0.92, green: 0.42, blue: 0.62)
    }

    private var primaryText: Color {
        isNight ? Color(red: 0.93, green: 0.95, blue: 0.98) : primaryTextColor
    }

    private var secondaryText: Color {
        isNight ? Color(red: 0.62, green: 0.65, blue: 0.70) : Color(red: 0.58, green: 0.58, blue: 0.58)
    }

    private var inactiveBubbleColor: Color {
        isNight ? Color(red: 0.24, green: 0.25, blue: 0.28) : Color(red: 0.86, green: 0.84, blue: 0.82)
    }

    private var barBackground: Color {
        if isNight {
            return genderTheme == "male" ? Color(red: 0.09, green: 0.11, blue: 0.14) : Color(red: 0.13, green: 0.10, blue: 0.13)
        }

        return genderTheme == "male" ? Color(red: 0.90, green: 0.93, blue: 0.97) : Color(red: 0.96, green: 0.93, blue: 0.95)
    }
}

private struct ScenarioSimulationView: View {
    @State private var participants: [ScenarioParticipant]
    @State private var selectedParticipantID: ScenarioParticipant.ID?
    @State private var isAddingParticipant = false
    @State private var isAddingMode = false
    @State private var modes = ScenarioMode.defaultModes
    @State private var selectedModeID = ScenarioMode.defaultModes[0].id
    @State private var recordingTimer = RecordingTimer()
    @State private var draftMessage = ""
    @State private var conversation = ScenarioMessage.sample
    @State private var conversationHistory: [ScenarioConversationSession] = []
    @State private var isShowingHistory = false
    @State private var isShowingParticipantPicker = false
    @State private var conversationScrollTarget = UUID()

    init(relationshipPeople: [RelationshipPerson], focusedPersonID: RelationshipPerson.ID? = nil) {
        let initialParticipants = relationshipPeople.scenarioParticipants()
        _participants = State(initialValue: initialParticipants)
        let focusedID = focusedPersonID?.uuidString
        let selectedID = initialParticipants.contains { $0.id == focusedID } ? focusedID : initialParticipants.first?.id
        _selectedParticipantID = State(initialValue: selectedID)
    }

    private var selectedParticipant: ScenarioParticipant {
        participants.first { $0.id == selectedParticipantID } ?? participants[0]
    }

    private var selectedMode: ScenarioMode {
        modes.first { $0.id == selectedModeID } ?? modes[0]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(red: 0.99, green: 0.97, blue: 0.92)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScenarioHeader(
                    onShowHistory: {
                        isShowingHistory = true
                    },
                    onNewHeartTalk: startHeartTalk,
                    onNewConversation: startNewConversation,
                    onChangeParticipant: {
                        isShowingParticipantPicker = true
                    },
                    onAddMode: {
                        isAddingMode = true
                    }
                )

                ZStack(alignment: .topTrailing) {
                    ScenarioStage(participant: selectedParticipant)
                        .padding(.top, 4)

                    Button {
                        isShowingParticipantPicker = true
                    } label: {
                        HStack(spacing: 7) {
                            ScenarioAvatar(participant: selectedParticipant, size: 30)

                            VStack(alignment: .leading, spacing: 0) {
                                Text(selectedParticipant.name)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(primaryTextColor)
                                    .lineLimit(1)

                                Text(localizedText("对象", "Partner"))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(secondaryTextColor)
                            }

                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(secondaryTextColor)
                        }
                        .padding(.horizontal, 9)
                        .frame(height: 42)
                        .background(Color.white.opacity(0.78), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    .padding(.trailing, 18)
                }

                ScenarioControlCard(
                    participant: selectedParticipant,
                    selectedModeID: $selectedModeID,
                    modes: modes,
                    messages: conversation,
                    scrollTarget: conversationScrollTarget,
                    draftMessage: $draftMessage,
                    recordingTimer: $recordingTimer,
                    onAddMode: {
                        isAddingMode = true
                    },
                    onNewConversation: startNewConversation,
                    onCancelRecording: {
                        recordingTimer.cancel()
                    },
                    onConfirmRecording: confirmRecording,
                    onSend: sendMessage
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 88)
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            recordingTimer.tick()
        }
        .sheet(isPresented: $isAddingParticipant) {
            AddScenarioParticipantSheet { name, note, relationshipLabel in
                let participant = ScenarioParticipant.custom(
                    name: name,
                    note: note,
                    relationshipLabel: relationshipLabel
                )
                participants.append(participant)
                switchToParticipant(participant)
            }
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isAddingMode) {
            AddScenarioModeSheet { title, guidance in
                modes.addCustomMode(title: title, guidance: guidance)
                selectedModeID = modes.last?.id ?? selectedModeID
            }
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingParticipantPicker) {
            ScenarioParticipantPickerSheet(
                participants: participants,
                selectedID: selectedParticipantID,
                onSelect: { participant in
                    switchToParticipant(participant)
                    isShowingParticipantPicker = false
                },
                onAdd: {
                    isShowingParticipantPicker = false
                    isAddingParticipant = true
                },
                onDeleteCustom: deleteCustomParticipant
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingHistory) {
            ScenarioHistorySheet(
                sessions: conversationSessions,
                currentParticipantName: selectedParticipant.name,
                onContinue: continueConversation,
                onDelete: deleteConversationSession
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var conversationSessions: [ScenarioConversationSession] {
        [
            ScenarioConversationSession(
                participantID: selectedParticipantID,
                participantName: selectedParticipant.name,
                date: Date(),
                messages: conversation
            )
        ] + conversationHistory
    }

    private func sendMessage() {
        let text = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        conversation.append(ScenarioMessage(speaker: localizedText("你", "You"), text: text, isUser: true))
        conversation.append(
            ScenarioMessage(
                speaker: selectedParticipant.name,
                text: localizedText("我听到了。你希望我接下来怎么回应这件事？", "I hear you. How would you like me to respond to this next?"),
                isUser: false
            )
        )
        draftMessage = ""
        conversationScrollTarget = UUID()
    }

    private func confirmRecording(seconds: Int) {
        guard seconds > 0 else { return }

        conversation.append(
            ScenarioMessage(
                speaker: localizedText("你", "You"),
                text: localizedText("已提交一段 \(seconds) 秒的语音给 AI。", "Submitted a \(seconds)-second voice message to AI."),
                isUser: true
            )
        )
        conversationScrollTarget = UUID()
    }

    private func deleteCustomParticipant(_ participant: ScenarioParticipant) {
        participants.deleteCustomParticipant(participant.id)

        if selectedParticipantID == participant.id {
            selectedParticipantID = participants.first?.id
            resetConversation()
        }
    }

    private func deleteConversationSession(_ session: ScenarioConversationSession) {
        let oldCount = conversationHistory.count
        conversationHistory.removeAll { $0.id == session.id }

        if oldCount == conversationHistory.count,
           session.participantName == selectedParticipant.name,
           session.messages == conversation {
            resetConversation()
        }
    }

    private func switchToParticipant(_ participant: ScenarioParticipant) {
        guard selectedParticipantID != participant.id else { return }
        saveCurrentConversationIfNeeded()
        selectedParticipantID = participant.id
        resetConversation()
    }

    private func startNewConversation() {
        saveCurrentConversationIfNeeded()
        resetConversation()
    }

    private func startHeartTalk() {
        saveCurrentConversationIfNeeded()
        selectedModeID = modes.first { $0.id == "boundary" }?.id ?? selectedModeID
        conversation = [
            ScenarioMessage(speaker: "AI", text: localizedText("心对话已开启。你可以先说最真实的感受，不需要一次说完。", "Heart talk is open. Start with the most honest feeling; you do not need to say everything at once."), isUser: false)
        ]
        draftMessage = ""
        recordingTimer.cancel()
        conversationScrollTarget = UUID()
    }

    private func continueConversation(_ session: ScenarioConversationSession) {
        saveCurrentConversationIfNeeded()
        if let participantID = session.participantID,
           participants.contains(where: { $0.id == participantID }) {
            selectedParticipantID = participantID
        } else if let participant = participants.first(where: { $0.name == session.participantName }) {
            selectedParticipantID = participant.id
        }
        conversation = session.messages
        draftMessage = ""
        recordingTimer.cancel()
        conversationHistory.removeAll { $0.id == session.id }
        isShowingHistory = false
        conversationScrollTarget = UUID()
    }

    private func resetConversation() {
        conversation = []
        draftMessage = ""
        recordingTimer.cancel()
        conversationScrollTarget = UUID()
    }

    private func saveCurrentConversationIfNeeded() {
        guard !conversation.isEmpty else { return }

        conversationHistory.insert(
            ScenarioConversationSession(
                participantID: selectedParticipantID,
                participantName: selectedParticipant.name,
                date: Date(),
                messages: conversation
            ),
            at: 0
        )
    }
}

private struct ScenarioHeader: View {
    let onShowHistory: () -> Void
    let onNewHeartTalk: () -> Void
    let onNewConversation: () -> Void
    let onChangeParticipant: () -> Void
    let onAddMode: () -> Void

    var body: some View {
        HStack {
            Button(action: onShowHistory) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(red: 0.30, green: 0.54, blue: 0.78))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(localizedText("情景模拟", "Simulation"))
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(primaryTextColor)

            Spacer()

            Menu {
                Button(action: onNewHeartTalk) {
                    Label(localizedText("心情倾诉", "Heart Talk"), systemImage: "heart.text.square.fill")
                }

                Button(action: onNewConversation) {
                    Label(localizedText("新对话", "New Chat"), systemImage: "plus.message.fill")
                }

                Button(action: onChangeParticipant) {
                    Label(localizedText("切换对象", "Switch Partner"), systemImage: "person.2.fill")
                }

                Button(action: onAddMode) {
                    Label(localizedText("自定义模式", "Custom Mode"), systemImage: "slider.horizontal.3")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(red: 0.58, green: 0.55, blue: 0.49))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .frame(height: 54)
    }
}

private struct ScenarioStage: View {
    let participant: ScenarioParticipant

    var body: some View {
        VStack(spacing: 8) {
            ScenarioCharacterIllustration()
                .frame(maxWidth: .infinity)
                .frame(height: 172)

            Text(localizedText("正在模拟与 \(participant.name) 的真实交流", "Simulating a realistic conversation with \(participant.name)"))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(secondaryTextColor)
                .padding(.horizontal, 14)
                .frame(height: 28)
                .background(Color.white.opacity(0.48), in: Capsule())
        }
    }
}

private struct ScenarioCharacterIllustration: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color(red: 0.75, green: 0.70, blue: 0.63).opacity(0.30))
                .frame(width: 230, height: 24)
                .offset(y: 128)

            Path { path in
                path.move(to: CGPoint(x: 180, y: 154))
                path.addLine(to: CGPoint(x: 180, y: 246))
                path.move(to: CGPoint(x: 180, y: 246))
                path.addLine(to: CGPoint(x: 130, y: 330))
                path.move(to: CGPoint(x: 180, y: 246))
                path.addLine(to: CGPoint(x: 232, y: 330))
                path.move(to: CGPoint(x: 130, y: 330))
                path.addLine(to: CGPoint(x: 92, y: 330))
                path.move(to: CGPoint(x: 232, y: 330))
                path.addLine(to: CGPoint(x: 270, y: 330))
                path.move(to: CGPoint(x: 180, y: 184))
                path.addLine(to: CGPoint(x: 110, y: 146))
                path.addLine(to: CGPoint(x: 78, y: 92))
                path.move(to: CGPoint(x: 180, y: 184))
                path.addLine(to: CGPoint(x: 248, y: 222))
                path.addLine(to: CGPoint(x: 278, y: 260))
            }
            .stroke(Color.black, style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))

            Circle()
                .fill(Color.clear)
                .frame(width: 118, height: 118)
                .overlay(Circle().stroke(Color.black, lineWidth: 14))
                .position(x: 180, y: 96)

            Capsule()
                .fill(Color.black)
                .frame(width: 18, height: 30)
                .position(x: 154, y: 94)

            Capsule()
                .fill(Color.black)
                .frame(width: 18, height: 30)
                .position(x: 206, y: 94)

            Circle()
                .fill(Color.black)
                .frame(width: 48, height: 48)
                .position(x: 64, y: 72)

            Circle()
                .fill(Color.black)
                .frame(width: 44, height: 44)
                .position(x: 292, y: 270)
        }
        .frame(width: 360, height: 350)
        .scaleEffect(0.50)
        .frame(width: 230, height: 172)
    }
}

private struct ScenarioParticipantRail: View {
    let participants: [ScenarioParticipant]
    let selectedID: ScenarioParticipant.ID?
    let onSelect: (ScenarioParticipant) -> Void
    let onAdd: () -> Void
    let onDeleteCustom: (ScenarioParticipant) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(participants) { participant in
                    ZStack(alignment: .topTrailing) {
                        Button {
                            onSelect(participant)
                        } label: {
                            VStack(spacing: 5) {
                                ScenarioAvatar(participant: participant, size: 44)

                                Text(participant.name)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(primaryTextColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.80)
                            }
                            .frame(width: 68, height: 64)
                            .background(
                                selectedID == participant.id
                                ? Color(red: 1.00, green: 0.94, blue: 0.89)
                                : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedID == participant.id ? participant.color.opacity(0.56) : .clear, lineWidth: 1.4)
                            )
                        }
                        .buttonStyle(.plain)

                        if participant.isCustom {
                            Button {
                                onDeleteCustom(participant)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(Color(red: 0.70, green: 0.18, blue: 0.22), Color.white)
                                    .frame(width: 24, height: 24)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .offset(x: 2, y: -4)
                        }
                    }
                }

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color(red: 0.48, green: 0.48, blue: 0.48))
                        .frame(width: 52, height: 52)
                        .background(Color(red: 0.90, green: 0.90, blue: 0.88), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 76, height: 236)
    }
}

private struct ScenarioParticipantPickerSheet: View {
    let participants: [ScenarioParticipant]
    let selectedID: ScenarioParticipant.ID?
    let onSelect: (ScenarioParticipant) -> Void
    let onAdd: () -> Void
    let onDeleteCustom: (ScenarioParticipant) -> Void

    private var groupedParticipants: [(String, [ScenarioParticipant])] {
        Dictionary(grouping: participants, by: \.relationshipLabel)
            .map { key, value in (key, value.sorted { $0.name < $1.name }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(groupedParticipants, id: \.0) { groupName, people in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(groupName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(secondaryTextColor)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 10)], spacing: 10) {
                                ForEach(people) { participant in
                                    ZStack(alignment: .topTrailing) {
                                        Button {
                                            onSelect(participant)
                                        } label: {
                                            VStack(spacing: 7) {
                                                ScenarioAvatar(participant: participant, size: 48)

                                                Text(participant.name)
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(primaryTextColor)
                                                    .lineLimit(1)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 88)
                                            .background(
                                                selectedID == participant.id
                                                ? participant.color.opacity(0.18)
                                                : Color.white.opacity(0.64),
                                                in: RoundedRectangle(cornerRadius: 10)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(selectedID == participant.id ? participant.color.opacity(0.52) : Color.clear, lineWidth: 1.3)
                                            )
                                        }
                                        .buttonStyle(.plain)

                                        if participant.isCustom {
                                            Button {
                                                onDeleteCustom(participant)
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundStyle(Color(red: 0.70, green: 0.18, blue: 0.22), Color.white)
                                                    .frame(width: 28, height: 28)
                                            }
                                            .buttonStyle(.plain)
                                            .offset(x: 4, y: -6)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Button(action: onAdd) {
                        Label(localizedText("创建自定义对象", "Create Custom Partner"), systemImage: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(primaryTextColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(red: 0.96, green: 0.64, blue: 0.76).opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(Color(red: 0.99, green: 0.96, blue: 0.93))
            .navigationTitle(localizedText("选择交流对象", "Choose Conversation Partner"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ScenarioHistorySheet: View {
    let sessions: [ScenarioConversationSession]
    let currentParticipantName: String
    let onContinue: (ScenarioConversationSession) -> Void
    let onDelete: (ScenarioConversationSession) -> Void

    @State private var searchText = ""

    private var filteredSessions: [ScenarioConversationSession] {
        sessions.filter { $0.matches(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(secondaryTextColor)

                        TextField(localizedText("搜索用户或聊天关键词", "Search user or chat keywords"), text: $searchText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))

                    if filteredSessions.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "text.magnifyingglass")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(secondaryTextColor)

                            Text(localizedText("没有找到相关对话", "No matching conversations"))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(primaryTextColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 34)
                    }

                    ForEach(filteredSessions) { session in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.participantName)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(primaryTextColor)

                                    Text(session.dateText)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(secondaryTextColor)
                                }

                                Spacer()

                                HStack(spacing: 6) {
                                    Text(session.participantName == currentParticipantName ? localizedText("当前", "Current") : localizedText("历史", "History"))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color(red: 0.30, green: 0.54, blue: 0.78))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                        .background(Color(red: 0.30, green: 0.54, blue: 0.78).opacity(0.12), in: Capsule())

                                    Button(role: .destructive) {
                                        onDelete(session)
                                    } label: {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color(red: 0.62, green: 0.12, blue: 0.18))
                                            .frame(width: 28, height: 28)
                                            .background(Color(red: 0.98, green: 0.82, blue: 0.82), in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            ForEach(session.messages) { message in
                                Text("\(message.speaker)：\(message.text)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(message.isUser ? primaryTextColor : secondaryTextColor)
                                    .lineLimit(3)
                            }

                            Button {
                                onContinue(session)
                            } label: {
                                Label(localizedText("继续这个对话", "Continue this conversation"), systemImage: "arrowshape.turn.up.right.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .background(Color(red: 0.30, green: 0.54, blue: 0.78), in: RoundedRectangle(cornerRadius: 9))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.99, green: 0.96, blue: 0.93))
            .navigationTitle(localizedText("以前对话", "Past Conversations"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ScenarioControlCard: View {
    let participant: ScenarioParticipant
    @Binding var selectedModeID: ScenarioMode.ID
    let modes: [ScenarioMode]
    let messages: [ScenarioMessage]
    let scrollTarget: UUID
    @Binding var draftMessage: String
    @Binding var recordingTimer: RecordingTimer
    let onAddMode: () -> Void
    let onNewConversation: () -> Void
    let onCancelRecording: () -> Void
    let onConfirmRecording: (Int) -> Void
    let onSend: () -> Void

    @State private var isShowingGuidance = false

    private var selectedMode: ScenarioMode {
        modes.first { $0.id == selectedModeID } ?? modes[0]
    }

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 10) {
                ScenarioAvatar(participant: participant, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(participant.name)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(participant.note)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                }

                Spacer()

                VStack(spacing: 1) {
                    Text(participant.relationshipLabel)
                        .font(.system(size: 14, weight: .heavy))

                    Text(localizedText("模拟关系", "Role"))
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color.white)
                .frame(width: 82, height: 36)
                .background(participant.color, in: Capsule())
            }

            Button(action: onNewConversation) {
                Label(localizedText("新对话", "New Chat"), systemImage: "plus.message.fill")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color(red: 0.90, green: 0.40, blue: 0.58), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            ScenarioModePicker(
                selectedModeID: $selectedModeID,
                modes: modes,
                onAddMode: onAddMode
            )

            ScenarioConversationPreview(
                messages: messages,
                guidance: selectedMode.displayGuidance,
                scrollTarget: scrollTarget
            )

            VoiceWaveform()
                .scaleEffect(y: 0.46)
                .frame(height: 14)

            HStack(spacing: 28) {
                ScenarioCircleAction(
                    systemImage: "xmark",
                    color: Color(red: 0.82, green: 0.29, blue: 0.31),
                    action: onCancelRecording
                )

                Button {
                    if recordingTimer.isRunning {
                        recordingTimer.stop()
                    } else {
                        recordingTimer.start()
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(recordingTimer.displayText)
                            .font(.system(size: 13, weight: .bold))

                        Image(systemName: "mic.fill")
                            .font(.system(size: 24, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    .frame(width: 76, height: 76)
                    .background(Color(red: 0.18, green: 0.72, blue: 0.28), in: Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    .overlay(Circle().stroke(Color(red: 0.18, green: 0.72, blue: 0.28), lineWidth: 1.5).padding(-4))
                }
                .buttonStyle(.plain)

                ScenarioCircleAction(systemImage: "checkmark", color: Color.white) {
                    let submittedSeconds = recordingTimer.finish()
                    onConfirmRecording(submittedSeconds)
                }
            }

            HStack(spacing: 10) {
                TextField(localizedText("输入你想练习说的话", "Type what you want to practice saying"), text: $draftMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primaryTextColor)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(Color.white.opacity(0.70), in: RoundedRectangle(cornerRadius: 8))

                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 36, height: 36)
                        .background(
                            draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.gray.opacity(0.35)
                            : Color(red: 0.30, green: 0.54, blue: 0.78),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
                .disabled(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.plain)
            }

            Divider()
                .background(Color(red: 0.78, green: 0.73, blue: 0.66))

            Button {
                isShowingGuidance = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(Color(red: 0.94, green: 0.59, blue: 0.12))

                    Text(localizedText("实时指导：\(selectedMode.displayGuidance)", "Live guide: \(selectedMode.displayGuidance)"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(secondaryTextColor)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(red: 1.00, green: 0.96, blue: 0.91), in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color(red: 0.88, green: 0.72, blue: 0.84), lineWidth: 1.3)
        )
        .sheet(isPresented: $isShowingGuidance) {
            ScenarioGuidanceSheet(mode: selectedMode)
                .presentationDetents([.height(330), .medium])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct ScenarioGuidanceSheet: View {
    let mode: ScenarioMode

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayTitle)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(primaryTextColor)

                    Text(localizedText("完整实时指导", "Full Live Guide"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(secondaryTextColor)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(primaryTextColor)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.72), in: Circle())
                }
                .buttonStyle(.plain)
            }

            Text(mode.displayGuidance)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(primaryTextColor)
                .lineSpacing(4)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.70), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 10) {
                GuidanceBullet(text: localizedText("先说事实，减少评价和指责。", "Start with facts and reduce judgment or blame."))
                GuidanceBullet(text: localizedText("再说你的感受，让对方知道这件事对你的影响。", "Then share your feelings so they understand the impact."))
                GuidanceBullet(text: localizedText("最后提出一个具体、可执行的下一步。", "Finally propose one specific next step."))
            }

            Spacer()
        }
        .padding(22)
        .background(Color(red: 0.99, green: 0.96, blue: 0.93))
    }
}

private struct GuidanceBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(red: 0.30, green: 0.54, blue: 0.78))

            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(secondaryTextColor)
                .lineSpacing(2)
        }
    }
}

private struct ScenarioModePicker: View {
    @Binding var selectedModeID: ScenarioMode.ID
    let modes: [ScenarioMode]
    let onAddMode: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(modes) { mode in
                    Button {
                        selectedModeID = mode.id
                    } label: {
                        Label(mode.displayTitle, systemImage: mode.systemImage)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(selectedModeID == mode.id ? primaryTextColor : secondaryTextColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                selectedModeID == mode.id
                                ? Color(red: 0.96, green: 0.64, blue: 0.76).opacity(0.72)
                                : Color.white.opacity(0.58),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onAddMode) {
                    Label(localizedText("自定义", "Custom"), systemImage: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.30, green: 0.54, blue: 0.78))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.68), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        }
    }
}

private struct ScenarioConversationPreview: View {
    let messages: [ScenarioMessage]
    let guidance: String
    let scrollTarget: UUID

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 6) {
                    if messages.isEmpty {
                        VStack(spacing: 7) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 23, weight: .semibold))
                                .foregroundStyle(secondaryTextColor)

                            Text(localizedText("新的对话已准备好", "New conversation ready"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(primaryTextColor)

                            Text(localizedText("说出第一句话，AI 会根据当前对象回应。", "Say the first line and AI will respond based on the current partner."))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(secondaryTextColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }

                    ForEach(messages) { message in
                        HStack {
                            if message.isUser {
                                Spacer(minLength: 28)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(message.speaker)
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundStyle(secondaryTextColor)

                                Text(message.text)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(primaryTextColor)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                message.isUser
                                ? Color(red: 0.77, green: 0.90, blue: 1.00).opacity(0.72)
                                : Color.white.opacity(0.72),
                                in: RoundedRectangle(cornerRadius: 8)
                            )

                            if !message.isUser {
                                Spacer(minLength: 28)
                            }
                        }
                        .id(message.id)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("conversation-bottom")
                }
                .padding(7)
            }
            .onChange(of: scrollTarget) { _, _ in
                withAnimation(.easeOut(duration: 0.22)) {
                    proxy.scrollTo("conversation-bottom", anchor: .bottom)
                }
            }
            .onAppear {
                proxy.scrollTo("conversation-bottom", anchor: .bottom)
            }
        }
        .frame(height: 156)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct ScenarioCircleAction: View {
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(systemImage == "checkmark" ? Color(red: 0.27, green: 0.28, blue: 0.27) : Color.white)
                .frame(width: 50, height: 50)
                .background(color, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct VoiceWaveform: View {
    private let bars: [CGFloat] = [18, 8, 26, 36, 22, 10, 28, 42, 16, 24, 34, 12, 26, 18]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, height in
                Capsule()
                    .fill(Color(red: 0.94, green: 0.58, blue: 0.68).opacity(0.72))
                    .frame(width: 4, height: height)
            }
        }
    }
}

private struct ScenarioAvatar: View {
    let participant: ScenarioParticipant
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(participant.color.opacity(participant.isCustom ? 0.24 : 0.70))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.white.opacity(0.88), lineWidth: 2))

            Image(systemName: participant.symbol)
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(primaryTextColor)
        }
    }
}

private struct ScenarioTabBar: View {
    let onOpenRelationshipGraph: () -> Void

    var body: some View {
        HStack(alignment: .bottom) {
            ScenarioTabItem(title: localizedText("首页", "Home"), systemImage: "house.fill", isSelected: false)

            Button(action: onOpenRelationshipGraph) {
                ScenarioTabItem(title: localizedText("关系网", "Map"), systemImage: "point.3.connected.trianglepath.dotted", isSelected: false)
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.96, green: 0.64, blue: 0.76))
                        .frame(width: 74, height: 74)

                    Image(systemName: "figure.wave")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Color.white)
                }

                Text(localizedText("情景模拟", "Simulation"))
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(primaryTextColor)
            }
            .frame(maxWidth: .infinity)
            .offset(y: -18)

            ScenarioTabItem(title: localizedText("情景模拟", "Simulation"), systemImage: "text.bubble.fill", isSelected: false)
            ScenarioTabItem(title: localizedText("我的", "Me"), systemImage: "person.crop.circle", isSelected: false)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 22)
        .frame(height: 98)
        .background(Color(red: 0.94, green: 0.94, blue: 0.93))
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct ScenarioTabItem: View {
    let title: String
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 25, weight: .semibold))

            Text(title)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(isSelected ? primaryTextColor : Color(red: 0.58, green: 0.58, blue: 0.58))
        .frame(maxWidth: .infinity)
    }
}

private struct AddScenarioParticipantSheet: View {
    let onAdd: (String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var note = ""
    @State private var relationship = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(localizedText("创建模拟对象", "Create Simulation Partner"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(primaryTextColor)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(primaryTextColor)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.72), in: Circle())
                }
            }

            TextField(localizedText("名字，例如：面试官", "Name, e.g. Interviewer"), text: $name)
                .textFieldStyle(.roundedBorder)

            TextField(localizedText("场景备注，例如：模拟一次艰难沟通", "Scene note, e.g. Practice a difficult conversation"), text: $note)
                .textFieldStyle(.roundedBorder)

            TextField(localizedText("关系标签，例如：导师、客户、朋友", "Relationship label, e.g. Mentor, Client, Friend"), text: $relationship)
                .textFieldStyle(.roundedBorder)

            Button {
                onAdd(name, note, relationship)
                dismiss()
            } label: {
                Label(localizedText("加入模拟", "Add to Simulation"), systemImage: "plus.message.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(primaryTextColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canSubmit ? Color(red: 0.96, green: 0.64, blue: 0.76) : Color.gray.opacity(0.20), in: RoundedRectangle(cornerRadius: 8))
            }
            .disabled(!canSubmit)

            Spacer()
        }
        .padding(24)
        .background(Color(red: 0.99, green: 0.96, blue: 0.93))
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct AddScenarioModeSheet: View {
    let onAdd: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var guidance = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(localizedText("自定义模拟模式", "Custom Simulation Mode"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(primaryTextColor)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(primaryTextColor)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.72), in: Circle())
                }
            }

            TextField(localizedText("模式名称，例如：和室友沟通", "Mode name, e.g. Talk with roommate"), text: $title)
                .textFieldStyle(.roundedBorder)

            TextField(localizedText("实时指导，例如：先讲事实，再讲需求", "Live guide, e.g. Say facts first, then needs"), text: $guidance)
                .textFieldStyle(.roundedBorder)

            Button {
                onAdd(title, guidance)
                dismiss()
            } label: {
                Label(localizedText("添加模式", "Add Mode"), systemImage: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(primaryTextColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canSubmit ? Color(red: 0.96, green: 0.64, blue: 0.76) : Color.gray.opacity(0.20), in: RoundedRectangle(cornerRadius: 8))
            }
            .disabled(!canSubmit)

            Spacer()
        }
        .padding(24)
        .background(Color(red: 0.99, green: 0.96, blue: 0.93))
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct RelationshipMapView: View {
    let people: [RelationshipPerson]
    let selectedPerson: RelationshipPerson?
    let onMovePerson: (RelationshipPerson.ID, CGPoint) -> Void
    let onOrganize: () -> Void
    let onSelect: (RelationshipPerson) -> Void

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

                    CenterProfile()
                        .position(centerPoint)
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
                Button(action: onOrganize) {
                    Label(localizedText("整理", "Organize"), systemImage: "wand.and.stars")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 0.21, green: 0.23, blue: 0.27))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.78), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 0.30, green: 0.54, blue: 0.78).opacity(0.16), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.leading, 16)
            }
            .overlay(alignment: .topTrailing) {
                MapControlHint(scale: scale)
                    .padding(.top, 8)
                    .padding(.trailing, 16)
            }
        }
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
                .font(.system(size: isSelected ? 15 : 13, weight: .semibold))
                .foregroundStyle(person.category.color.opacity(isSelected ? 1 : 0.70))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(red: 0.99, green: 0.96, blue: 0.93).opacity(0.82), in: Capsule())
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
        .foregroundStyle(primaryTextColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.72), in: Capsule())
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
                AvatarView(colors: person.avatarColors, symbol: person.symbol, size: avatarSize)
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
            isSelected ? Color.white.opacity(0.52) : Color.clear,
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(person.category.color.opacity(0.42), lineWidth: 1)
            }
        }
        .position(point)
    }

    private var label: some View {
        VStack(alignment: shouldPutTextFirst ? .trailing : .leading, spacing: 2) {
            Text(person.name)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(primaryTextColor)

            Text(person.displayNote)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
        }
        .frame(width: 86, alignment: shouldPutTextFirst ? .trailing : .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(person)
        }
    }

    private var shouldPutTextFirst: Bool {
        point.x > centerPoint.x
    }

    private var avatarSize: CGFloat {
        isSelected ? 66 : 54
    }
}

private struct CenterProfile: View {
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.58, green: 0.42, blue: 0.35))

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color(red: 0.20, green: 0.17, blue: 0.15).opacity(0.26))
            }
            .frame(width: 128, height: 128)
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )

            VStack(spacing: 2) {
                Text("Elias")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(primaryTextColor)

                Text(localizedText("设计师", "Designer"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(secondaryTextColor)

                Text(localizedText("长期向内探索", "Long-term inner exploration"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
            }
        }
    }
}

private struct AvatarView: View {
    let colors: [Color]
    let symbol: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill((colors.first ?? Color(red: 0.78, green: 0.74, blue: 0.66)).opacity(0.72))

            Image(systemName: symbol)
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(Color(red: 0.18, green: 0.19, blue: 0.22).opacity(0.74))
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct RelationshipFilterBar: View {
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
                            .foregroundStyle(primaryTextColor)
                            .frame(width: 106, height: 56)
                            .background(
                                Capsule()
                                    .fill(selectedFilter == filter && selectedCustomCategory == nil ? filter.tint.opacity(0.24) : Color.white.opacity(0.78))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selectedFilter == filter && selectedCustomCategory == nil ? filter.tint.opacity(0.58) : filter.tint.opacity(0.16), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        if let category = filter.category {
                            Button {
                                onDeleteRelationship(category)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(Color(red: 0.64, green: 0.22, blue: 0.28), Color.white.opacity(0.92))
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
                            .foregroundStyle(primaryTextColor)
                            .frame(width: 106, height: 56)
                            .background(
                                Capsule()
                                    .fill(selectedCustomCategory == category ? category.color.opacity(0.24) : Color.white.opacity(0.78))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selectedCustomCategory == category ? category.color.opacity(0.58) : category.color.opacity(0.16), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            onDeleteRelationship(category)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Color(red: 0.64, green: 0.22, blue: 0.28), Color.white.opacity(0.92))
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
                        .foregroundStyle(Color(red: 0.30, green: 0.54, blue: 0.78))
                        .frame(width: 56, height: 56)
                        .background(Color.white.opacity(0.78), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(red: 0.30, green: 0.54, blue: 0.78).opacity(0.18), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(6)
        }
        .background(.white.opacity(0.88), in: Capsule())
    }
}

private struct RelationshipDetailSheet: View {
    let person: RelationshipPerson
    let availableCategories: [RelationshipCategory]
    let onCategoryChange: (RelationshipCategory) -> Void
    let onDeletePerson: () -> Void
    let onStartScenario: () -> Void
    @State private var pendingCategory: RelationshipCategory?
    @State private var isConfirmingDeletePerson = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                ProfileAvatarView(category: person.category, symbol: person.symbol)

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
                                    .foregroundStyle(person.category == category ? Color(red: 0.18, green: 0.19, blue: 0.23) : category.color)
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

            Button(action: onStartScenario) {
                Label(localizedText("与 \(person.name) 情景模拟", "Simulate with \(person.name)"), systemImage: "figure.wave")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(primaryTextColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color(red: 0.96, green: 0.64, blue: 0.76).opacity(0.46), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                isConfirmingDeletePerson = true
            } label: {
                Label(localizedText("从关系图谱删除此人", "Remove this person from map"), systemImage: "trash.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 0.62, green: 0.12, blue: 0.18))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color(red: 0.98, green: 0.82, blue: 0.82), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(24)
        .background(Color(red: 0.99, green: 0.96, blue: 0.93))
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
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ProfileAvatarView: View {
    let category: RelationshipCategory
    let symbol: String

    var body: some View {
        ZStack {
            Circle()
                .fill(category.color.opacity(0.18))
                .frame(width: 64, height: 64)
                .overlay(
                    Circle()
                        .stroke(category.color.opacity(0.52), lineWidth: 1)
                )

            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(primaryTextColor)
        }
    }
}

private struct AddPersonSheet: View {
    let availableCategories: [RelationshipCategory]
    let onAdd: (String, String, RelationshipCategory) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var note = ""
    @State private var selectedCategory: RelationshipCategory

    init(
        availableCategories: [RelationshipCategory],
        onAdd: @escaping (String, String, RelationshipCategory) -> Void
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
                    .foregroundStyle(primaryTextColor)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(primaryTextColor)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.72), in: Circle())
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                TextField(localizedText("名字", "Name"), text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField(localizedText("一句关系备注", "One-line relationship note"), text: $note)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(localizedText("选择关系", "Choose Relationship"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(primaryTextColor)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableCategories) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Text(category.shortTitle)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(selectedCategory == category ? Color(red: 0.18, green: 0.19, blue: 0.23) : category.color)
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
                onAdd(name, note, selectedCategory)
                dismiss()
            } label: {
                Label(localizedText("添加到图谱", "Add to Map"), systemImage: "person.badge.plus")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(red: 0.18, green: 0.19, blue: 0.23))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canSubmit ? Color(red: 0.95, green: 0.58, blue: 0.70).opacity(0.48) : Color.gray.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
            }
            .disabled(!canSubmit)

            Spacer()
        }
        .padding(24)
        .background(Color(red: 0.99, green: 0.96, blue: 0.93))
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct AddRelationshipSheet: View {
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(localizedText("自定义关系", "Custom Relationship"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(primaryTextColor)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(primaryTextColor)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.72), in: Circle())
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
                    .foregroundStyle(Color(red: 0.18, green: 0.19, blue: 0.23))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canSubmit ? Color(red: 0.54, green: 0.43, blue: 0.82).opacity(0.34) : Color.gray.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
            }
            .disabled(!canSubmit)

            Spacer()
        }
        .padding(24)
        .background(Color(red: 0.99, green: 0.96, blue: 0.93))
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct RelationshipBackground: View {
    var body: some View {
        Color(red: 0.99, green: 0.96, blue: 0.93)
        .ignoresSafeArea()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
