import SwiftUI

struct GrowthProgressCard: View {
    let state: GrowthLoadState
    var onRetry: () -> Void = {}
    @State private var showingRules = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(localizedText("自我成长", "Your Growth"), systemImage: "sparkles")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(SoulTheme.primaryText)
                Spacer()
                Button { showingRules.toggle() } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(SoulTheme.secondaryText)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedText("经验与衰减规则", "Experience and inactivity rules"))
            }
            switch state {
            case .loading:
                HStack(spacing: 10) {
                    ProgressView()
                    Text(localizedText("正在同步成长记录…", "Syncing your progress…"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(SoulTheme.secondaryText)
                }.frame(minHeight: 80)
            case .failed:
                VStack(alignment: .leading, spacing: 12) {
                    Text(localizedText("成长记录暂时无法同步", "Progress is temporarily unavailable"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(SoulTheme.primaryText)
                    Text(localizedText("连接恢复后即可查看经验、等级和称号。", "Reconnect to see your experience, level and title."))
                        .font(.system(size: 12))
                        .foregroundStyle(SoulTheme.secondaryText)
                    Button(localizedText("重新同步", "Try again"), action: onRetry)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(SoulTheme.accent)
                        .padding(.vertical, 8)
                }
            case .loaded(let growth):
                HStack(spacing: 10) {
                    rewardPill(localizedText("复盘 +30", "Review +30"), icon: "text.bubble")
                    rewardPill(localizedText("对话 +5 / 轮", "Chat +5 / turn"), icon: "waveform")
                    rewardPill(localizedText("挑战 +20", "Challenge +20"), icon: "flag.checkered")
                }
                if let next = GrowthMilestone.all.first(where: { $0.level > growth.level }) {
                    Text(localizedText("下个称号：Lv.\(next.level) · \(next.title)", "Next title: Lv.\(next.level) · \(next.title)"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SoulTheme.secondaryText)
                }
                Text(localizedText("今日聊天经验 \(growth.chatExperienceToday) / 50", "Chat EXP today: \(growth.chatExperienceToday) / 50"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SoulTheme.secondaryText)
            }
            Text(localizedText("连续 7 天未使用不扣经验，第 8 天起每日 −10", "7 inactive days are free; −10 EXP/day from day 8"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(SoulTheme.tertiaryText)
            if showingRules {
                Text(localizedText(
                    "复盘成功保存 +30 EXP；首次完成自我觉察挑战 +20 EXP；聊天每个完整问答 +5 EXP，结束并保存后结算，每日最多 50。升级依次需要 100、150、200… EXP。打开 App 即重新开始 7 天宽限期，回归时先结算离开期间的扣减。经验最低为 0，等级和当前称号可能下降，已解锁的等级徽章永久保留。按新加坡日期结算。",
                    "Saved reviews earn 30 EXP. Each complete chat turn earns 5 EXP when the call is saved, up to 50 daily. Levels require 100, 150, 200… EXP. Opening the app restarts a 7-day grace period after settling any inactivity loss. EXP cannot fall below zero. Levels and current titles may drop; earned level badges stay unlocked. Days follow Singapore time."
                ))
                .font(.system(size: 12))
                .foregroundStyle(SoulTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
            }
        }
        .padding(18)
        .background(SoulGlassCardBackground(accented: true))
    }

    private func rewardPill(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(SoulTheme.accent)
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(SoulTheme.accentSoft, in: Capsule())
    }
}

struct GrowthMilestoneSection: View {
    let growth: GrowthSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SoulSectionHeader(title: localizedText("成长称号", "Growth Milestones"), detail: "\(growth.unlockedMilestones.count) / 5")
            ForEach(GrowthMilestone.all) { milestone in
                let unlocked = growth.peakLevel >= milestone.level
                HStack(spacing: 12) {
                    Image(systemName: unlocked ? milestone.icon : "lock.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(unlocked ? SoulTheme.accent : SoulTheme.tertiaryText)
                        .frame(width: 44, height: 44)
                        .background(SoulTheme.subtleFill, in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(milestone.title).font(.system(size: 15, weight: .bold))
                            .foregroundStyle(SoulTheme.primaryText)
                        Text(unlocked ? localizedText("已解锁 · 永久保留", "Unlocked · yours to keep") : localizedText("达到 Lv.\(milestone.level) 解锁", "Unlock at Lv.\(milestone.level)"))
                            .font(.system(size: 11)).foregroundStyle(SoulTheme.secondaryText)
                    }
                    Spacer()
                    Text("Lv.\(milestone.level)").font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(SoulTheme.secondaryText)
                }
            }
        }.padding(16).background(SoulGlassCardBackground())
    }
}

struct GrowthFeedbackOverlay: View {
    @EnvironmentObject private var session: AppSession
    var body: some View {
        VStack(spacing: 8) {
            if let error = session.practiceSaveError {
                HStack {
                    Text(error).font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button(localizedText("重试", "Retry")) { Task { await session.retryPendingPractices() } }
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(SoulTheme.primaryText)
                .padding(14).background(SoulGlassCardBackground())
            }
            if let feedback = session.growthFeedback {
                HStack(spacing: 10) {
                    Image(systemName: feedback.newLevel == nil ? "sparkles" : "arrow.up.circle.fill")
                        .foregroundStyle(SoulTheme.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        if let level = feedback.newLevel {
                            Text(localizedText("升级了！Lv.\(level)", "Level up! Lv.\(level)"))
                        }
                        if feedback.awarded > 0 { Text("+\(feedback.awarded) EXP") }
                        if feedback.decayed > 0 {
                            Text(localizedText("闲置期间 −\(feedback.decayed) EXP，欢迎回来", "−\(feedback.decayed) EXP while away. Welcome back."))
                        }
                    }.font(.system(size: 13, weight: .bold))
                    Spacer()
                    Button { session.growthFeedback = nil } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(localizedText("关闭提示", "Dismiss"))
                }
                .foregroundStyle(SoulTheme.primaryText)
                .padding(14).background(SoulGlassCardBackground(accented: true))
                .task(id: feedback.id) {
                    try? await Task.sleep(for: .seconds(6))
                    if !Task.isCancelled, session.growthFeedback?.id == feedback.id { session.growthFeedback = nil }
                }
            }
        }.padding(.horizontal, 18).padding(.top, 6)
    }
}
