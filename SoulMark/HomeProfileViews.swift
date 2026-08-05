//
//  HomeProfileViews.swift
//  SoulMark
//

import SwiftUI

struct IntegratedHomePage: View {
    @AppStorage("soulMarkLanguage") private var language = "zh"
    @AppStorage("soulMarkGenderTheme") private var genderTheme = "male"
    @AppStorage("soulMarkAppearanceMode") private var appearanceMode = "auto"
    @State private var showingSettings = false

    let userID: UUID?
    let people: [RelationshipPerson]
    let onOpenRelationshipGraph: () -> Void
    let onOpenScenario: () -> Void
    let onOpenJournal: () -> Void

    var body: some View {
        ZStack {
            SoulBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    SoulPageHeader(
                        eyebrow: "Soul OS / 01",
                        title: "SoulMark",
                        subtitle: localizedText("早上好。今天也更清楚地理解自己与他人。", "Good morning. See yourself and others a little more clearly today.")
                    ) {
                        SoulIconButton(systemImage: "slider.horizontal.3") {
                            showingSettings = true
                        }
                    }

                    dailyDose
                    heroPanel

                    VStack(alignment: .leading, spacing: 14) {
                        SoulSectionHeader(
                            title: localizedText("快速开始", "Quick Start"),
                            detail: "02 Actions"
                        )
                        quickActions
                    }

                    relationshipSnapshot
                    weeklySignal
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 126)
            }
        }
        .id("\(genderTheme)-\(appearanceMode)")
        .sheet(isPresented: $showingSettings) {
            SoulSettingsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var heroPanel: some View {
        ZStack(alignment: .bottomTrailing) {
            SoulVisorPanelBackground()

            VStack(alignment: .leading, spacing: 14) {
                SoulStatusPill(
                    text: localizedText("信号在线", "SIGNAL ONLINE"),
                    systemImage: "dot.radiowaves.left.and.right"
                )

                Text(localizedText("把难开口的话，\n先在这里练一次。", "Practice the hard words\nhere first."))
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(localizedText("Soul 会观察表达节奏，帮你找到更真实、也更舒服的说法。", "Soul reads the rhythm of your message and helps you find words that feel honest and clear."))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .lineSpacing(3)
                    .frame(maxWidth: language == "en" ? 208 : 190, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onOpenScenario) {
                    HStack(spacing: 9) {
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 15, weight: .bold))

                        Text(localizedText("开始模拟", "Start Simulation"))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .heavy))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(SoulTheme.accent, in: RoundedRectangle(cornerRadius: 8))
                    .shadow(color: SoulTheme.accent.opacity(0.35), radius: 12, x: 0, y: 7)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(20)
            .padding(.trailing, language == "en" ? 104 : 118)

            ZStack {
                Circle()
                    .stroke(SoulTheme.energy.opacity(0.70), lineWidth: 2.4)
                    .frame(width: 174, height: 174)
                    .shadow(color: SoulTheme.energy.opacity(0.68), radius: 16)

                Circle()
                    .stroke(SoulTheme.accent.opacity(0.36), style: StrokeStyle(lineWidth: 1, dash: [5, 7]))
                    .frame(width: 202, height: 202)

                SoulMascotFigure(height: 244, haloIntensity: 1.65)
            }
            .offset(x: 16, y: 20)
        }
        .frame(height: language == "en" ? 334 : 286)
        .clipped()
    }

    private var dailyDose: some View {
        let quote = DailyQuoteCatalog.quote(userID: userID ?? DailyQuoteCatalog.guestUserID)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(localizedText("今日毒鸡汤", "DAILY REALITY CHECK"), systemImage: "quote.opening")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(SoulTheme.energy)

                Spacer()

                ShareLink(item: quote.shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 38, height: 38)
                        .background(SoulTheme.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedText("分享今日毒鸡汤", "Share today's quote"))
            }

            Text(quote.text)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(SoulTheme.primaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text("— \(quote.source)")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(SoulTheme.tertiaryText)
                .lineLimit(2)

            Text("SOULMARK / DAILY DOSE")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(SoulTheme.tertiaryText)
        }
        .padding(18)
        .background(SoulGlassCardBackground(accented: true))
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            SoulActionCard(
                index: "01",
                title: localizedText("关系图谱", "Relationship Map"),
                subtitle: localizedText("看见连接与距离", "See connection and distance"),
                icon: "point.3.connected.trianglepath.dotted",
                action: onOpenRelationshipGraph
            )

            SoulActionCard(
                index: "02",
                title: localizedText("沟通复盘", "Conversation Review"),
                subtitle: localizedText("读懂表达的影响", "Read the impact of words"),
                icon: "text.bubble.fill",
                action: onOpenJournal
            )
        }
    }

    private var relationshipSnapshot: some View {
        VStack(alignment: .leading, spacing: 15) {
            SoulSectionHeader(
                title: localizedText("关系雷达", "Relationship Radar"),
                detail: localizedText("最近连接", "Recent links")
            )

            if radarPeople.isEmpty {
                Button(action: onOpenRelationshipGraph) {
                    HStack(spacing: 13) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(SoulTheme.accent)
                            .frame(width: 44, height: 44)
                            .background(SoulTheme.accentSoft, in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(localizedText("关系雷达还是空的", "Your relationship radar is empty"))
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(SoulTheme.primaryText)

                            Text(localizedText("添加第一个人，开始看见关系变化", "Add someone to start seeing relationship signals"))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(SoulTheme.secondaryText)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(SoulTheme.energy)
                    }
                    .padding(16)
                    .background(SoulGlassCardBackground(accented: true))
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(radarPeople.enumerated()), id: \.element.id) { index, person in
                        HStack(spacing: 13) {
                            ZStack {
                                Circle()
                                    .fill(SoulTheme.accentSoft)
                                    .frame(width: 46, height: 46)

                                Text(String(person.name.prefix(1)))
                                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                                    .foregroundStyle(SoulTheme.accent)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(person.name)
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    .foregroundStyle(SoulTheme.primaryText)

                                Text(localizedText(
                                    "\(person.category.displayTitle) · 当前连接度 \(Int(person.strength * 100))",
                                    "\(person.category.displayTitle) · Connection \(Int(person.strength * 100))"
                                ))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(SoulTheme.secondaryText)
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                ForEach(0..<4, id: \.self) { strength in
                                    Capsule()
                                        .fill(Double(strength + 1) / 4 <= person.strength ? SoulTheme.energy : SoulTheme.subtleFill)
                                        .frame(width: 4, height: CGFloat(9 + strength * 4))
                                }
                            }
                            .frame(width: 30, height: 28, alignment: .bottom)
                        }
                        .padding(.vertical, 13)

                        if index < radarPeople.count - 1 {
                            Divider().overlay(SoulTheme.cardStroke)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(SoulGlassCardBackground(accented: true))
            }
        }
    }

    private var weeklySignal: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(localizedText("本周表达信号", "Weekly Expression Signal"))
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)

                    Text(localizedText("你已经完成 3 次练习，清晰度正在上升。", "You completed 3 practices. Your clarity is trending up."))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .lineSpacing(3)
                }

                Spacer()

                Text("78")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(SoulTheme.energy)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(SoulTheme.energy)
                        .frame(width: proxy.size.width * 0.78)
                }
            }
            .frame(height: 6)
        }
        .padding(18)
        .background(SoulVisorPanelBackground())
    }

    private var radarPeople: [RelationshipPerson] {
        Array(people.sorted { $0.strength > $1.strength }.prefix(3))
    }
}

