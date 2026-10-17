//
//  HomeProfileViews.swift
//  SoulMark
//

import AVFoundation
import SwiftUI

struct IntegratedHomePage: View {
    @EnvironmentObject private var session: AppSession
    @AppStorage("soulMarkLanguage") private var language = "zh"
    @AppStorage("soulMarkGenderTheme") private var genderTheme = "male"
    @AppStorage("soulMarkAppearanceMode") private var appearanceMode = "auto"
    @State private var showingSettings = false
    @State private var showingReport = false
    @State private var pageSummary: SelfAwarenessReportDTO?
    @State private var sharePayload: DailyQuoteSharePayload?
    @State private var shareErrorMessage: String?

    let userID: UUID?
    let people: [RelationshipPerson]
    let averageReviewScore: Double?
    let onOpenRelationshipGraph: () -> Void
    let onOpenScenario: () -> Void
    let onOpenJournal: () -> Void
    let onSelectPerson: (RelationshipPerson) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    SoulPageHeader(
                        title: "SoulMark",
                        subtitle: greetingSubtitle
                    ) {
                        SoulIconButton(systemImage: "slider.horizontal.3") {
                            showingSettings = true
                        }
                        .accessibilityLabel(localizedText("个性化", "Personalization"))
                    }

                    dailyDose
                    heroPanel
                    if let pageSummary {
                        selfPageLine(pageSummary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        SoulSectionHeader(
                            title: localizedText("快速开始", "Quick Start")
                        )
                        quickActions
                    }

                    ChallengeHubCard()

                    relationshipSnapshot
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, AppTabBar.reservedHeight)
            }
        .background { SoulBackground() }
        .sheet(isPresented: $showingSettings) {
            SoulSettingsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $sharePayload) { payload in
            ActivityShareSheet(items: payload.items)
        }
        .alert(
            localizedText("暂时无法分享", "Unable to Share"),
            isPresented: Binding(
                get: { shareErrorMessage != nil },
                set: { if !$0 { shareErrorMessage = nil } }
            )
        ) {
            Button(localizedText("知道了", "OK")) { shareErrorMessage = nil }
        } message: {
            Text(shareErrorMessage ?? "")
        }
        .fullScreenCover(isPresented: $showingReport) {
            SelfAwarenessReportSheet(
                onOpenGraph: onOpenRelationshipGraph,
                onOpenScenario: onOpenScenario,
                onOpenJournal: onOpenJournal
            )
            .environmentObject(session)
        }
        .task(id: session.selfPageRevision) { await loadPageSummary() }
    }

    private var heroPanel: some View {
        ZStack(alignment: .bottomTrailing) {
            SoulVisorPanelBackground()

            VStack(alignment: .leading, spacing: 14) {
                SoulStatusPill(
                    text: localizedText("今日练习", "TODAY'S PRACTICE"),
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
                    .background(SoulTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private func selfPageLine(_ summary: SelfAwarenessReportDTO) -> some View {
        Button {
            showingReport = true
        } label: {
            HStack(spacing: 12) {
                Text(localizedText(
                    "证据 \(summary.evidenceCovered)/\(summary.evidenceTotal)",
                    "Evidence \(summary.evidenceCovered)/\(summary.evidenceTotal)"
                ))
                Spacer(minLength: 8)
                Text(localizedText(
                    "本周这一步：\(summary.weeklyStepDone ? "已做" : "未做")",
                    "This week's step: \(summary.weeklyStepDone ? "Done" : "Not done")"
                ))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .heavy))
            }
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundStyle(SoulTheme.primaryText)
            .padding(16)
            .background(SoulGlassCardBackground())
        }
        .buttonStyle(.plain)
    }

    private func loadPageSummary() async {
        pageSummary = try? await session.loadSelfAwarenessReport()
    }

    private var dailyDose: some View {
        let quote = DailyQuoteCatalog.quote(userID: userID ?? DailyQuoteCatalog.guestUserID)
        let signal = WeeklyExpressionSignal(averageScore: averageReviewScore)

        return VStack(alignment: .leading, spacing: 14) {
            Text(quote.text)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(SoulTheme.primaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text("— \(quote.source)")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(SoulTheme.tertiaryText)
                .lineLimit(2)

            if averageReviewScore == nil {
                Text(weeklySignalDetail)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(SoulTheme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 8) {
                    SoulSlotIcon(asset: SoulArtwork.signal)
                        .frame(width: 28, height: 16)
                    Text(localizedText("本周表达信号", "Weekly Expression Signal"))
                }
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(SoulTheme.primaryText)

                Spacer(minLength: 8)

                if averageReviewScore != nil {
                    Text(signal.displayScore)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(SoulTheme.energy)
                }

                Button {
                    do {
                        sharePayload = try DailyQuoteSharePayload.make(quote: quote)
                    } catch {
                        shareErrorMessage = localizedText(
                            "分享卡片生成失败，请稍后重试。",
                            "The share card could not be created. Try again later."
                        )
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 38, height: 38)
                        .background(SoulTheme.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedText("分享今日内容", "Share today's quote"))
            }
        }
        .padding(18)
        .background(SoulGlassCardBackground(accented: true))
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            SoulActionCard(
                index: "01",
                title: localizedText("关系图谱", "Relationship Map"),
                subtitle: localizedText("在关系里看见自己", "See yourself through others"),
                icon: "point.3.connected.trianglepath.dotted",
                iconAsset: SoulArtwork.tabMap,
                action: onOpenRelationshipGraph
            )

            SoulActionCard(
                index: "02",
                title: localizedText("沟通复盘", "Conversation Review"),
                subtitle: localizedText("读懂表达的影响", "Read the impact of words"),
                icon: "text.bubble.fill",
                iconAsset: SoulArtwork.tabReview,
                action: onOpenJournal
            )
        }
    }

    private var relationshipSnapshot: some View {
        VStack(alignment: .leading, spacing: 15) {
            SoulSectionHeader(
                title: localizedText("关系镜子", "Relationship Mirror"),
                detail: localizedText("最近连接", "Recent links")
            )

            if radarPeople.isEmpty {
                Button(action: onOpenRelationshipGraph) {
                    HStack(spacing: 13) {
                        SoulSlotIcon(asset: SoulArtwork.emptyMirror)
                            .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(localizedText("关系镜子还是空的", "Your relationship mirror is empty"))
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
                        Button {
                            onSelectPerson(person)
                        } label: {
                            HStack(spacing: 13) {
                                ContactAvatarView(
                                    avatarPath: person.avatarURL,
                                    color: person.category.color,
                                    symbol: person.symbol,
                                    size: 46
                                )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(person.name)
                                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                                        .foregroundStyle(SoulTheme.primaryText)

                                    Text(person.intimacyCalculated
                                        ? localizedText(
                                            "\(person.category.displayTitle) · 亲密度 \(Int(person.strength * 100))%",
                                            "\(person.category.displayTitle) · Closeness \(Int(person.strength * 100))%"
                                        )
                                        : localizedText(
                                            "\(person.category.displayTitle) · 还需 \(max(0, 10 - person.eventCount)) 件事件",
                                            "\(person.category.displayTitle) · \(max(0, 10 - person.eventCount)) more events"
                                        )
                                    )
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(SoulTheme.secondaryText)
                                }

                                Spacer()

                                HStack(spacing: 4) {
                                    ForEach(0..<4, id: \.self) { strength in
                                        Capsule()
                                            .fill(
                                                person.intimacyCalculated
                                                    && Double(strength + 1) / 4 <= person.strength
                                                    ? SoulTheme.energy
                                                    : SoulTheme.subtleFill
                                            )
                                            .frame(width: 4, height: CGFloat(9 + strength * 4))
                                    }
                                }
                                .frame(width: 30, height: 28, alignment: .bottom)
                            }
                            .padding(.vertical, 13)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

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

    private var greetingSubtitle: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return localizedText("早上好。今天也更清楚地理解自己与他人。", "Good morning. See yourself and others a little more clearly today.")
        case 12..<18:
            return localizedText("下午好。今天也更清楚地理解自己与他人。", "Good afternoon. See yourself and others a little more clearly today.")
        default:
            return localizedText("晚上好。今天也更清楚地理解自己与他人。", "Good evening. See yourself and others a little more clearly today.")
        }
    }

    private var weeklySignalDetail: String {
        localizedText(
            "完成一次复盘后，这里会显示你的平均表达分。",
            "Complete a review to see your average expression score."
        )
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
    @State private var showingDataVault = false
    @State private var showingPrivacySecurity = false
    @State private var showingReport = false
    @State private var selectedRecentSection: ProfileRecentSection?

    var people: [RelationshipPerson] = []
    var achievementProgress: AchievementProgress = .empty
    var onOpenRelationshipGraph: () -> Void = {}
    var onOpenScenario: () -> Void = {}
    var onOpenJournal: () -> Void = {}

    var body: some View {
        ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    SoulPageHeader(
                        title: localizedText("我的", "Profile"),
                        subtitle: localizedText("通过关系，认识自己。", "Know yourself through your relationships.")
                    ) {
                        SoulIconButton(systemImage: "slider.horizontal.3") {
                            showingSettings = true
                        }
                        .accessibilityLabel(localizedText("个性化", "Personalization"))
                    }

                    identityPanel
                    SelfAwarenessReportEntryCard { showingReport = true }
                    GrowthProgressCard(state: session.growthState) {
                        Task { await session.refreshGrowth() }
                    }
                    ChallengeHubCard()
                    personalizationButton
                    accountMenu
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, AppTabBar.reservedHeight)
            }
        .background { SoulBackground() }
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
        .sheet(isPresented: $showingDataVault) {
            DataVaultSheet(people: people)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingPrivacySecurity) {
            PrivacySecuritySheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showingReport) {
            SelfAwarenessReportSheet(
                onOpenGraph: onOpenRelationshipGraph,
                onOpenScenario: onOpenScenario,
                onOpenJournal: onOpenJournal
            )
            .environmentObject(session)
        }
        .sheet(item: $selectedRecentSection) { section in
            ProfileRecentActivitySheet(section: section, people: people)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var identityPanel: some View {
        ZStack(alignment: .bottomTrailing) {
            SoulVisorPanelBackground()

            VStack(alignment: .leading, spacing: 10) {
                SoulStatusPill(
                    text: "ID / \(PublicUserIDFormatter.string(session.user?.publicID))",
                    systemImage: "person.text.rectangle"
                )

                Text(session.user?.displayName ?? "Soul User")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(identityLevelLine)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let growth = session.growthState.snapshot {
                    identityXP(growth)
                    if let next = GrowthMilestone.all.first(where: { $0.level > growth.level }) {
                        Text(localizedText("下个称号：Lv.\(next.level) · \(next.title)", "Next title: Lv.\(next.level) · \(next.title)"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }

                identityCounts
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .padding(.trailing, 108)

            SoulMascotFigure(height: 176)
                .offset(x: 4, y: 16)
        }
        .clipped()
    }

    private var identityLevelLine: String {
        if let snapshot = session.growthState.snapshot {
            return "Lv.\(snapshot.level) · \(snapshot.currentMilestone.title)"
        }
        if case .failed = session.growthState {
            return localizedText("成长记录暂时无法同步", "Progress is temporarily unavailable")
        }
        return localizedText("成长记录同步中", "Syncing growth")
    }

    private func identityXP(_ growth: GrowthSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("\(growth.levelExperience)/\(growth.nextLevelExperience)")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white)
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(height: 12)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(LinearGradient(colors: [SoulTheme.accent, SoulTheme.energy], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * growth.progress)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(localizedText("升级进度", "Level progress"))
                .accessibilityValue("\(growth.levelExperience)/\(growth.nextLevelExperience)")
        }
    }

    private var identityCounts: some View {
        HStack(spacing: 0) {
            identityCount(.reviews, localizedText("复盘", "Reviews"), achievementProgress.reviewCount, "text.bubble.fill")
            identityCount(.connections, localizedText("连接", "People"), achievementProgress.peopleCount, "person.2.fill")
            identityCount(.practices, localizedText("练习", "Practice"), achievementProgress.practiceCount, "bolt.fill")
        }
        .padding(.top, 2)
    }

    private func identityCount(_ section: ProfileRecentSection, _ title: String, _ value: Int, _ icon: String) -> some View {
        Button { selectedRecentSection = section } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                    Text(String(format: "%02d", value))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(Color.white)
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.58))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
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
                    .background(SoulTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedText("个性化", "Personalization"))
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
            SoulSectionHeader(title: localizedText("数据与安全", "Data & Security"))

            VStack(spacing: 0) {
                Button {
                    showingAchievements = true
                } label: {
                    SoulMenuRow(title: localizedText("成就徽章", "Achievements"), subtitle: localizedText("查看你的练习成果", "See your practice milestones"), icon: "seal.fill")
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 58).overlay(SoulTheme.cardStroke)
                Button {
                    showingDataVault = true
                } label: {
                    SoulMenuRow(title: localizedText("数据仓库", "Data Vault"), subtitle: localizedText("关系与复盘数据总览", "Overview of relationship and review data"), icon: "externaldrive.fill")
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 58).overlay(SoulTheme.cardStroke)
                Button {
                    showingPrivacySecurity = true
                } label: {
                    SoulMenuRow(title: localizedText("隐私与安全", "Privacy & Security"), subtitle: localizedText("控制数据和权限", "Control your data and permissions"), icon: "lock.shield.fill")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .background(SoulGlassCardBackground())
        }
    }
}

private struct DataVaultSheet: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let people: [RelationshipPerson]

    @State private var stats: DashboardStatsDTO?
    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                SoulBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(localizedText(
                            "这里汇总 SoulMark 为你的账户保存的数据。你可以随时导出一份 JSON 副本。",
                            "This summarizes the data SoulMark stores for your account. You can export a JSON copy at any time."
                        ))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(SoulTheme.secondaryText)

                        HStack(spacing: 10) {
                            vaultMetric(localizedText("人物", "People"), stats?.contactsCount ?? people.count, "person.2.fill")
                            vaultMetric(localizedText("练习", "Practices"), stats?.practicesCount ?? 0, "waveform")
                            vaultMetric(localizedText("复盘", "Reviews"), stats?.reviewsCount ?? 0, "text.bubble.fill")
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                Image(systemName: "archivebox.fill")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .frame(width: 42, height: 42)
                                    .background(
                                        SoulTheme.accent,
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(localizedText("导出内容", "Export Contents"))
                                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                                        .foregroundStyle(SoulTheme.primaryText)
                                    Text(localizedText("你的 SoulMark 数据副本", "Your SoulMark data copy"))
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(SoulTheme.accent)
                                }
                            }

                            Text(localizedText(
                                "包括账户资料、关系人物、事件记录、情景练习和复盘。导出文件可能包含敏感信息，请妥善保管。",
                                "Includes your profile, relationships, events, scenario practices, and reviews. The file may contain sensitive information."
                            ))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(SoulTheme.secondaryText)

                            if let exportURL {
                                ShareLink(item: exportURL) {
                                    Label(localizedText("分享导出文件", "Share Export"), systemImage: "square.and.arrow.up")
                                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                                        .foregroundStyle(Color.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 52)
                                        .background(
                                            SoulTheme.accent,
                                            in: RoundedRectangle(cornerRadius: SoulTheme.controlCornerRadius, style: .continuous)
                                        )
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    createExport()
                                } label: {
                                    if isExporting {
                                        ProgressView()
                                            .tint(Color.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 52)
                                            .background(
                                                SoulTheme.accent,
                                                in: RoundedRectangle(cornerRadius: SoulTheme.controlCornerRadius, style: .continuous)
                                            )
                                    } else {
                                        Label(localizedText("生成数据副本", "Create Data Copy"), systemImage: "arrow.down.doc.fill")
                                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                                            .foregroundStyle(Color.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 52)
                                            .background(
                                                SoulTheme.accent,
                                                in: RoundedRectangle(cornerRadius: SoulTheme.controlCornerRadius, style: .continuous)
                                            )
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(isExporting)
                            }
                        }
                        .padding(18)
                        .background(SoulGlassCardBackground(accented: true))
                    }
                    .padding(18)
                }
            }
            .navigationTitle(localizedText("数据仓库", "Data Vault"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localizedText("完成", "Done")) { dismiss() }
                }
            }
            .task { stats = await session.loadStats() }
            .alert(
                localizedText("导出失败", "Export Failed"),
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button(localizedText("知道了", "OK")) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func vaultMetric(_ title: String, _ value: Int, _ icon: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon).foregroundStyle(SoulTheme.accent)
            Text("\(value)").font(.system(size: 22, weight: .heavy, design: .rounded))
            Text(title).font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(SoulTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(SoulGlassCardBackground())
    }

    private func createExport() {
        isExporting = true
        Task {
            do {
                exportURL = try await session.createDataExportFile()
            } catch {
                errorMessage = error.localizedDescription
            }
            isExporting = false
        }
    }
}

private struct PrivacySecuritySheet: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var microphonePermission = AVAudioApplication.shared.recordPermission
    @State private var showingDeletionVerification = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                SoulBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        securityCard(
                            icon: "key.fill",
                            title: localizedText("登录凭证", "Sign-in credentials"),
                            detail: localizedText(
                                "登录令牌保存在 iOS 钥匙串中，退出登录或删除账户时会从设备移除。",
                                "Your sign-in token is stored in the iOS Keychain and removed on sign-out or account deletion."
                            )
                        )

                        securityCard(
                            icon: "sparkles.rectangle.stack.fill",
                            title: localizedText("AI 数据处理", "AI Data Processing"),
                            detail: localizedText(
                                "情景对话和复盘内容会发送到配置的 AI 服务以生成回复与分析，不用于广告。请避免输入不必要的敏感信息。",
                                "Scenario conversations and reviews are sent to the configured AI service for responses and analysis, not advertising. Avoid unnecessary sensitive details."
                            )
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label(localizedText("麦克风权限", "Microphone Access"), systemImage: "mic.fill")
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                Spacer()
                                Text(permissionText)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(permissionColor)
                            }
                            Text(localizedText(
                                "仅在你发起情景语音练习时采集音频，用于实时转写和生成回复。",
                                "Audio is captured only during a scenario voice session for live transcription and responses."
                            ))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(SoulTheme.secondaryText)

                            if microphonePermission == .undetermined {
                                Button(localizedText("请求麦克风权限", "Request Microphone Access")) {
                                    AVAudioApplication.requestRecordPermission { granted in
                                        Task { @MainActor in
                                            microphonePermission = granted ? .granted : .denied
                                        }
                                    }
                                }
                                .buttonStyle(.bordered)
                            } else if microphonePermission == .denied,
                                      let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                Link(localizedText("前往系统设置", "Open System Settings"), destination: settingsURL)
                                    .buttonStyle(.bordered)
                            }
                        }
                        .padding(16)
                        .background(SoulGlassCardBackground())

                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(SoulTheme.danger)
                                    .frame(width: 42, height: 42)
                                    .background(
                                        SoulTheme.danger.opacity(0.10),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(localizedText("删除账户与数据", "Delete Account and Data"))
                                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                                        .foregroundStyle(SoulTheme.primaryText)
                                    Text(localizedText("永久且无法撤销", "Permanent and irreversible"))
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(SoulTheme.danger)
                                }
                            }

                            Text(localizedText(
                                "这会永久删除账户，以及关联的人物、事件、练习和复盘记录。此操作无法撤销。",
                                "This permanently deletes your account and associated people, events, practices, and reviews. It cannot be undone."
                            ))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(SoulTheme.secondaryText)

                            Button(role: .destructive) {
                                if session.user?.email != nil || session.user?.phoneNumber != nil {
                                    showingDeletionVerification = true
                                } else {
                                    errorMessage = localizedText(
                                        "当前登录方式暂不支持直接删除，请先绑定邮箱或手机号。",
                                        "This sign-in method cannot delete the account directly. Bind an email address or phone number first."
                                    )
                                }
                            } label: {
                                Label(localizedText("删除我的账户", "Delete My Account"), systemImage: "trash.fill")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundStyle(SoulTheme.danger)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                            }
                            .buttonStyle(.plain)
                            .background(
                                SoulTheme.danger.opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(SoulTheme.danger.opacity(0.28), lineWidth: 1)
                            }
                        }
                        .padding(18)
                        .background(SoulGlassCardBackground())
                    }
                    .padding(18)
                }
            }
            .navigationTitle(localizedText("隐私与安全", "Privacy & Security"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localizedText("完成", "Done")) { dismiss() }
                }
            }
            .sheet(isPresented: $showingDeletionVerification) {
                AccountDeletionVerificationSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .alert(
                localizedText("操作失败", "Action Failed"),
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button(localizedText("知道了", "OK")) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func securityCard(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .foregroundStyle(SoulTheme.accent)
                .frame(width: 38, height: 38)
                .background(SoulTheme.accentSoft, in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 15, weight: .heavy, design: .rounded))
                Text(detail)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(SoulTheme.secondaryText)
            }
        }
        .padding(16)
        .background(SoulGlassCardBackground())
    }

    private var permissionText: String {
        switch microphonePermission {
        case .granted: localizedText("已允许", "Allowed")
        case .denied: localizedText("已拒绝", "Denied")
        case .undetermined: localizedText("未询问", "Not Requested")
        @unknown default: localizedText("未知", "Unknown")
        }
    }

    private var permissionColor: Color {
        microphonePermission == .granted ? SoulTheme.energy : SoulTheme.warning
    }

}

