//
//  ConversationReviewPage.swift
//  SoulMark
//

import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct ReviewMediaAttachment {
    let data: Data
    let filename: String
    let mimeType: String
}

struct ConversationReviewPage: View {
    @EnvironmentObject private var session: AppSession
    @AppStorage("soulMarkLanguage") private var language = "zh"
    @AppStorage("soulMarkGenderTheme") private var genderTheme = "male"
    @AppStorage("soulMarkAppearanceMode") private var appearanceMode = "auto"
    @State private var records: [ConversationReviewRecord] = []
    @State private var isAddingRecord = false
    @State private var selectedSource: ReviewSource?
    @State private var selectedRecord: ConversationReviewRecord?
    @State private var searchText = ""
    @State private var deletionError: String?
    @State private var queuedTimelineSuggestion: ReviewTimelineSuggestion?
    @State private var pendingTimelineSuggestion: ReviewTimelineSuggestion?
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
                                onOpen: {
                                    selectedRecord = record
                                },
                                onDelete: {
                                    Task {
                                        do {
                                            try await session.deleteReview(record.id)
                                            records.removeAll { $0.id == record.id }
                                            onRecordCountChange(records.count)
                                        } catch {
                                            deletionError = error.localizedDescription
                                        }
                                    }
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
            AddReviewRecordSheet { title, source, transcript, media in
                let analysis = try await session.analyzeReview(
                    title: title,
                    source: source,
                    transcript: transcript,
                    language: SoulPreferencesStore.shared.language,
                    media: media
                )
                let record = try await session.recordReview(analysis)
                await MainActor.run {
                    records.insert(record, at: 0)
                    onRecordCountChange(records.count)
                    queuedTimelineSuggestion = analysis.timelineSuggestion
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedRecord) { record in
            ConversationReviewDetailSheet(record: record)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $pendingTimelineSuggestion) { suggestion in
            ReviewTimelineSuggestionSheet(suggestion: suggestion) {
                contactIDs,
                title,
                details,
                occurredAt,
                imageData in
                _ = try await session.createContactEvents(
                    contactIDs: contactIDs,
                    title: title,
                    details: details,
                    occurredAt: occurredAt,
                    imageData: imageData,
                    skipRelationshipUpdate: true
                )
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: isAddingRecord) { _, isPresented in
            guard !isPresented, let suggestion = queuedTimelineSuggestion else {
                return
            }
            queuedTimelineSuggestion = nil
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(280))
                pendingTimelineSuggestion = suggestion
            }
        }
        .task {
            if let syncedRecords = await session.loadReviews() {
                records = syncedRecords
                onRecordCountChange(records.count)
            }
        }
        .alert(
            localizedText("删除失败", "Delete Failed"),
            isPresented: Binding(
                get: { deletionError != nil },
                set: { if !$0 { deletionError = nil } }
            )
        ) {
            Button(localizedText("知道了", "OK")) { deletionError = nil }
        } message: {
            Text(deletionError ?? "")
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
                        .foregroundStyle(SoulTheme.primaryText)

                    Text("/ 100")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(SoulTheme.secondaryText)
                }
            }

            Rectangle()
                .fill(SoulTheme.cardStroke)
                .frame(width: 1, height: 64)

