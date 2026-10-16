//
//  SelfAwarenessReportView.swift
//  SoulMark
//
//  Profile report: one weekly page of eight cells, exportable as image or PDF.
//

import SwiftUI
import UIKit

struct SelfAwarenessReportEntryCard: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 48, height: 48)
                    .background(
                        LinearGradient(colors: [SoulTheme.accent, SoulTheme.energy], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedText("我的自我认知报告", "My Self-awareness Report"))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(SoulTheme.primaryText)
                    Text(localizedText("从挑战、复盘和关系里，看见现在的你", "What your challenges, reviews and relationships say about you"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(SoulTheme.secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(SoulTheme.accent)
            }
            .padding(16)
            .background(SoulGlassCardBackground(accented: true))
        }
        .buttonStyle(.plain)
    }
}

struct SelfAwarenessReportSheet: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    var onOpenGraph: () -> Void = {}
    var onOpenScenario: () -> Void = {}
    var onOpenJournal: () -> Void = {}
    @State private var report: SelfAwarenessReportDTO?
    @State private var errorMessage: String?
    @State private var shareItems: ShareItems?
    @State private var confirming: SelfAwarenessReportDTO.Cell?

    var body: some View {
        NavigationStack {
            ZStack {
                SoulBackground()
                ScrollView(showsIndicators: false) {
                    if let report {
                        SelfPageBody(
                            report: report,
                            onConfirm: { confirming = $0 },
                            onCompleteStep: { Task { await completeStep() } },
                            onOpenGraph: { dismiss(); onOpenGraph() },
                            onOpenScenario: { dismiss(); onOpenScenario() },
                            onOpenJournal: { dismiss(); onOpenJournal() }
                        )
                        .padding(16)
                    } else if let errorMessage {
                        VStack(spacing: 12) {
                            Text(errorMessage).foregroundStyle(SoulTheme.secondaryText)
                            Button(localizedText("重试", "Retry")) { Task { await load() } }
                        }
                        .padding(60)
                    } else {
                        VStack(spacing: 12) {
                            ProgressView().tint(SoulTheme.accent)
                            Text(localizedText("正在整理这一页…", "Gathering this page…"))
                                .font(.system(size: 13)).foregroundStyle(SoulTheme.secondaryText)
                        }
                        .padding(.top, 120)
                    }
                }
            }
            .navigationTitle(localizedText("自我认知报告", "Self-awareness Report"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localizedText("关闭", "Close")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { share(asPDF: false) } label: {
                            Label(localizedText("分享为图片", "Share as image"), systemImage: "photo")
                        }
                        Button { share(asPDF: true) } label: {
                            Label(localizedText("导出 PDF", "Export PDF"), systemImage: "doc.fill")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(report == nil)
                }
            }
            .task { await load() }
            .sheet(item: $shareItems) { item in ActivityShareSheet(items: item.items) }
            .sheet(item: $confirming) { cell in
                if let report {
                    ConfirmSelfCellSheet(report: report, cell: cell) { updated in
                        self.report = updated
                        confirming = nil
                    }
                }
            }
        }
    }

    private func load() async {
        do { report = try await session.loadSelfAwarenessReport(); errorMessage = nil } catch { errorMessage = error.localizedDescription }
    }

    private func completeStep() async {
        do { report = try await session.completeWeeklyStep() } catch { errorMessage = error.localizedDescription }
    }

    private func share(asPDF: Bool) {
        guard let report else { return }
        do {
            let url = asPDF ? try SelfAwarenessReportExporter.pdf(report) : try SelfAwarenessReportExporter.png(report)
            let line = localizedText(
                "证据 \(report.evidenceCovered)/\(report.evidenceTotal)",
                "Evidence \(report.evidenceCovered)/\(report.evidenceTotal)"
            )
            shareItems = ShareItems(items: [url, line as NSString])
        } catch {
            errorMessage = localizedText("导出失败，请稍后重试。", "Export failed. Try again later.")
        }
    }

    private struct ShareItems: Identifiable {
        let id = UUID()
        let items: [Any]
    }
}