private struct AccountDeletionVerificationSheet: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var code = ""
    @State private var isSendingCode = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private var usesPhoneVerification: Bool {
        session.user?.phoneNumber != nil && session.user?.email == nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(SoulTheme.danger)
                        .frame(width: 68, height: 68)
                        .background(SoulTheme.danger.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 7) {
                        Text(localizedText("验证身份后删除", "Verify Before Deleting"))
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(SoulTheme.primaryText)
                        Text(verificationExplanation)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(SoulTheme.secondaryText)
                            .lineSpacing(4)
                    }

                    if usesPhoneVerification {
                        HStack(spacing: 10) {
                            TextField(localizedText("6 位短信验证码", "6-digit SMS code"), text: $code)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .onChange(of: code) { _, value in
                                    code = String(value.filter(\.isNumber).prefix(6))
                                }
                                .soulInsetField()

                            Button {
                                sendCode()
                            } label: {
                                if isSendingCode {
                                    ProgressView()
                                } else {
                                    Text(localizedText("获取验证码", "Send Code"))
                                        .font(.system(size: 13, weight: .bold))
                                }
                            }
                            .frame(minWidth: 96, minHeight: 52)
                            .buttonStyle(.bordered)
                            .disabled(isSendingCode)
                        }
                    } else {
                        SecureField(localizedText("输入账户密码", "Enter account password"), text: $password)
                            .textContentType(.password)
                            .soulInsetField()
                    }

                    Text(localizedText(
                        "确认后，账户以及全部人物、事件、练习和复盘数据将永久删除。",
                        "After confirmation, your account and all people, events, practices, and reviews will be permanently deleted."
                    ))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(SoulTheme.danger)

                    Button(role: .destructive) {
                        deleteAccount()
                    } label: {
                        if isDeleting {
                            ProgressView().tint(.white)
                        } else {
                            Text(localizedText("验证并永久删除", "Verify and Delete Permanently"))
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(SoulTheme.danger, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .buttonStyle(.plain)
                    .disabled(!canDelete || isDeleting)
                }
                .padding(22)
            }
            .background(SoulTheme.pageGradient)
            .navigationTitle(localizedText("删除账户", "Delete Account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedText("取消", "Cancel")) { dismiss() }
                }
            }
            .alert(
                localizedText("操作失败", "Action Failed"),
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button(localizedText("知道了", "OK")) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var canDelete: Bool {
        usesPhoneVerification ? code.count == 6 : !password.isEmpty
    }

    private var verificationExplanation: String {
        if usesPhoneVerification {
            return localizedText(
                "我们会向 \(session.user?.phoneNumber ?? "") 发送短信验证码。",
                "We will send an SMS code to \(session.user?.phoneNumber ?? "")."
            )
        }
        return localizedText(
            "请输入 \(session.user?.email ?? "") 的登录密码确认身份。",
            "Enter the password for \(session.user?.email ?? "") to confirm your identity."
        )
    }

    private func sendCode() {
        isSendingCode = true
        Task {
            defer { isSendingCode = false }
            do {
                try await session.sendAccountDeletionCode()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteAccount() {
        isDeleting = true
        Task {
            do {
                try await session.deleteAccount(
                    password: usesPhoneVerification ? nil : password,
                    code: usesPhoneVerification ? code : nil
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isDeleting = false
            }
        }
    }
}

private enum ProfileRecentSection: String, Identifiable {
    case reviews
    case connections
    case practices

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reviews: localizedText("最近复盘", "Recent Reviews")
        case .connections: localizedText("我的连接", "My Connections")
        case .practices: localizedText("最近练习", "Recent Practice")
        }
    }
}

private struct ProfileRecentActivitySheet: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let section: ProfileRecentSection
    let people: [RelationshipPerson]
    @State private var reviews: [ConversationReviewRecord] = []
    @State private var practices: [PracticeRecord] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                SoulBackground()
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if isLoading && section != .connections {
                            ProgressView().tint(SoulTheme.accent).padding(.top, 36)
                        } else if isEmpty {
                            ContentUnavailableView(
                                localizedText("暂时没有记录", "No records yet"),
                                systemImage: emptyIcon,
                                description: Text(localizedText("完成一次相关操作后会显示在这里。", "Your latest activity will appear here."))
                            )
                            .padding(.top, 24)
                        } else {
                            rows
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle(section.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localizedText("完成", "Done")) { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var rows: some View {
        switch section {
        case .reviews:
            ForEach(reviews.prefix(5)) { review in
                recentRow(
                    icon: review.source.systemImage,
                    title: review.title,
                    subtitle: localizedText("得分 \(review.score) · \(review.date.formatted(date: .abbreviated, time: .omitted))", "Score \(review.score) · \(review.date.formatted(date: .abbreviated, time: .omitted))")
                )
            }
        case .connections:
            ForEach(people.sorted { $0.strength > $1.strength }.prefix(5)) { person in
                recentRow(
                    icon: person.symbol,
                    title: person.name,
                    subtitle: "\(person.category.displayTitle) · \(Int(person.strength * 100))%"
                )
            }
        case .practices:
            ForEach(practices.prefix(5)) { practice in
                recentRow(
                    icon: "waveform.and.mic",
                    title: practice.participantName,
                    subtitle: "\(practice.modeTitle) · \(practice.createdAt.formatted(date: .abbreviated, time: .shortened))"
                )
            }
        }
    }

    private func recentRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(SoulTheme.accent)
                .frame(width: 42, height: 42)
                .background(SoulTheme.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(SoulTheme.primaryText)
                Text(subtitle).font(.system(size: 11, weight: .semibold)).foregroundStyle(SoulTheme.secondaryText)
            }
            Spacer()
        }
        .padding(14)
        .background(SoulGlassCardBackground())
    }

    private var isEmpty: Bool {
        switch section {
        case .reviews: reviews.isEmpty
        case .connections: people.isEmpty
        case .practices: practices.isEmpty
        }
    }

    private var emptyIcon: String {
        switch section {
        case .reviews: "text.bubble"
        case .connections: "person.2"
        case .practices: "waveform"
        }
    }

    @MainActor
    private func load() async {
        switch section {
        case .reviews: reviews = await session.loadReviews() ?? []
        case .practices: practices = await session.loadPractices() ?? []
        case .connections: break
        }
        isLoading = false
    }
}

private struct AchievementsSheet: View {
    @EnvironmentObject private var session: AppSession
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

                    if let growth = session.growthState.snapshot {
                        GrowthMilestoneSection(growth: growth)
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
                RoundedRectangle(cornerRadius: 16, style: .continuous)
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
    @Bindable private var preferences = SoulPreferencesStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var tutorialReplay = SoulTutorialReplayState()

    var body: some View {
        NavigationStack {
            ZStack {
                SoulBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        themePreview

                        SettingsGroup(title: localizedText("语言", "Language"), subtitle: localizedText("选择界面主要语言", "Choose the primary interface language")) {
                            Picker(localizedText("语言", "Language"), selection: $preferences.language) {
                                Text("中文").tag("zh")
                                Text("English").tag("en")
                            }
                            .pickerStyle(.segmented)
                        }

                        SettingsGroup(title: localizedText("能量色", "Energy Color"), subtitle: localizedText("选择适合你的简洁信号色", "Choose a clean signal color that fits you")) {
                            HStack(spacing: 10) {
                                ThemeChoiceButton(
                                    title: localizedText("深空蓝", "Orbit Blue"),
                                    systemImage: "circle.hexagongrid.fill",
                                    color: Color(red: 0.04, green: 0.50, blue: 0.90),
                                    isSelected: preferences.genderTheme == "male"
                                ) {
                                    preferences.genderTheme = "male"
                                }

                                ThemeChoiceButton(
                                    title: localizedText("樱花粉", "Sakura Pink"),
                                    systemImage: "sparkle",
                                    color: Color(red: 0.94, green: 0.30, blue: 0.56),
                                    isSelected: preferences.genderTheme == "female"
                                ) {
                                    preferences.genderTheme = "female"
                                }

                                ThemeChoiceButton(
                                    title: localizedText("松石绿", "Jade Green"),
                                    systemImage: "leaf.fill",
                                    color: Color(red: 0.08, green: 0.48, blue: 0.36),
                                    isSelected: preferences.genderTheme == "green"
                                ) {
                                    preferences.genderTheme = "green"
                                }
                            }
                        }

                        SettingsGroup(title: localizedText("显示模式", "Appearance"), subtitle: localizedText("跟随时间，或固定日间与夜间", "Follow time, or keep day or night mode")) {
                            Picker(localizedText("模式", "Mode"), selection: $preferences.appearanceMode) {
                                Text(localizedText("自动", "Auto")).tag("auto")
                                Text(localizedText("日间", "Day")).tag("day")
                                Text(localizedText("夜间", "Night")).tag("night")
                            }
                            .pickerStyle(.segmented)
                        }

                        SettingsGroup(
                            title: localizedText("新手指引", "New User Guide"),
                            subtitle: localizedText("重新查看四个核心功能", "Review the four core features")
                        ) {
                            Button {
                                tutorialReplay.open()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "questionmark.circle.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(SoulTheme.accent)
                                    Text(localizedText("重新查看新手指引", "View the guide again"))
                                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                                        .foregroundStyle(SoulTheme.primaryText)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(SoulTheme.tertiaryText)
                                }
                                .padding(.horizontal, 12)
                                .frame(minHeight: 46)
                                .background(
                                    SoulTheme.subtleFill,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
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
                                    .background(SoulTheme.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 24)
                }
            }
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
        .fullScreenCover(isPresented: Binding(
            get: { tutorialReplay.isPresented },
            set: { if !$0 { tutorialReplay.close() } }
        )) {
            SoulTutorialView(mode: .replay(onClose: { tutorialReplay.close() }))
        }
    }

    private var themePreview: some View {
        ZStack(alignment: .bottomTrailing) {
            SoulVisorPanelBackground()

            VStack(alignment: .leading, spacing: 8) {
                SoulStatusPill(text: localizedText("实时预览", "LIVE PREVIEW"), systemImage: "eye.fill")

                Spacer()

                Text(themePreviewTitle)
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

    private var themePreviewTitle: String {
        switch preferences.genderTheme {
        case "female": localizedText("樱花粉信号", "Sakura Pink Signal")
        case "green": localizedText("松石绿信号", "Jade Green Signal")
        default: localizedText("深空蓝信号", "Orbit Blue Signal")
        }
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
            VStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color)

                Text(title)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(SoulTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(isSelected ? color.opacity(0.12) : SoulTheme.subtleFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(isSelected ? color.opacity(0.48) : .clear, lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isSelected ? color : SoulTheme.tertiaryText)
                    .padding(8)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SoulActionCard: View {
    let index: String
    let title: String
    let subtitle: String
    let icon: String
    var iconAsset: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Group {
                        if let iconAsset {
                            SoulSlotIcon(asset: iconAsset)
                                .padding(8)
                        } else {
                            Image(systemName: icon)
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(SoulTheme.accent)
                        }
                    }
                    .frame(width: 42, height: 42)
                    .background(SoulTheme.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

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
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(14)
            .background(SoulGlassCardBackground())
        }
        .buttonStyle(.plain)
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
                .background(SoulTheme.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