            VStack(alignment: .leading, spacing: 10) {
                Label(localizedText("\(resultCount) 条复盘", "\(resultCount) reviews"), systemImage: "text.bubble.fill")
                Label(localizedText("信号持续上升", "Signal trending up"), systemImage: "arrow.up.right")
            }
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(SoulTheme.secondaryText)

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 126)
        .background(SoulGlassCardBackground())
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
            .background(SoulTheme.subtleFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
    let onOpen: () -> Void
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
                .background(SoulTheme.subtleFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            ReviewInsightRow(title: localizedText("评分原因", "Score Reason"), text: record.reason, systemImage: "checkmark.seal.fill")
            ReviewInsightRow(title: localizedText("复盘建议", "Review Advice"), text: record.advice, systemImage: "lightbulb.fill")
        }
        .padding(15)
        .background(SoulGlassCardBackground())
        .contentShape(RoundedRectangle(cornerRadius: SoulTheme.containerCornerRadius, style: .continuous))
        .onTapGesture(perform: onOpen)
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

private struct ConversationReviewDetailSheet: View {
    let record: ConversationReviewRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(record.title)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(SoulTheme.primaryText)

                            Label(
                                "\(record.source.title) · \(record.date.formatted(date: .abbreviated, time: .shortened))",
                                systemImage: record.source.systemImage
                            )
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SoulTheme.secondaryText)
                        }

                        Spacer()

                        VStack(spacing: 0) {
                            Text("\(record.score)")
                                .font(.system(size: 30, weight: .heavy, design: .rounded))
                            Text(localizedText("分", "pts"))
                                .font(.caption.bold())
                        }
                        .foregroundStyle(SoulTheme.primaryText)
                        .frame(width: 76, height: 76)
                        .background(scoreColor, in: Circle())
                    }

                    ReviewDetailSection(
                        title: localizedText("评分原因", "Why This Score"),
                        systemImage: "checkmark.seal.fill",
                        text: record.reason
                    )

                    ReviewDetailSection(
                        title: localizedText("详细复盘建议", "Detailed Review"),
                        systemImage: "text.book.closed.fill",
                        text: record.detailedAdvice
                    )
                }
                .padding(20)
            }
            .background(SoulTheme.pageGradient)
            .navigationTitle(localizedText("复盘详情", "Review Details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizedText("完成", "Done")) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var scoreColor: Color {
        record.score >= 85
            ? Color(red: 0.70, green: 0.88, blue: 0.55)
            : Color(red: 0.98, green: 0.76, blue: 0.38)
    }
}

private struct ReviewDetailSection: View {
    let title: String
    let systemImage: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(SoulTheme.accent)

            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(SoulTheme.primaryText)
                .lineSpacing(5)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(SoulGlassCardBackground())
    }
}

private struct AddReviewRecordSheet: View {
    let onAdd: (
        String,
        ReviewSource,
        String,
        ReviewMediaAttachment?
    ) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioRecorder = ReviewAudioRecorder()
    @State private var title = ""
    @State private var source: ReviewSource = .scenario
    @State private var transcript = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedImageData: Data?
    @State private var isGenerating = false
    @State private var generationError: String?

