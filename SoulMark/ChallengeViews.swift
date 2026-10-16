//
//  ChallengeViews.swift
//  SoulMark
//
//  Self-awareness challenges: discover, start, step through, complete.
//

import SwiftUI

/// Compact entry card used on Home and Profile.
struct ChallengeHubCard: View {
    @EnvironmentObject private var session: AppSession
    @State private var list: ChallengeListDTO?
    @State private var failed = false
    @State private var showingHub = false
    @State private var openKey: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SoulSectionHeader(
                title: localizedText("自我觉察挑战", "Self-awareness Challenges"),
                detail: list.map { "\($0.completedCount) / \($0.challenges.count)" } ?? "—"
            )
            Button { openFeatured() } label: { featured }
                .buttonStyle(.plain)
            Button { showingHub = true } label: {
                HStack {
                    Text(localizedText("浏览全部挑战", "Browse all challenges"))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .heavy))
                }
                .foregroundStyle(SoulTheme.accent)
                .padding(.horizontal, 16).frame(height: 44)
                .background(SoulGlassCardBackground())
            }
            .buttonStyle(.plain)
        }
        .task(id: session.challengesRevision) { await load() }
        .sheet(isPresented: $showingHub) {
            ChallengeHubSheet()
                .environmentObject(session)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: Binding(get: { openKey.map(ChallengeKey.init) }, set: { openKey = $0?.id })) { item in
            NavigationStack { ChallengeDetailView(key: item.id) }
                .environmentObject(session)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var featuredChallenge: ChallengeSummaryDTO? {
        guard let items = list?.challenges else { return nil }
        return items.first(where: \.isActive) ?? items.first(where: { $0.completionCount == 0 }) ?? items.first
    }

    private func openFeatured() {
        if let featuredChallenge { openKey = featuredChallenge.key } else { showingHub = true }
    }

    @ViewBuilder
    private var featured: some View {
        if let item = featuredChallenge {
            HStack(spacing: 14) {
                ChallengeIcon(name: item.icon)
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.isActive ? localizedText("进行中", "In progress") : localizedText("今日推荐", "Suggested"))
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(SoulTheme.energy)
                    Text(item.title)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(SoulTheme.primaryText)
                    Text(item.subtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(SoulTheme.secondaryText)
                        .lineLimit(2)
                    if item.isActive {
                        ChallengeProgressBar(progress: item.progress).padding(.top, 4)
                    } else {
                        Text("\(item.modelTitle) · \(item.timeLabel)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(SoulTheme.tertiaryText)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(SoulTheme.accent)
            }
            .padding(16)
            .background(SoulGlassCardBackground(accented: true))
        } else {
            HStack(spacing: 10) {
                if failed {
                    Image(systemName: "wifi.exclamationmark").foregroundStyle(SoulTheme.secondaryText)
                    Text(localizedText("挑战暂时无法加载，点我重试", "Challenges unavailable. Tap to retry"))
                } else {
                    ProgressView()
                    Text(localizedText("正在准备挑战…", "Preparing challenges…"))
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(SoulTheme.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(SoulGlassCardBackground())
            .onTapGesture { Task { await load() } }
        }
    }

    private func load() async {
        do { list = try await session.loadChallenges(); failed = false } catch { failed = true }
    }
}

private struct ChallengeKey: Identifiable { let id: String }

struct ChallengeHubSheet: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var list: ChallengeListDTO?
    @State private var errorMessage: String?
    @State private var filter: String = "all"
    @AppStorage("soulMarkLanguage") private var language = "zh"

    private var filters: [(String, String)] {
        _ = language
        return [
            ("all", localizedText("全部", "All")),
            ("johari", localizedText("乔哈里视窗", "Johari")),
            ("values", localizedText("价值与自我", "Values")),
            ("emotional_intelligence", localizedText("情绪智力", "Emotion")),
            ("awareness_wheel", localizedText("觉察之轮", "Awareness")),
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SoulBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(localizedText("通过一个个小行动，在关系里认识自己。", "Small actions to see yourself through your relationships."))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(SoulTheme.secondaryText)
                        if let list {
                            HStack(spacing: 10) {
                                statPill("\(list.activeCount)", localizedText("进行中", "Active"))
                                statPill("\(list.completedCount)", localizedText("已完成", "Done"))
                                statPill("\(list.challenges.count)", localizedText("全部", "Total"))
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(filters, id: \.0) { item in
                                        Button { filter = item.0 } label: {
                                            Text(item.1)
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(filter == item.0 ? Color.white : SoulTheme.primaryText)
                                                .padding(.horizontal, 12).frame(height: 32)
                                                .background(filter == item.0 ? SoulTheme.accent : SoulTheme.subtleFill, in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            ForEach(list.challenges.filter { filter == "all" || $0.model == filter }) { item in
                                NavigationLink {
                                    ChallengeDetailView(key: item.key)
                                } label: {
                                    ChallengeRow(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        } else if let errorMessage {
                            VStack(spacing: 12) {
                                Text(errorMessage).foregroundStyle(SoulTheme.secondaryText)
                                Button(localizedText("重试", "Retry")) { Task { await load() } }
                                    .foregroundStyle(SoulTheme.accent)
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                        } else {
                            ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle(localizedText("自我觉察挑战", "Challenges"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localizedText("完成", "Done")) { dismiss() }
                }
            }
            .task(id: session.challengesRevision) { await load() }
        }
    }

    private func statPill(_ value: String, _ title: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(SoulTheme.accent)
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(SoulTheme.secondaryText)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(SoulGlassCardBackground())
    }

    private func load() async {
        do { list = try await session.loadChallenges(); errorMessage = nil } catch { errorMessage = error.localizedDescription }
    }
}

private struct ChallengeRow: View {
    let item: ChallengeSummaryDTO
    var body: some View {
        HStack(spacing: 14) {
            ChallengeIcon(name: item.icon)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(SoulTheme.primaryText)
                    if item.completionCount > 0 {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(SoulTheme.success).font(.system(size: 13))
                    }
                }
                Text(item.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SoulTheme.secondaryText)
                    .lineLimit(2)
                if item.isActive {
                    ChallengeProgressBar(progress: item.progress)
                } else {
                    Text("\(item.modelTitle) · \(item.timeLabel) · +\(item.rewardExperience) EXP")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(SoulTheme.tertiaryText)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(SoulTheme.tertiaryText)
        }
        .padding(14)
        .background(SoulGlassCardBackground(accented: item.isActive))
    }
}

struct ChallengeIcon: View {
    let name: String
    var body: some View {
        Image(systemName: name)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(SoulTheme.accent)
            .frame(width: 50, height: 50)
            .background(SoulTheme.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ChallengeProgressBar: View {
    let progress: Double
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(SoulTheme.subtleFill)
                Capsule()
                    .fill(LinearGradient(colors: [SoulTheme.accent, SoulTheme.energy], startPoint: .leading, endPoint: .trailing))
                    .frame(width: proxy.size.width * max(0.04, min(1, progress)))
            }
        }
        .frame(height: 6)
    }
}

struct ChallengeDetailView: View {
    @EnvironmentObject private var session: AppSession
    let key: String
    @State private var detail: ChallengeDetailDTO?
    @State private var draft = ""
    @State private var rating: Int?
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var celebration: Int?

    var body: some View {
        ZStack {
            SoulBackground()
            ScrollView(showsIndicators: false) {
                if let detail {
                    VStack(alignment: .leading, spacing: 18) {
                        header(detail)
                        if let celebration { completionCard(awarded: celebration) }
                        else if detail.summary.isCompleted { completionCard(awarded: nil) }
                        ForEach(detail.steps) { step in stepCard(step, detail: detail) }
                        footer(detail)
                    }
                    .padding(18)
                    .padding(.bottom, 40)
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(SoulTheme.secondaryText).padding(40)
                } else {
                    ProgressView().padding(80)
                }
            }
        }
        .navigationTitle(detail?.summary.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert(localizedText("还差一点", "Almost"), isPresented: Binding(get: { errorMessage != nil && detail != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button(localizedText("好的", "OK")) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func header(_ detail: ChallengeDetailDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ChallengeIcon(name: detail.summary.icon)
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.summary.title)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(SoulTheme.primaryText)
                    Text("\(detail.summary.modelTitle) · \(detail.summary.dimensionTitle)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SoulTheme.energy)
                }
            }
            Text(detail.intro)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(SoulTheme.primaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                metaPill(detail.summary.timeLabel, icon: "clock")
                metaPill("\(detail.summary.stepCount) 步", icon: "list.number")
                metaPill("+\(detail.summary.rewardExperience) EXP", icon: "sparkles")
            }
            if detail.summary.isActive {
                ChallengeProgressBar(progress: detail.summary.progress)
            }
            Text(detail.completionRule)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SoulTheme.tertiaryText)
        }
        .padding(18)
        .background(SoulGlassCardBackground(accented: true))
    }

    private func metaPill(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(SoulTheme.accent)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(SoulTheme.accentSoft, in: Capsule())
    }

    @ViewBuilder
    private func stepCard(_ step: ChallengeStepDTO, detail: ChallengeDetailDTO) -> some View {
        let isCurrent = detail.currentStepIndex == step.index
        let locked = !step.isAnswered && !isCurrent
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("\(step.index + 1)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(step.isAnswered || isCurrent ? Color.white : SoulTheme.tertiaryText)
                    .frame(width: 28, height: 28)
                    .background(step.isAnswered ? SoulTheme.success : (isCurrent ? SoulTheme.accent : SoulTheme.subtleFill), in: Circle())
                Text(step.title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(locked ? SoulTheme.tertiaryText : SoulTheme.primaryText)
                Spacer()
                if step.isAnswered { Image(systemName: "checkmark").foregroundStyle(SoulTheme.success) }
                if locked { Image(systemName: "lock.fill").font(.system(size: 12)).foregroundStyle(SoulTheme.tertiaryText) }
            }
            if !locked {
                Text(step.instruction)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SoulTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if isCurrent {
                Text(step.prompt)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(SoulTheme.primaryText)
                if step.isRating {
                    HStack(spacing: 10) {
                        ForEach(1...5, id: \.self) { value in
                            Button { rating = value } label: {
                                Text("\(value)")
                                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                                    .foregroundStyle(rating == value ? Color.white : SoulTheme.primaryText)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(rating == value ? SoulTheme.accent : SoulTheme.subtleFill, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    TextEditor(text: $draft)
                        .scrollContentBackground(.hidden)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(minHeight: 110)
                        .padding(8)
                        .background(
                            SoulTheme.cardFill,
                            in: RoundedRectangle(cornerRadius: SoulTheme.controlCornerRadius, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: SoulTheme.controlCornerRadius, style: .continuous)
                                .stroke(SoulTheme.cardStroke, lineWidth: 1)
                        )
                    if step.minChars > 0 {
                        Text("\(draft.trimmingCharacters(in: .whitespacesAndNewlines).count) / 至少 \(step.minChars) 字")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(SoulTheme.tertiaryText)
                    }
                }
                Button { Task { await submit(step) } } label: {
                    HStack {
                        if isWorking { ProgressView().tint(.white) }
                        Text(step.index == detail.steps.count - 1 ? localizedText("完成挑战", "Finish") : localizedText("记下，下一步", "Save & continue"))
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(canSubmit(step) ? SoulTheme.accent : SoulTheme.tertiaryText, in: RoundedRectangle(cornerRadius: SoulTheme.controlCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit(step) || isWorking)
            } else if let response = step.response, !response.isEmpty {
                Text("“\(response)”")
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundStyle(SoulTheme.primaryText)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SoulTheme.subtleFill, in: RoundedRectangle(cornerRadius: 12))
            } else if let value = step.rating {
                Text(localizedText("自评：\(value) / 5", "Self-rating: \(value) / 5"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(SoulTheme.accent)
            }
        }
        .padding(16)
        .background(SoulGlassCardBackground(accented: isCurrent))
        .opacity(locked ? 0.6 : 1)
    }

    @ViewBuilder
    private func footer(_ detail: ChallengeDetailDTO) -> some View {
        if detail.summary.status == "not_started" || detail.summary.isCompleted {
            Button { Task { await start() } } label: {
                Text(detail.summary.isCompleted ? localizedText("再来一次", "Do it again") : localizedText("开始挑战", "Start challenge"))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(SoulTheme.accent, in: RoundedRectangle(cornerRadius: SoulTheme.controlCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
        }
    }

    private func completionCard(awarded: Int?) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30))
                .foregroundStyle(SoulTheme.energy)
            VStack(alignment: .leading, spacing: 4) {
                Text(localizedText("挑战完成", "Challenge complete"))
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                Text(awarded.map { $0 > 0 ? "+\($0) EXP · 已写入你的自我认知报告" : "已写入你的自我认知报告" } ?? "你的反思已收进自我认知报告")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(18)
        .background(SoulVisorPanelBackground())
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func canSubmit(_ step: ChallengeStepDTO) -> Bool {
        step.isRating ? rating != nil : draft.trimmingCharacters(in: .whitespacesAndNewlines).count >= max(1, step.minChars)
    }

    private func load() async {
        do { detail = try await session.loadChallenge(key: key) } catch { errorMessage = error.localizedDescription }
    }

    private func start() async {
        isWorking = true
        defer { isWorking = false }
        do {
            detail = try await session.startChallenge(key: key)
            celebration = nil
        } catch { errorMessage = error.localizedDescription }
    }

    private func submit(_ step: ChallengeStepDTO) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await session.submitChallengeStep(
                key: key, index: step.index,
                response: draft.trimmingCharacters(in: .whitespacesAndNewlines),
                rating: step.isRating ? rating : nil
            )
            detail = result.challenge
            draft = ""
            rating = nil
            if result.challenge.summary.isCompleted { celebration = result.awardedExperience }
        } catch { errorMessage = error.localizedDescription }
    }
}