struct IntegratedProfilePage: View {
    @EnvironmentObject private var session: AppSession
    @AppStorage("soulMarkLanguage") private var language = "zh"
    @AppStorage("soulMarkGenderTheme") private var genderTheme = "male"
    @AppStorage("soulMarkAppearanceMode") private var appearanceMode = "auto"
    @State private var showingSettings = false
    @State private var showingAchievements = false

    var achievementProgress: AchievementProgress = .empty

    var body: some View {
        ZStack {
            SoulBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    SoulPageHeader(
                        eyebrow: "Identity / 05",
                        title: localizedText("我的", "Profile"),
                        subtitle: localizedText("你的关系练习、偏好与数据空间。", "Your practice, preferences, and relationship data space.")
                    ) {
                        SoulIconButton(systemImage: "gearshape.fill") {
                            showingSettings = true
                        }
                    }

                    identityPanel
                    statsBand
                    personalizationButton
                    accountMenu
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 126)
            }
        }
        .id("\(genderTheme)-\(appearanceMode)")
        .sheet(isPresented: $showingSettings) {
            SoulSettingsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAchievements) {
            AchievementsSheet(progress: achievementProgress)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var identityPanel: some View {
        ZStack(alignment: .bottomTrailing) {
            SoulVisorPanelBackground()

            VStack(alignment: .leading, spacing: 8) {
                SoulStatusPill(text: "ID / 0001", systemImage: "person.text.rectangle")

                Spacer()

                Text(session.user?.displayName ?? "Soul User")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)

                Text(localizedText("关系洞察等级 01", "Relationship Insight Level 01"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.58))

                HStack(spacing: 6) {
                    Circle().fill(SoulTheme.energy).frame(width: 6, height: 6)
                    Text(localizedText("数字身份同步中", "Digital identity synced"))
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(SoulTheme.energy)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(19)

            SoulMascotFigure(height: 180)
                .offset(x: 2, y: 22)
        }
        .frame(height: 210)
        .clipped()
    }

    private var statsBand: some View {
        HStack(spacing: 0) {
            SoulStatItem(title: localizedText("复盘", "Reviews"), value: String(format: "%02d", achievementProgress.reviewCount), icon: "text.bubble.fill")
            Divider().frame(height: 48).overlay(SoulTheme.cardStroke)
            SoulStatItem(title: localizedText("连接", "People"), value: String(format: "%02d", achievementProgress.peopleCount), icon: "person.2.fill")
            Divider().frame(height: 48).overlay(SoulTheme.cardStroke)
            SoulStatItem(title: localizedText("练习", "Practice"), value: String(format: "%02d", achievementProgress.practiceCount), icon: "bolt.fill")
        }
        .padding(.vertical, 16)
        .background(SoulGlassCardBackground(accented: true))
    }

    private var personalizationButton: some View {
        Button {
            showingSettings = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 44, height: 44)
                    .background(SoulTheme.accent, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedText("个性化界面", "Personalize Interface"))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(SoulTheme.primaryText)

                    Text(localizedText("语言、能量色与日夜模式", "Language, energy color, and appearance"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(SoulTheme.secondaryText)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(SoulTheme.accent)
            }
            .padding(16)
            .background(SoulGlassCardBackground())
        }
        .buttonStyle(.plain)
    }

    private var accountMenu: some View {
        VStack(alignment: .leading, spacing: 14) {
            SoulSectionHeader(title: localizedText("数据与安全", "Data & Security"), detail: "Vault")

            VStack(spacing: 0) {
                Button {
                    showingAchievements = true
                } label: {
                    SoulMenuRow(title: localizedText("成就徽章", "Achievements"), subtitle: localizedText("查看你的练习成果", "See your practice milestones"), icon: "seal.fill")
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 58).overlay(SoulTheme.cardStroke)
                SoulMenuRow(title: localizedText("数据仓库", "Data Vault"), subtitle: localizedText("关系与复盘数据总览", "Overview of relationship and review data"), icon: "externaldrive.fill")
                Divider().padding(.leading, 58).overlay(SoulTheme.cardStroke)
                SoulMenuRow(title: localizedText("隐私与安全", "Privacy & Security"), subtitle: localizedText("控制数据和权限", "Control your data and permissions"), icon: "lock.shield.fill")
            }
            .padding(.horizontal, 14)
            .background(SoulGlassCardBackground())
        }
    }
}

private struct AchievementsSheet: View {
    let progress: AchievementProgress
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            SoulBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(localizedText("成就徽章", "Achievements"))
                                .font(.system(size: 27, weight: .heavy, design: .rounded))
                                .foregroundStyle(SoulTheme.primaryText)

                            Text(localizedText("每一次真实的连接，都值得被看见。", "Every honest connection deserves to be seen."))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(SoulTheme.secondaryText)
                        }

                        Spacer()

                        SoulIconButton(systemImage: "xmark") {
                            dismiss()
                        }
                    }

                    let achievements = SoulAchievement.all(progress: progress)

                    HStack(spacing: 8) {
                        Text("\(achievements.filter(\.isUnlocked).count)/\(achievements.count)")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(SoulTheme.energy)

                        Text(localizedText("已点亮", "unlocked"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(SoulTheme.secondaryText)
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(achievements) { achievement in
                            AchievementBadgeCard(achievement: achievement)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 28)
            }
        }
    }
}

