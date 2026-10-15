//
//  SelfAwarenessReportView.swift
//  SoulMark
//
//  Profile report: 自我认知 / 自我提升报告, exportable as image or PDF.
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
    @State private var report: SelfAwarenessReportDTO?
    @State private var errorMessage: String?
    @State private var shareItems: ShareItems?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.065, blue: 0.08).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    if let report {
                        SelfAwarenessReportCard(report: report)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .padding(16)
                    } else if let errorMessage {
                        VStack(spacing: 12) {
                            Text(errorMessage).foregroundStyle(Color.white.opacity(0.7))
                            Button(localizedText("重试", "Retry")) { Task { await load() } }
                        }
                        .padding(60)
                    } else {
                        VStack(spacing: 12) {
                            ProgressView().tint(.white)
                            Text(localizedText("正在整理你的报告…", "Composing your report…"))
                                .font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.6))
                        }
                        .padding(.top, 120)
                    }
                }
            }
            .navigationTitle(localizedText("自我认知报告", "Self-awareness Report"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
        }
    }

    private func load() async {
        do { report = try await session.loadSelfAwarenessReport(); errorMessage = nil } catch { errorMessage = error.localizedDescription }
    }

    private func share(asPDF: Bool) {
        guard let report else { return }
        do {
            let url = asPDF ? try SelfAwarenessReportExporter.pdf(report) : try SelfAwarenessReportExporter.png(report)
            shareItems = ShareItems(items: [url, "我的 SoulMark 自我认知报告：\(report.headline)" as NSString])
        } catch {
            errorMessage = localizedText("导出失败，请稍后重试。", "Export failed. Try again later.")
        }
    }

    private struct ShareItems: Identifiable {
        let id = UUID()
        let items: [Any]
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

/// Fixed palette so the on-screen card and exported files look identical in any theme.
struct SelfAwarenessReportCard: View {
    let report: SelfAwarenessReportDTO

    private let ink = Color(red: 0.06, green: 0.065, blue: 0.085)
    private let panel = Color.white.opacity(0.06)
    private let violet = Color(red: 0.55, green: 0.45, blue: 1.0)
    private let mint = Color(red: 0.36, green: 0.92, blue: 0.78)
    private let soft = Color.white.opacity(0.62)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            dimensionsBlock
            listBlock(title: "你的优势", icon: "sun.max.fill", items: report.strengths, tint: mint)
            listBlock(title: "成长的方向", icon: "leaf.fill", items: report.growthEdges, tint: violet)
            if !report.highlights.isEmpty { highlightsBlock }
            statsBlock
            listBlock(title: "下一步试试", icon: "arrow.forward.circle.fill", items: report.nextSteps, tint: mint)
            footerBlock
        }
        .padding(24)
        .background(
            ZStack {
                ink
                RadialGradient(colors: [violet.opacity(0.45), .clear], center: .topTrailing, startRadius: 10, endRadius: 360)
                RadialGradient(colors: [mint.opacity(0.18), .clear], center: .bottomLeading, startRadius: 10, endRadius: 420)
            }
        )
        .environment(\.colorScheme, .dark)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SOULMARK · 自我认知报告")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(mint)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(report.displayName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(soft)
                    Text(report.headline)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: CGFloat(report.overallScore) / 100)
                        .stroke(AngularGradient(colors: [violet, mint, violet], center: .center), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(report.overallScore)").font(.system(size: 26, weight: .black, design: .rounded)).foregroundStyle(.white)
                        Text("觉察指数").font(.system(size: 9, weight: .bold)).foregroundStyle(soft)
                    }
                }
                .frame(width: 92, height: 92)
            }
            Text(report.summary)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(soft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dimensionsBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("四个维度", icon: "circle.grid.2x2.fill")
            ForEach(report.dimensions) { dimension in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(dimension.title).font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        Spacer()
                        Text("\(dimension.score)").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(mint)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(LinearGradient(colors: [violet, mint], startPoint: .leading, endPoint: .trailing))
                                .frame(width: proxy.size.width * CGFloat(dimension.score) / 100)
                        }
                    }
                    .frame(height: 8)
                    Text(dimension.insight)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(soft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .background(panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func listBlock(title: String, icon: String, items: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(title, icon: icon, tint: tint)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(tint).frame(width: 6, height: 6).padding(.top, 6)
                    Text(item)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var highlightsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("你写下的话", icon: "quote.opening")
            ForEach(report.highlights) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text("“\(item.response)”")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("— \(item.challengeTitle) · \(item.stepTitle)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(soft)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var statsBlock: some View {
        let stats: [(String, String)] = [
            ("\(report.challengesCompleted)", "完成挑战"),
            ("\(report.reflectionsCount)", "条反思"),
            ("\(report.reviewsCount)", "次复盘"),
            ("\(report.contactsCount)", "段关系"),
        ]
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                ForEach(stats, id: \.1) { value, label in
                    VStack(spacing: 4) {
                        Text(value).font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(.white)
                        Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(soft)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if !report.relationshipMix.isEmpty {
                Text("关系里的你：" + report.relationshipMix.map { "\($0.label) \($0.count)" }.joined(separator: " · "))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(soft)
            }
            if let average = report.averageReviewScore {
                Text("沟通复盘平均分 \(Int(average)) · Lv.\(report.level)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(soft)
            }
        }
        .padding(16)
        .background(panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var footerBlock: some View {
        HStack {
            Text("通过关系，认识自己。")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(mint)
            Spacer()
            Text(Date().formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(soft)
        }
    }

    private func sectionTitle(_ title: String, icon: String, tint: Color? = nil) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(tint ?? violet)
    }
}
