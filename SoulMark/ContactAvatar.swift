import SwiftUI
import UIKit

enum BackendURLResolver {
    static var configuredBaseURL: String {
        UserDefaults.standard.string(forKey: "soulMarkBackendURL")
            ?? RealtimeVoiceServiceConfiguration.defaultBackendURL
    }

    static func apiURL(_ path: String, baseURL: String = configuredBaseURL) -> URL? {
        guard let base = URL(string: baseURL) else { return nil }
        return URL(string: path, relativeTo: base)?.absoluteURL
    }

    static func mediaURL(_ value: String?, baseURL: String = configuredBaseURL) -> URL? {
        guard let value, !value.isEmpty else { return nil }
        if let absolute = URL(string: value), absolute.scheme != nil {
            return absolute
        }
        return apiURL(value, baseURL: baseURL)
    }
}

enum ContactAvatarImageProcessor {
    enum ProcessingError: Error {
        case invalidImage
        case encodingFailed
    }

    static func prepare(_ data: Data) throws -> Data {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
            throw ProcessingError.invalidImage
        }

        let outputSide = min(1_024, min(image.size.width, image.size.height))
        let scale = max(outputSide / image.size.width, outputSide / image.size.height)
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let drawOrigin = CGPoint(
            x: (outputSide - drawSize.width) / 2,
            y: (outputSide - drawSize.height) / 2
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: outputSide, height: outputSide),
            format: format
        )
        let square = renderer.image { _ in
            image.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        }
        guard let jpeg = square.jpegData(compressionQuality: 0.82) else {
            throw ProcessingError.encodingFailed
        }
        return jpeg
    }
}

struct ContactAvatarView: View {
    let avatarPath: String?
    let color: Color
    let symbol: String
    let size: CGFloat

    var body: some View {
        Group {
            if let url = BackendURLResolver.mediaURL(avatarPath) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(SoulTheme.cardStroke, lineWidth: 1))
    }

    private var fallback: some View {
        ZStack {
            Circle().fill(color.opacity(SoulTheme.isNight ? 0.24 : 0.14))
            Image(systemName: symbol)
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}