    private var canSubmit: Bool {
        switch source {
        case .scenario:
            audioRecorder.recordingData != nil && !audioRecorder.isRecording
        case .wechat:
            selectedImageData != nil
        case .manual:
            !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var mediaAttachment: ReviewMediaAttachment? {
        switch source {
        case .scenario:
            guard let data = audioRecorder.recordingData else { return nil }
            return ReviewMediaAttachment(
                data: data,
                filename: "scenario-review.m4a",
                mimeType: "audio/mp4"
            )
        case .wechat:
            guard let data = selectedImageData else { return nil }
            return ReviewMediaAttachment(
                data: data,
                filename: "wechat-review.jpg",
                mimeType: "image/jpeg"
            )
        case .manual:
            return nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localizedText("标题", "Title"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SoulTheme.secondaryText)

                        HStack(spacing: 12) {
                            Image(systemName: "textformat")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(SoulTheme.accent)

                            TextField(
                                localizedText(
                                    "例如：和朋友的误会复盘",
                                    "Example: A misunderstanding with a friend"
                                ),
                                text: $title
                            )
                            .font(.system(size: 16))
                            .foregroundStyle(SoulTheme.primaryText)
                            .textFieldStyle(.plain)
                        }
                        .padding(.horizontal, 15)
                        .frame(height: 52)
                        .background(
                            SoulTheme.cardFill,
                            in: RoundedRectangle(
                                cornerRadius: SoulTheme.controlCornerRadius,
                                style: .continuous
                            )
                        )
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: SoulTheme.controlCornerRadius,
                                style: .continuous
                            )
                            .stroke(SoulTheme.cardStroke, lineWidth: 1)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(localizedText("来源", "Source"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SoulTheme.secondaryText)

                        HStack(spacing: 8) {
                            ForEach(ReviewSource.allCases) { item in
                                Button {
                                    source = item
                                } label: {
                                    VStack(spacing: 7) {
                                        Image(systemName: item.systemImage)
                                            .font(.system(size: 16, weight: .semibold))
                                        Text(item.title)
                                            .font(.system(size: 12, weight: .semibold))
                                            .lineLimit(1)
                                    }
                                    .foregroundStyle(
                                        source == item
                                            ? Color.white
                                            : SoulTheme.primaryText
                                    )
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 62)
                                    .background(
                                        source == item
                                            ? SoulTheme.accent
                                            : SoulTheme.cardFill,
                                        in: RoundedRectangle(
                                            cornerRadius: SoulTheme.controlCornerRadius,
                                            style: .continuous
                                        )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    sourceInput

                    Button {
                        Task {
                            isGenerating = true
                            do {
                                try await onAdd(
                                    title,
                                    source,
                                    transcript,
                                    mediaAttachment
                                )
                                isGenerating = false
                                dismiss()
                            } catch {
                                isGenerating = false
                                generationError = error.localizedDescription
                            }
                        }
                    } label: {
                        if isGenerating {
                            HStack(spacing: 9) {
                                ProgressView()
                                    .tint(.white)
                                Text(localizedText("正在分析…", "Analyzing…"))
                            }
                        } else {
                            Label(
                                localizedText("生成复盘", "Generate Review"),
                                systemImage: "sparkles"
                            )
                        }
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        canSubmit && !isGenerating
                            ? SoulTheme.accent
                            : Color.gray.opacity(0.35),
                        in: RoundedRectangle(
                            cornerRadius: SoulTheme.controlCornerRadius,
                            style: .continuous
                        )
                    )
                    .disabled(!canSubmit || isGenerating)
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(SoulTheme.pageGradient)
            .navigationTitle(localizedText("添加复盘", "Add Review"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                do {
                    guard let data = try await newItem.loadTransferable(type: Data.self) else {
                        throw ReviewMediaError.invalidImage
                    }
                    let prepared = try ReviewImageProcessor.prepare(data)
                    selectedImageData = prepared
                    selectedImage = UIImage(data: prepared)
                } catch {
                    generationError = localizedText(
                        "无法读取这张图片，请选择其他聊天截图。",
                        "This image could not be read. Choose another screenshot."
                    )
                }
            }
        }
        .onChange(of: audioRecorder.errorMessage) { _, message in
            if let message {
                generationError = message
                audioRecorder.errorMessage = nil
            }
        }
        .onDisappear {
            audioRecorder.stop()
        }
        .interactiveDismissDisabled(isGenerating)
        .alert(
            localizedText("生成失败", "Generation Failed"),
            isPresented: Binding(
                get: { generationError != nil },
                set: { if !$0 { generationError = nil } }
            )
        ) {
            Button(localizedText("知道了", "OK")) { generationError = nil }
        } message: {
            Text(generationError ?? "")
        }
    }

    @ViewBuilder
    private var sourceInput: some View {
        switch source {
        case .scenario:
            audioInput
        case .wechat:
            imageInput
        case .manual:
            manualInput
        }
    }

    private var audioInput: some View {
        VStack(spacing: 18) {
            Button {
                Task { await audioRecorder.toggle() }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            audioRecorder.isRecording
                                ? SoulTheme.danger
                                : SoulTheme.accent
                        )
                        .frame(width: 76, height: 76)

                    Image(
                        systemName: audioRecorder.isRecording
                            ? "stop.fill"
                            : "mic.fill"
                    )
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Color.white)
                }
            }
            .buttonStyle(.plain)
            .disabled(isGenerating)

            VStack(spacing: 5) {
                Text(audioStatusTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(SoulTheme.primaryText)

                Text(
                    audioRecorder.isRecording
                        ? "\(audioRecorder.elapsedDisplay) / 2:00"
                        : localizedText(
                            "录下你对这次沟通的描述，AI 会先转写再分析",
                            "Describe the conversation; AI will transcribe and analyze it"
                        )
                )
                .font(.system(size: 13))
                .foregroundStyle(SoulTheme.secondaryText)
                .multilineTextAlignment(.center)
            }

            if audioRecorder.recordingData != nil && !audioRecorder.isRecording {
                Button(localizedText("重新录制", "Record Again")) {
                    audioRecorder.reset()
                }
                .font(.system(size: 13, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
        .background(SoulGlassCardBackground())
    }

    private var audioStatusTitle: String {
        if audioRecorder.isRecording {
            return localizedText("正在录音", "Recording")
        }
        if audioRecorder.recordingData != nil {
            return localizedText("录音已就绪", "Recording Ready")
        }
        return localizedText("点击开始录音", "Tap to Record")
    }

    private var imageInput: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            VStack(spacing: 14) {
                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 230)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: SoulTheme.controlCornerRadius,
                                style: .continuous
                            )
                        )

                    Label(
                        localizedText("更换聊天截图", "Choose Another Screenshot"),
                        systemImage: "photo.badge.arrow.down"
                    )
                } else {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(SoulTheme.accent)

                    Text(localizedText("选择微信聊天截图", "Choose WeChat Screenshots"))
                        .font(.system(size: 17, weight: .semibold))

                    Text(
                        localizedText(
                            "截图会直接发送给 AI 读取并分析",
                            "The screenshot will be sent directly to AI for analysis"
                        )
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(SoulTheme.secondaryText)
                }
            }
            .foregroundStyle(SoulTheme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(22)
            .background(SoulGlassCardBackground())
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
    }

    private var manualInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedText("聊天记录", "Chat Record"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SoulTheme.secondaryText)

            TextEditor(text: $transcript)
                .font(.system(size: 15))
                .foregroundStyle(SoulTheme.primaryText)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 210)
                .background(
                    SoulTheme.cardFill,
                    in: RoundedRectangle(
                        cornerRadius: SoulTheme.controlCornerRadius,
                        style: .continuous
                    )
                )
                .overlay(alignment: .topLeading) {
                    if transcript.isEmpty {
                        Text(
                            localizedText(
                                "输入或粘贴你整理的沟通内容",
                                "Enter or paste the conversation"
                            )
                        )
                        .font(.system(size: 14))
                        .foregroundStyle(SoulTheme.tertiaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                    }
                }
        }
    }
}

private struct ReviewContactSelectionButton: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                Text(name).lineLimit(1)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isSelected ? Color.white : SoulTheme.primaryText)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background {
                Capsule()
                    .fill(isSelected ? SoulTheme.accent : SoulTheme.cardFill)
            }
            .overlay {
                if !isSelected {
                    Capsule()
                        .stroke(SoulTheme.cardStroke, lineWidth: 0.8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ReviewTimelineSuggestionSheet: View {
    let suggestion: ReviewTimelineSuggestion
    let onSave: ([UUID], String, String, Date, Data?) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedContactIDs: Set<UUID>
    @State private var title: String
    @State private var details: String
    @State private var occurredAt = Date()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var previewImage: UIImage?
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        suggestion: ReviewTimelineSuggestion,
        onSave: @escaping ([UUID], String, String, Date, Data?) async throws -> Void
    ) {
        self.suggestion = suggestion
        self.onSave = onSave
        _selectedContactIDs = State(initialValue: Set(suggestion.contacts.map(\.id)))
        _title = State(initialValue: suggestion.title)
        _details = State(initialValue: suggestion.details)
    }

    private var canSave: Bool {
        !selectedContactIDs.isEmpty
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var contactNames: String {
        suggestion.contacts.map(\.name).joined(separator: "、")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Label(
                            localizedText("识别到相关人物", "Related Person Found"),
                            systemImage: "person.crop.circle.badge.checkmark"
                        )
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(SoulTheme.accent)

                        Text(
                            localizedText(
                                "要将这件事记录到 \(contactNames) 的事件时间线吗？",
                                "Add this event to \(suggestion.contacts.map(\.name).joined(separator: ", "))'s timeline?"
                            )
                        )
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(SoulTheme.primaryText)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(localizedText("事件标题", "Event Title"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SoulTheme.secondaryText)
                        HStack(spacing: 12) {
                            Image(systemName: "textformat")
                                .foregroundStyle(SoulTheme.accent)
                            TextField(localizedText("事件标题", "Event title"), text: $title)
                                .textFieldStyle(.plain)
                        }
                        .padding(.horizontal, 15)
                        .frame(height: 52)
                        .background(
                            SoulGlassCardBackground(
                                cornerRadius: SoulTheme.controlCornerRadius
                            )
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(localizedText("发生时间", "Date and Time"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SoulTheme.secondaryText)
                        DatePicker(
                            "",
                            selection: $occurredAt,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .padding(15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(SoulGlassCardBackground())
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(localizedText("人物", "People"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SoulTheme.secondaryText)

                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 104), spacing: 8)
                            ],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            ForEach(suggestion.contacts) { contact in
                                ReviewContactSelectionButton(
                                    name: contact.name,
                                    isSelected: selectedContactIDs.contains(contact.id)
                                ) {
                                    withAnimation(.snappy(duration: 0.28)) {
                                        if selectedContactIDs.contains(contact.id) {
                                            selectedContactIDs.remove(contact.id)
                                        } else {
                                            selectedContactIDs.insert(contact.id)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(SoulGlassCardBackground())

                        if selectedContactIDs.isEmpty {
                            Text(localizedText("请至少选择一位人物", "Select at least one person"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.red)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(localizedText("事件详情", "Event Details"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SoulTheme.secondaryText)
                        TextEditor(text: $details)
                            .font(.system(size: 15))
                            .foregroundStyle(SoulTheme.primaryText)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 180)
                            .padding(12)
                            .background(SoulGlassCardBackground())
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        VStack(spacing: 10) {
                            if let previewImage {
                                Image(uiImage: previewImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 220)
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: SoulTheme.controlCornerRadius,
                                            style: .continuous
                                        )
                                    )
                                Label(
                                    localizedText("更换图片", "Change Photo"),
                                    systemImage: "photo"
                                )
                            } else {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(SoulTheme.accent)
                                Text(localizedText("可选添加图片", "Add an Optional Photo"))
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        }
                        .foregroundStyle(SoulTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background(SoulGlassCardBackground())
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            isSaving = true
                            do {
                                let selectedIDs = suggestion.contacts
                                    .map(\.id)
                                    .filter(selectedContactIDs.contains)
                                try await onSave(
                                    selectedIDs,
                                    title,
                                    details,
                                    occurredAt,
                                    imageData
                                )
                                dismiss()
                            } catch {
                                isSaving = false
                                errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Label(
                                localizedText("记录到事件时间线", "Add to Timeline"),
                                systemImage: "clock.badge.checkmark"
                            )
                        }
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        canSave ? SoulTheme.accent : Color.gray.opacity(0.35),
                        in: RoundedRectangle(
                            cornerRadius: SoulTheme.controlCornerRadius,
                            style: .continuous
                        )
                    )
                    .disabled(!canSave || isSaving)
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(SoulTheme.pageGradient)
            .navigationTitle(localizedText("保存事件", "Save Event"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedText("不记录", "Not Now")) { dismiss() }
                        .disabled(isSaving)
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw ReviewMediaError.invalidImage
                    }
                    let prepared = try ReviewImageProcessor.prepare(data)
                    imageData = prepared
                    previewImage = UIImage(data: prepared)
                } catch {
                    errorMessage = localizedText(
                        "无法读取这张图片，请选择另一张。",
                        "This photo could not be read. Choose another one."
                    )
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .alert(
            localizedText("无法记录事件", "Could Not Save Event"),
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

private enum ReviewMediaError: Error {
    case invalidImage
}

private enum ReviewImageProcessor {
    static func prepare(_ data: Data) throws -> Data {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
            throw ReviewMediaError.invalidImage
        }
        let longestSide = max(image.size.width, image.size.height)
        let scale = min(1, 1_600 / longestSide)
        let targetSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let encoded = rendered.jpegData(compressionQuality: 0.80) else {
            throw ReviewMediaError.invalidImage
        }
        return encoded
    }
}

@MainActor
private final class ReviewAudioRecorder: ObservableObject {
    private static let maximumDuration = 120

    @Published var isRecording = false
    @Published var elapsedSeconds = 0
    @Published var recordingData: Data?
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var timerTask: Task<Void, Never>?

    var elapsedDisplay: String {
        String(format: "%d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    func toggle() async {
        if isRecording {
            stop()
        } else {
            await start()
        }
    }

    func start() async {
        let granted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
        guard granted else {
            errorMessage = localizedText(
                "请在系统设置中允许 SoulMark 使用麦克风。",
                "Allow SoulMark to use the microphone in Settings."
            )
            return
        }

        do {
            reset()
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker]
            )
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("soulmark-review-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64_000,
            ]
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.prepareToRecord()
            guard newRecorder.record() else {
                throw ReviewMediaError.invalidImage
            }
            recorder = newRecorder
            recordingURL = url
            elapsedSeconds = 0
            isRecording = true
            startTimer()
        } catch {
            errorMessage = localizedText(
                "无法开始录音，请稍后重试。",
                "Recording could not start. Try again."
            )
            stop()
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
        recorder?.stop()
        recorder = nil
        if isRecording, let recordingURL {
            recordingData = try? Data(contentsOf: recordingURL)
        }
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    func reset() {
        stop()
        recordingData = nil
        elapsedSeconds = 0
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
    }

    private func startTimer() {
        timerTask = Task { @MainActor [weak self] in
            while let self,
                  self.isRecording,
                  self.elapsedSeconds < Self.maximumDuration {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, self.isRecording else { return }
                self.elapsedSeconds += 1
            }
            if self?.isRecording == true {
                self?.stop()
            }
        }
    }
}