private struct SelfPageBody: View {
    let report: SelfAwarenessReportDTO
    let onConfirm: (SelfAwarenessReportDTO.Cell) -> Void
    let onCompleteStep: () -> Void
    let onOpenGraph: () -> Void
    let onOpenScenario: () -> Void
    let onOpenJournal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(localizedText(
                    "证据 \(report.evidenceCovered)/\(report.evidenceTotal)",
                    "Evidence \(report.evidenceCovered)/\(report.evidenceTotal)"
                ))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(SoulTheme.primaryText)
                Text(localizedText(
                    "本周这一步：\(report.weeklyStepDone ? "已做" : "未做")",
                    "This week's step: \(report.weeklyStepDone ? "Done" : "Not done")"
                ))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(SoulTheme.secondaryText)
                if report.pausedAt != nil {
                    Text(localizedText("先停在这里", "Stopped here"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(SoulTheme.secondaryText)
                }
            }

            ForEach(report.cells) { cell in
                VStack(alignment: .leading, spacing: 8) {
                    Text(selfPageSlotTitle(cell.slot))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(SoulTheme.primaryText)
                    if cell.covered {
                        Text(cell.text)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(SoulTheme.primaryText)
                        if cell.slot == "weekly_step", !report.weeklyStepDone {
                            Button(action: onCompleteStep) {
                                Text(localizedText("标为已做", "Mark done"))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(SoulTheme.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Text(localizedText("空白", "Blank"))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(SoulTheme.tertiaryText)
                        if !cell.missing.isEmpty {
                            Text(cell.missing.joined(separator: " · "))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(SoulTheme.secondaryText)
                        }
                    }
                    Button {
                        onConfirm(cell)
                    } label: {
                        Text(cell.covered
                            ? localizedText("改一句", "Edit this line")
                            : localizedText("确认这一格", "Confirm this cell"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(SoulTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(SoulGlassCardBackground())
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(localizedText("记账", "Bookkeeping"))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(SoulTheme.primaryText)
                bookkeepingButton(
                    localizedText("去图谱记一个人", "Add someone on the map"),
                    action: onOpenGraph
                )
                bookkeepingButton(
                    localizedText("开始一次练习", "Start a practice"),
                    action: onOpenScenario
                )
                bookkeepingButton(
                    localizedText("写一条复盘", "Write a review"),
                    action: onOpenJournal
                )
                Text(localizedText(
                    "已有 \(report.bookkeeping.contactsCount) 人、\(report.bookkeeping.eventsCount) 件事件、\(report.bookkeeping.practicesCount) 次练习、\(report.bookkeeping.reviewsCount) 条复盘。",
                    "\(report.bookkeeping.contactsCount) people, \(report.bookkeeping.eventsCount) events, \(report.bookkeeping.practicesCount) practices, \(report.bookkeeping.reviewsCount) reviews."
                ))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(SoulTheme.secondaryText)
            }
        }
    }

    private func bookkeepingButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .heavy))
            }
            .foregroundStyle(SoulTheme.primaryText)
            .padding(14)
            .background(SoulGlassCardBackground())
        }
        .buttonStyle(.plain)
    }
}

private struct ConfirmSelfCellSheet: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let report: SelfAwarenessReportDTO
    let cell: SelfAwarenessReportDTO.Cell
    let onSaved: (SelfAwarenessReportDTO) -> Void

    @State private var text: String
    @State private var selected: Set<String> = []
    @State private var addedQuotes: [String: String] = [:]
    @State private var noteQuote = ""
    @State private var noteDetail = ""
    @State private var noteDate = Date()
    @State private var includeNote = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var pendingDistress = false

    init(report: SelfAwarenessReportDTO, cell: SelfAwarenessReportDTO.Cell, onSaved: @escaping (SelfAwarenessReportDTO) -> Void) {
        self.report = report
        self.cell = cell
        self.onSaved = onSaved
        _text = State(initialValue: cell.text)
    }

    private var candidates: [SelfAwarenessReportDTO.DraftItem] {
        report.draft.filter { item in
            if cell.slot.hasPrefix("pattern") {
                return item.slot == "pattern" || item.slot == "marked"
            }
            return item.slot == cell.slot || item.slot == "marked"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(selfPageSlotTitle(cell.slot))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(SoulTheme.primaryText)
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(minHeight: 90)
                        .padding(8)
                        .background(SoulTheme.cardFill, in: RoundedRectangle(cornerRadius: SoulTheme.controlCornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: SoulTheme.controlCornerRadius, style: .continuous)
                                .stroke(SoulTheme.cardStroke, lineWidth: 1)
                        )
                    ForEach(candidates) { item in
                        candidateRow(item)
                    }
                    Toggle(localizedText("补一句，并写上日期", "Add a sentence and its date"), isOn: $includeNote)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    if includeNote {
                        TextField(localizedText("原话", "Your words"), text: $noteQuote, axis: .vertical)
                            .soulInsetField()
                        TextField(localizedText("具体细节", "Concrete detail"), text: $noteDetail, axis: .vertical)
                            .soulInsetField()
                        DatePicker(localizedText("日期", "Date"), selection: $noteDate, displayedComponents: .date)
                    }
                    Button { Task { await confirm(continueAnyway: false) } } label: {
                        Text(localizedText("确认上页", "Put it on the page"))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(SoulTheme.accent, in: RoundedRectangle(cornerRadius: SoulTheme.controlCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                    Button { Task { await clearCell() } } label: {
                        Text(localizedText("这一格留空", "Leave this cell blank"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(SoulTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                }
                .padding(18)
            }
            .background(SoulTheme.pageGradient)
            .navigationTitle(localizedText("确认", "Confirm"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedText("关闭", "Close")) { dismiss() }
                }
            }
            .alert(localizedText("这一格还不能上页", "This cell stays blank"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button(localizedText("知道了", "OK")) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .confirmationDialog(
                localizedText("你现在还好吗", "Are you okay right now?"),
                isPresented: $pendingDistress,
                titleVisibility: .visible
            ) {
                Button(localizedText("我还好，继续", "I'm okay, continue")) {
                    Task { await confirm(continueAnyway: true) }
                }
                Button(localizedText("先停在这里", "Stop here")) {
                    Task { await stopHere() }
                }
            }
        }
    }

    @ViewBuilder
    private func candidateRow(_ item: SelfAwarenessReportDTO.DraftItem) -> some View {
        let chosen = selected.contains(item.id)
        VStack(alignment: .leading, spacing: 6) {
            Button {
                if chosen { selected.remove(item.id) } else { selected.insert(item.id) }
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(SoulTheme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.prompt)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(SoulTheme.secondaryText)
                        if !item.quote.isEmpty {
                            Text("“\(item.quote)”")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(SoulTheme.primaryText)
                        }
                        if !item.detail.isEmpty {
                            Text(item.detail)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(SoulTheme.secondaryText)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            if chosen && item.quote.isEmpty {
                TextField(localizedText("你的原话", "Your words"), text: Binding(
                    get: { addedQuotes[item.id] ?? "" },
                    set: { addedQuotes[item.id] = $0 }
                ), axis: .vertical)
                .soulInsetField()
            }
        }
        .padding(12)
        .background(SoulGlassCardBackground())
    }

    private func evidencePayload() -> [SelfEvidenceInput] {
        var rows: [SelfEvidenceInput] = []
        for item in candidates where selected.contains(item.id) {
            let quote = item.quote.isEmpty ? (addedQuotes[item.id] ?? "") : item.quote
            let trimmed = quote.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            rows.append(SelfEvidenceInput(
                sourceType: item.sourceType,
                sourceId: item.sourceId,
                quote: trimmed,
                detail: item.detail.isEmpty ? trimmed : item.detail,
                occurredOn: item.occurredOn.map(selfPageDayString)
            ))
        }
        if includeNote {
            let quote = noteQuote.trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = noteDetail.trimmingCharacters(in: .whitespacesAndNewlines)
            if !quote.isEmpty && !detail.isEmpty {
                rows.append(SelfEvidenceInput(
                    sourceType: "user_note",
                    sourceId: nil,
                    quote: quote,
                    detail: detail,
                    occurredOn: selfPageDayString(noteDate)
                ))
            }
        }
        return rows
    }

    private func confirm(continueAnyway: Bool) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let updated = try await session.confirmSelfCell(ConfirmSelfCellPayload(
                slot: cell.slot,
                text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                evidence: evidencePayload(),
                continueAnyway: continueAnyway
            ))
            onSaved(updated)
        } catch SoulAPIError.distressCheck {
            pendingDistress = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearCell() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let updated = try await session.confirmSelfCell(ConfirmSelfCellPayload(
                slot: cell.slot,
                text: "",
                evidence: [],
                continueAnyway: false
            ))
            onSaved(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopHere() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let updated = try await session.pauseSelfPage()
            onSaved(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum SelfAwarenessReportExporter {
    enum ExportError: Error { case renderFailed }
    static let width: CGFloat = 430

    @MainActor
    private static func renderer(_ report: SelfAwarenessReportDTO) -> ImageRenderer<some View> {
        let renderer = ImageRenderer(content: SelfAwarenessReportCard(report: report).frame(width: width))
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        renderer.scale = 3
        return renderer
    }

    private static func fileURL(_ ext: String) -> URL {
        let stamp = Date().formatted(.iso8601.year().month().day())
        return FileManager.default.temporaryDirectory.appendingPathComponent("SoulMark-自我认知报告-\(stamp).\(ext)")
    }

    @MainActor
    static func png(_ report: SelfAwarenessReportDTO) throws -> URL {
        guard let data = renderer(report).uiImage?.pngData() else { throw ExportError.renderFailed }
        let url = fileURL("png")
        try data.write(to: url, options: .atomic)
        return url
    }

    @MainActor
    static func pdf(_ report: SelfAwarenessReportDTO) throws -> URL {
        let url = fileURL("pdf")
        var failed = true
        renderer(report).render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            failed = false
        }
        if failed { throw ExportError.renderFailed }
        return url
    }
}

struct SelfAwarenessReportCard: View {
    let report: SelfAwarenessReportDTO

    private let ink = Color(red: 0.06, green: 0.065, blue: 0.085)
    private let panel = Color.white.opacity(0.06)
    private let mint = Color(red: 0.36, green: 0.92, blue: 0.78)
    private let soft = Color.white.opacity(0.62)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SOULMARK")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(mint)
            Text(localizedText(
                "证据 \(report.evidenceCovered)/\(report.evidenceTotal)",
                "Evidence \(report.evidenceCovered)/\(report.evidenceTotal)"
            ))
            .font(.system(size: 28, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            Text(localizedText(
                "本周这一步：\(report.weeklyStepDone ? "已做" : "未做")",
                "This week's step: \(report.weeklyStepDone ? "Done" : "Not done")"
            ))
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(soft)
            ForEach(report.cells) { cell in
                VStack(alignment: .leading, spacing: 6) {
                    Text(selfPageSlotTitle(cell.slot))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(mint)
                    Text(cell.covered ? cell.text : localizedText("空白", "Blank"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(24)
        .background(ink)
        .environment(\.colorScheme, .dark)
    }
}
