import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

private enum DailyQuoteDownload {
    // Set SoulMarkDownloadURL in Info.plist when the public download page is ready.
    static var qrImage: UIImage? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "SoulMarkDownloadURL") as? String,
              let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        // Four white modules on each edge provide the QR quiet zone.
        let bounds = output.extent.insetBy(dx: -4, dy: -4)
        let background = CIImage(color: CIColor(red: 1, green: 1, blue: 1)).cropped(to: bounds)
        let padded = output.composited(over: background).transformed(by: CGAffineTransform(scaleX: 6, y: 6))
        guard let image = CIContext().createCGImage(padded, from: padded.extent) else { return nil }
        return UIImage(cgImage: image)
    }
}

struct DailyQuoteSharePayload: Identifiable {
    enum RenderError: Error {
        case imageUnavailable
    }

    let id = UUID()
    let previewImage: UIImage
    let items: [Any]

    @MainActor
    static func make(quote: DailySoulQuote) throws -> DailyQuoteSharePayload {
        let renderer = ImageRenderer(content: DailyQuoteShareCard(quote: quote))
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: 540, height: 795)

        guard let image = renderer.uiImage else {
            throw RenderError.imageUnavailable
        }

        return DailyQuoteSharePayload(
            previewImage: image,
            items: [image, quote.shareText as NSString]
        )
    }
}

private struct DailyQuoteShareCard: View {
    let quote: DailySoulQuote
    private let qrImage = DailyQuoteDownload.qrImage

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.055, green: 0.060, blue: 0.075),
                    Color(red: 0.105, green: 0.075, blue: 0.105)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.96, green: 0.48, blue: 0.68).opacity(0.16))
                .frame(width: 420, height: 420)
                .blur(radius: 8)
                .offset(x: 220, y: -270)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()

                    Text("SOULMARK")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.48))
                }

                Spacer()

                Text("“")
                    .font(.system(size: 92, weight: .black, design: .serif))
                    .foregroundStyle(Color(red: 1.0, green: 0.32, blue: 0.62))
                    .frame(height: 62)

                Text(quote.text)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineSpacing(9)
                    .minimumScaleFactor(0.62)
                    .fixedSize(horizontal: false, vertical: true)

                Text("— \(quote.source)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.52))
                    .padding(.top, 24)

                Spacer()

                downloadFooter
            }
            .padding(48)
        }
        .frame(width: 540, height: 795)
        .clipped()
    }

    private var downloadFooter: some View {
        VStack(spacing: 22) {
            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(height: 1)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("SoulMark")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                    Text(localizedText("每天一句，清醒一点。", "A daily thought. A clearer day."))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.60))
                    Text(qrImage == nil
                         ? localizedText("下载入口即将开放", "Download coming soon")
                         : localizedText("扫码下载 SoulMark", "Scan to download SoulMark"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.56, blue: 0.76))
                }
                Spacer(minLength: 0)
                Group {
                    if let qrImage {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                    } else {
                        VStack(spacing: 9) {
                            Image(systemName: "arrow.down.app")
                                .font(.system(size: 27, weight: .medium))
                            Text(localizedText("敬请期待", "COMING SOON"))
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(Color.black.opacity(0.45))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(width: 112, height: 112)
                .padding(4)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
