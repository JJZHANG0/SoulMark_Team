import SwiftUI

struct SoulTutorialText: Hashable, Sendable {
    let zh: String
    let en: String

    var localized: String { localizedText(zh, en) }
}

struct SoulTutorialPage: Identifiable, Hashable, Sendable {
    let id: String
    let index: Int
    let title: SoulTutorialText
    let subtitle: SoulTutorialText
    let body: SoulTutorialText
    let icon: String
    let features: [SoulTutorialText]

    var buttonTitle: SoulTutorialText {
        index == 3
            ? SoulTutorialText(zh: "开始使用", en: "Start using SoulMark")
            : SoulTutorialText(zh: "下一步", en: "Next")
    }

    static let all: [SoulTutorialPage] = [
        SoulTutorialPage(
            id: "relationship-map",
            index: 0,
            title: .init(zh: "关系图谱", en: "Relationship Map"),
            subtitle: .init(zh: "把重要的人放进你的关系世界", en: "Bring important people into your relationship world"),
            body: .init(
                zh: "点击图谱中的“添加”，填写名字、关系类型和备注，就能建立一个关系人物。",
                en: "Tap Add in the map, then enter a name, relationship type, and note to create a person."
            ),
            icon: "person.2.fill",
            features: [
                .init(zh: "点击添加", en: "Tap Add"),
                .init(zh: "填写人物信息", en: "Enter details"),
                .init(zh: "建立关系人物", en: "Create the person")
            ]
        ),
        SoulTutorialPage(
            id: "scenario-simulation",
            index: 1,
            title: .init(zh: "情景模拟", en: "Scenario Practice"),
            subtitle: .init(zh: "先选对人，再练对话", en: "Choose the person, then practice the moment"),
            body: .init(
                zh: "你可以随时切换对象，也可以切换情景／提示词，让 AI 按所选人物和情景回应。",
                en: "Switch the person or the scenario prompt at any time, and AI will respond as that person in that situation."
            ),
            icon: "bubble.left.and.bubble.right.fill",
            features: [
                .init(zh: "切换对象", en: "Switch person"),
                .init(zh: "切换情景／提示词", en: "Switch scenario prompt"),
                .init(zh: "与 AI 练习", en: "Practice with AI")
            ]
        ),
        SoulTutorialPage(
            id: "conversation-review",
            index: 2,
            title: .init(zh: "沟通复盘", en: "Conversation Review"),
            subtitle: .init(zh: "把一次沟通变成下一次进步", en: "Turn one conversation into your next improvement"),
            body: .init(
                zh: "用文字、聊天截图或语音记录沟通，保存后会获得表达分析和改进建议。",
                en: "Add text, chat screenshots, or voice. After saving, you will receive communication analysis and practical suggestions."
            ),
            icon: "doc.text.magnifyingglass",
            features: [
                .init(zh: "文字", en: "Text"),
                .init(zh: "聊天截图", en: "Screenshot"),
                .init(zh: "语音", en: "Voice")
            ]
        ),
        SoulTutorialPage(
            id: "relationship-growth",
            index: 3,
            title: .init(zh: "关系成长", en: "Relationship Growth"),
            subtitle: .init(zh: "持续练习，见证你的关系能力", en: "Keep practicing and see your relationship skills grow"),
            body: .init(
                zh: "复盘和有效 AI 对话会增加经验，每级所需经验逐步提高；长期未使用时经验会衰减。升级可获得称号，等级里程碑会收进“我的 → 成就徽章”。",
                en: "Reviews and meaningful AI chats add experience, while each level requires more. Experience decays after long inactivity. Levels unlock titles, and milestone badges live in Profile → Achievement Badges."
            ),
            icon: "chart.line.uptrend.xyaxis",
            features: [
                .init(zh: "复盘与对话得经验", en: "Earn XP from reviews and chats"),
                .init(zh: "升级获得称号", en: "Unlock level titles"),
                .init(zh: "成就徽章", en: "Achievement badges")
            ]
        )
    ]
}

enum SoulTutorialMode {
    case required(startStep: Int, onAdvance: @MainActor (Int) async -> Bool)
    case replay(onClose: @MainActor () -> Void)
}

struct SoulTutorialView: View {
    let mode: SoulTutorialMode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: Int
    @State private var isSubmitting = false
    @State private var showsRetryMessage = false