private struct AchievementBadgeCard: View {
    let achievement: SoulAchievement

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(achievement.isUnlocked ? SoulTheme.accentSoft : SoulTheme.subtleFill)
                    .frame(width: 52, height: 52)

                Image(systemName: achievement.systemImage)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(achievement.isUnlocked ? SoulTheme.accent : SoulTheme.tertiaryText)
                    .shadow(color: achievement.isUnlocked ? SoulTheme.energy.opacity(0.42) : .clear, radius: 7)

                if !achievement.isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(SoulTheme.secondaryText)
                        .frame(width: 20, height: 20)
                        .background(SoulTheme.cardFill, in: Circle())
                        .offset(x: 21, y: 21)
                }
            }

            Text(achievement.title)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(achievement.isUnlocked ? SoulTheme.primaryText : SoulTheme.secondaryText)
                .lineLimit(2)

            Text(achievement.requirement)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(SoulTheme.secondaryText)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
        .padding(14)
        .background(SoulGlassCardBackground(accented: achievement.isUnlocked))
        .saturation(achievement.isUnlocked ? 1 : 0.08)
    }
}

private struct SoulSettingsSheet: View {
    @EnvironmentObject private var session: AppSession
    @AppStorage("soulMarkLanguage") private var language = "zh"
    @AppStorage("soulMarkGenderTheme") private var genderTheme = "male"
    @AppStorage("soulMarkAppearanceMode") private var appearanceMode = "auto"
    @AppStorage("soulMarkBackendURL") private var backendURL = RealtimeVoiceServiceConfiguration.defaultBackendURL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                SoulBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        themePreview
                            .id("\(genderTheme)-\(appearanceMode)")

