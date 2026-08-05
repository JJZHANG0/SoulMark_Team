import SwiftUI
import UIKit

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
        renderer.proposedSize = ProposedViewSize(width: 540, height: 675)

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
                    Label(localizedText("今日毒鸡汤", "DAILY REALITY CHECK"), systemImage: "quote.opening")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.56, blue: 0.76))

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

                HStack {
                    Text(localizedText("每天一句，清醒一点。", "ONE THOUGHT. A CLEARER DAY."))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.46))

                    Spacer()

                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.56, blue: 0.76))
                }
            }
            .padding(48)
        }
        .frame(width: 540, height: 675)
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