    init(mode: SoulTutorialMode) {
        self.mode = mode
        let initialStep: Int
        switch mode {
        case .required(let startStep, _):
            initialStep = min(max(startStep, 0), SoulTutorialPage.all.count - 1)
        case .replay:
            initialStep = 0
        }
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        ZStack {
            SoulBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    pageContent
                    Spacer(minLength: 112)
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            actionArea
        }
    }

    private var page: SoulTutorialPage { SoulTutorialPage.all[step] }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("SOUL GUIDE / 0\(step + 1)")
                    .font(.caption2.weight(.heavy).monospaced())
                    .foregroundStyle(SoulTheme.energy)
                Text(localizedText("认识 SoulMark", "Meet SoulMark"))
                    .font(.title2.weight(.black))
                    .foregroundStyle(SoulTheme.primaryText)
            }
            Spacer()
            if case .replay(let onClose) = mode {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.bold))
                        .frame(width: 44, height: 44)
                        .background(SoulTheme.cardFill, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(SoulTheme.primaryText)
                .accessibilityLabel(localizedText("关闭新手指引", "Close tutorial"))
            } else {
                Text("\(step + 1)/4")
                    .font(.subheadline.weight(.heavy).monospaced())
                    .foregroundStyle(SoulTheme.secondaryText)
            }
        }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            ZStack {
                Circle()
                    .fill(SoulTheme.accentSoft)
                    .frame(width: 108, height: 108)
                Image(systemName: page.icon)
                    .font(.system(size: 43, weight: .semibold))
                    .foregroundStyle(SoulTheme.accent)
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text(page.title.localized)
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(SoulTheme.primaryText)
                Text(page.subtitle.localized)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SoulTheme.accent)
                Text(page.body.localized)
                    .font(.body)
                    .foregroundStyle(SoulTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: 12) {
                ForEach(Array(page.features.enumerated()), id: \.offset) { index, feature in
                    SoulTutorialFeatureRow(
                        number: index + 1,
                        title: feature.localized,
                        isLast: index == page.features.count - 1
                    )
                }
            }
            .padding(16)
            .background(SoulGlassCardBackground())

            if showsRetryMessage {
                Label(
                    localizedText("进度没有保存，请重试。", "Progress was not saved. Please try again."),
                    systemImage: "exclamationmark.arrow.triangle.2.circlepath"
                )
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SoulTheme.danger)
                .accessibilityAddTraits(.isStaticText)
            }
        }
        .id(page.id)
        .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
    }

    private var actionArea: some View {
        VStack(spacing: 10) {
            ProgressView(value: Double(step + 1), total: 4)
                .tint(SoulTheme.accent)

            Button(action: advance) {
                HStack(spacing: 10) {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text(page.buttonTitle.localized)
                        Image(systemName: step == 3 ? "checkmark" : "arrow.right")
                    }
                }
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54)
                .background(SoulTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
            .accessibilityHint(localizedText("进入下一页", "Continue to the next page"))
        }
        .frame(maxWidth: 680)
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private func advance() {
        guard !isSubmitting else { return }
        showsRetryMessage = false
        switch mode {
        case .required(_, let onAdvance):
            isSubmitting = true
            Task { @MainActor in
                let succeeded = await onAdvance(step + 1)
                isSubmitting = false
                guard succeeded else {
                    showsRetryMessage = true
                    return
                }
                if step < 3 { move(to: step + 1) }
            }
        case .replay(let onClose):
            if step == 3 {
                onClose()
            } else {
                move(to: step + 1)
            }
        }
    }

    private func move(to newStep: Int) {
        if reduceMotion {
            step = newStep
        } else {
            withAnimation(.smooth(duration: 0.32)) {
                step = newStep
            }
        }
    }
}

private struct SoulTutorialFeatureRow: View {
    let number: Int
    let title: String
    let isLast: Bool

    var body: some View {
        HStack(spacing: 13) {
            Text(String(number))
                .font(.caption.weight(.black).monospaced())
                .foregroundStyle(SoulTheme.accent)
                .frame(width: 30, height: 30)
                .background(SoulTheme.accentSoft, in: Circle())
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(SoulTheme.primaryText)
            Spacer(minLength: 0)
            Image(systemName: isLast ? "checkmark.circle.fill" : "arrow.right")
                .foregroundStyle(isLast ? SoulTheme.success : SoulTheme.tertiaryText)
        }
        .padding(15)
        .background(
            SoulTheme.subtleFill,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}