                        SettingsGroup(title: localizedText("语言", "Language"), subtitle: localizedText("选择界面主要语言", "Choose the primary interface language")) {
                            Picker(localizedText("语言", "Language"), selection: $language) {
                                Text("中文").tag("zh")
                                Text("English").tag("en")
                            }
                            .pickerStyle(.segmented)
                        }

                        SettingsGroup(title: localizedText("能量色", "Energy Color"), subtitle: localizedText("蓝色冷静锐利，樱粉温柔有力量", "Blue feels sharp and calm; sakura feels warm and bold")) {
                            HStack(spacing: 10) {
                                ThemeChoiceButton(
                                    title: localizedText("深空蓝", "Orbit Blue"),
                                    systemImage: "circle.hexagongrid.fill",
                                    color: Color(red: 0.04, green: 0.50, blue: 0.90),
                                    isSelected: genderTheme == "male"
                                ) {
                                    genderTheme = "male"
                                }

                                ThemeChoiceButton(
                                    title: localizedText("樱花粉", "Sakura Pink"),
                                    systemImage: "sparkle",
                                    color: Color(red: 0.94, green: 0.30, blue: 0.56),
                                    isSelected: genderTheme == "female"
                                ) {
                                    genderTheme = "female"
                                }
                            }
                        }

                        SettingsGroup(title: localizedText("显示模式", "Appearance"), subtitle: localizedText("跟随时间，或固定日间与夜间", "Follow time, or keep day or night mode")) {
                            Picker(localizedText("模式", "Mode"), selection: $appearanceMode) {
                                Text(localizedText("自动", "Auto")).tag("auto")
                                Text(localizedText("日间", "Day")).tag("day")
                                Text(localizedText("夜间", "Night")).tag("night")
                            }
                            .pickerStyle(.segmented)
                        }

