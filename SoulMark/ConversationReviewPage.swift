//
//  ConversationReviewPage.swift
//  SoulMark
//

import SwiftUI

struct ConversationReviewPage: View {
    @EnvironmentObject private var session: AppSession
    @State private var records: [ConversationReviewRecord] = []
    @State private var isAddingRecord = false
    @State private var selectedSource: ReviewSource?
    @State private var searchText = ""
    let onRecordCountChange: (Int) -> Void

    init(onRecordCountChange: @escaping (Int) -> Void = { _ in }) {
        self.onRecordCountChange = onRecordCountChange
    }

    private var filteredRecords: [ConversationReviewRecord] {
        records.filter { $0.matches(source: selectedSource, query: searchText) }
    }

    private var averageScore: Int {
        guard !filteredRecords.isEmpty else { return 0 }
        return filteredRecords.map(\.score).reduce(0, +) / filteredRecords.count
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            SoulBackground()

            VStack(spacing: 0) {
                SoulPageHeader(
                    eyebrow: "Reflect / 04",
                    title: localizedText("沟通复盘", "Conversation Review"),
                    subtitle: localizedText("回看表达如何发生，也看见下一次可以怎么说。", "See how your words landed and what you can try next time.")
                ) {
                    SoulIconButton(systemImage: "plus", isEmphasized: true) {
                        isAddingRecord = true
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 8)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {
                        ReviewSignalPanel(averageScore: averageScore, resultCount: filteredRecords.count)

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
                                    onRecordCountChange(records.count)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 126)
                }
            }
        }
        .sheet(isPresented: $isAddingRecord) {
            AddReviewRecordSheet { title, source, transcript in
                let record = ConversationReviewRecord.make(
                    title: title,
                    source: source,
                    transcript: transcript
                )
                records.insert(record, at: 0)
                onRecordCountChange(records.count)
                Task { await session.recordReview(record) }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task {
            if let syncedRecords = await session.loadReviews() {
                records = syncedRecords
                onRecordCountChange(records.count)
            }
        }
    }
}

private struct ReviewSignalPanel: View {
    let averageScore: Int
    let resultCount: Int

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(localizedText("表达清晰度", "CLARITY SIGNAL"))
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(SoulTheme.energy)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(averageScore)")
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)

                    Text("/ 100")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.40))
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 1, height: 64)

            VStack(alignment: .leading, spacing: 10) {
                Label(localizedText("\(resultCount) 条复盘", "\(resultCount) reviews"), systemImage: "text.bubble.fill")
                Label(localizedText("信号持续上升", "Signal trending up"), systemImage: "arrow.up.right")
            }
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.72))

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 126)
        .background(SoulVisorPanelBackground())
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
                .foregroundStyle(SoulTheme.accent)
                .frame(width: 36, height: 36)
                .background(SoulTheme.accentSoft, in: Circle())

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
        .background(SoulGlassCardBackground())
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
            .background(SoulTheme.subtleFill, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .background(SoulGlassCardBackground())
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
                .foregroundStyle(isSelected ? Color.white : SoulTheme.primaryText)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(
                    isSelected
                    ? SoulTheme.accent
                    : SoulTheme.cardFill,
                    in: Capsule()
                )
                .overlay(Capsule().stroke(isSelected ? SoulTheme.accent.opacity(0.34) : SoulTheme.cardStroke, lineWidth: 1))
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
        .background(SoulGlassCardBackground())
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
                            .foregroundStyle(SoulTheme.danger)
                            .frame(width: 32, height: 32)
                            .background(SoulTheme.danger.opacity(0.14), in: Circle())
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
                .background(SoulTheme.subtleFill, in: RoundedRectangle(cornerRadius: 8))

            ReviewInsightRow(title: localizedText("评分原因", "Score Reason"), text: record.reason, systemImage: "checkmark.seal.fill")
            ReviewInsightRow(title: localizedText("复盘建议", "Review Advice"), text: record.advice, systemImage: "lightbulb.fill")
        }
        .padding(15)
        .background(SoulGlassCardBackground())
    }

    private var sourceColor: Color {
        switch record.source {
        case .scenario: SoulTheme.accent
        case .wechat: Color(red: 0.22, green: 0.68, blue: 0.35)
        case .manual: SoulTheme.support
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
                .foregroundStyle(SoulTheme.warning)
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
                                    .foregroundStyle(source == item ? Color.white : SoulTheme.primaryText)
                                    .padding(.horizontal, 10)
                                    .frame(height: 34)
                                    .background(
                                        source == item
                                        ? SoulTheme.accent
                                        : SoulTheme.cardFill,
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
                        .background(SoulTheme.subtleFill, in: RoundedRectangle(cornerRadius: 8))
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
                            ? SoulTheme.accent
                            : Color.gray.opacity(0.35),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
                .disabled(!canSubmit)
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(SoulTheme.pageGradient)
            .navigationTitle(localizedText("添加复盘", "Add Review"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