                        SettingsGroup(
                            title: localizedText("语音服务", "Voice Service"),
                            subtitle: localizedText("真机调试时填写运行 SoulMark 后端的电脑地址", "For device testing, enter the Mac address running the SoulMark backend")
                        ) {
                            HStack(spacing: 10) {
                                Image(systemName: "server.rack")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(SoulTheme.accent)

                                TextField("http://192.168.1.10:8000", text: $backendURL)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.URL)

                                Button {
                                    backendURL = RealtimeVoiceServiceConfiguration.defaultBackendURL
                                } label: {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(SoulTheme.secondaryText)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(localizedText("恢复默认地址", "Restore default address"))
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 46)
                            .background(SoulTheme.subtleFill, in: RoundedRectangle(cornerRadius: 8))
                        }

                        SettingsGroup(
                            title: localizedText("账户", "Account"),
                            subtitle: session.user?.email ?? localizedText("当前 Soul 身份", "Current Soul identity")
                        ) {
                            Button {
                                dismiss()
                                session.signOut()
                            } label: {
                                Label(localizedText("退出登录", "Sign Out"), systemImage: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundStyle(SoulTheme.danger)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .frame(height: 46)
                                    .background(SoulTheme.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 24)
                }
            }
            .id("\(genderTheme)-\(appearanceMode)")
            .navigationTitle(localizedText("个性化", "Personalization"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localizedText("完成", "Done")) {
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(SoulTheme.accent)
                }
            }
        }
        .preferredColorScheme(isSoulNightMode() ? .dark : .light)
    }

    private var themePreview: some View {
        ZStack(alignment: .bottomTrailing) {
            SoulVisorPanelBackground()

            VStack(alignment: .leading, spacing: 8) {
                SoulStatusPill(text: localizedText("实时预览", "LIVE PREVIEW"), systemImage: "eye.fill")

                Spacer()

                Text(genderTheme == "male" ? localizedText("深空蓝信号", "Orbit Blue Signal") : localizedText("樱花粉信号", "Sakura Pink Signal"))
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)

                Text(isSoulNightMode() ? localizedText("夜间模式", "Night mode") : localizedText("日间模式", "Day mode"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(18)

            SoulMascotFigure(height: 155)
                .offset(x: 8, y: 18)
        }
        .frame(height: 180)
        .clipped()
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(SoulTheme.primaryText)

                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(SoulTheme.secondaryText)
            }

            content
        }
        .padding(16)
        .background(SoulGlassCardBackground())
    }
}

private struct ThemeChoiceButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color)

                Text(title)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(SoulTheme.primaryText)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? color : SoulTheme.tertiaryText)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(isSelected ? color.opacity(0.12) : SoulTheme.subtleFill, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? color.opacity(0.48) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct SoulActionCard: View {
    let index: String
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(SoulTheme.accent)
                        .frame(width: 42, height: 42)
                        .background(SoulTheme.accentSoft, in: RoundedRectangle(cornerRadius: 8))

                    Spacer()

                    Text(index)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(SoulTheme.tertiaryText)
                }

                Text(title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(SoulTheme.primaryText)
                    .lineLimit(2)

                HStack(alignment: .bottom, spacing: 8) {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(SoulTheme.secondaryText)
                        .lineLimit(2)

                    Spacer(minLength: 2)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(SoulTheme.energy)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
            .padding(14)
            .background(SoulGlassCardBackground())
        }
        .buttonStyle(.plain)
    }
}

private struct SoulStatItem: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Label(value, systemImage: icon)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(SoulTheme.primaryText)

            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(SoulTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SoulMenuRow: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(SoulTheme.accent)
                .frame(width: 38, height: 38)
                .background(SoulTheme.accentSoft, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(SoulTheme.primaryText)

                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(SoulTheme.secondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(SoulTheme.tertiaryText)
        }
        .padding(.vertical, 12)
    }
}
