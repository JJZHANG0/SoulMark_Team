//
//  SoulTheme.swift
//  SoulMark
//

import SwiftUI
import Observation

@Observable
final class SoulPreferencesStore {
    static let shared = SoulPreferencesStore()

    var language: String {
        didSet { UserDefaults.standard.set(language, forKey: "soulMarkLanguage") }
    }

    var genderTheme: String {
        didSet { UserDefaults.standard.set(genderTheme, forKey: "soulMarkGenderTheme") }
    }

    var appearanceMode: String {
        didSet { UserDefaults.standard.set(appearanceMode, forKey: "soulMarkAppearanceMode") }
    }

    private init() {
        language = UserDefaults.standard.string(forKey: "soulMarkLanguage") ?? "zh"
        genderTheme = UserDefaults.standard.string(forKey: "soulMarkGenderTheme") ?? "male"
        appearanceMode = UserDefaults.standard.string(forKey: "soulMarkAppearanceMode") ?? "auto"
    }

    func apply(language: String, genderTheme: String, appearanceMode: String) {
        self.language = language
        self.genderTheme = genderTheme
        self.appearanceMode = appearanceMode
    }
}

var primaryTextColor: Color { SoulTheme.primaryText }
var secondaryTextColor: Color { SoulTheme.secondaryText }

func localizedText(_ chinese: String, _ english: String) -> String {
    SoulPreferencesStore.shared.language == "en" ? english : chinese
}

func isSoulNightMode() -> Bool {
    let mode = SoulPreferencesStore.shared.appearanceMode
    if mode == "night" { return true }
    if mode == "day" { return false }

    let hour = Calendar.current.component(.hour, from: Date())
    return hour < 7 || hour >= 19
}

enum SoulTheme {
    // Concentric, continuous radii aligned with modern Apple hardware and sheets.
    static let containerCornerRadius: CGFloat = 24
    static let controlCornerRadius: CGFloat = 16
    static let compactCornerRadius: CGFloat = 12

    static var isNight: Bool { isSoulNightMode() }

    static var isMale: Bool {
        SoulPreferencesStore.shared.genderTheme == "male"
    }

    static var background: Color {
        isNight ? Color(red: 0.035, green: 0.040, blue: 0.050) : Color(red: 0.945, green: 0.953, blue: 0.965)
    }

    static var surface: Color {
        isNight ? Color(red: 0.075, green: 0.085, blue: 0.105) : Color(red: 0.995, green: 0.997, blue: 1.0)
    }

    static var elevatedSurface: Color {
        isNight ? Color(red: 0.105, green: 0.115, blue: 0.140) : Color.white
    }

    static var visorSurface: Color {
        isNight ? Color(red: 0.065, green: 0.070, blue: 0.085) : Color(red: 0.075, green: 0.082, blue: 0.098)
    }

    static var primaryText: Color {
        isNight ? Color(red: 0.95, green: 0.96, blue: 0.98) : Color(red: 0.08, green: 0.09, blue: 0.11)
    }

    static var secondaryText: Color {
        isNight ? Color(red: 0.65, green: 0.68, blue: 0.74) : Color(red: 0.38, green: 0.40, blue: 0.45)
    }

    static var tertiaryText: Color {
        isNight ? Color.white.opacity(0.42) : Color.black.opacity(0.38)
    }

    static var accent: Color {
        if isMale {
            return isNight ? Color(red: 0.14, green: 0.58, blue: 0.98) : Color(red: 0.04, green: 0.43, blue: 0.82)
        }

        return isNight ? Color(red: 1.0, green: 0.32, blue: 0.62) : Color(red: 0.90, green: 0.25, blue: 0.50)
    }

    static var energy: Color {
        if isMale {
            return isNight ? Color(red: 0.18, green: 0.93, blue: 0.94) : Color(red: 0.02, green: 0.64, blue: 0.72)
        }

        return isNight ? Color(red: 1.0, green: 0.56, blue: 0.76) : Color(red: 0.96, green: 0.48, blue: 0.68)
    }

    static var support: Color {
        isMale ? Color(red: 0.34, green: 0.78, blue: 0.86) : Color(red: 0.98, green: 0.70, blue: 0.80)
    }

    static var pageGradient: LinearGradient {
        let lower = isNight
            ? Color(red: 0.055, green: 0.060, blue: 0.075)
            : (isMale ? Color(red: 0.91, green: 0.94, blue: 0.965) : Color(red: 0.97, green: 0.92, blue: 0.94))
        return LinearGradient(colors: [background, lower], startPoint: .top, endPoint: .bottom)
    }

    static var cardFill: Color {
        isNight ? elevatedSurface.opacity(0.82) : Color.white.opacity(0.86)
    }

    static var cardStroke: Color {
        isNight ? Color.white.opacity(0.11) : Color.black.opacity(0.07)
    }

    static var gridLine: Color {
        isNight ? Color.white.opacity(0.035) : Color.black.opacity(0.028)
    }

    static var subtleFill: Color {
        isNight ? Color.white.opacity(0.065) : Color.black.opacity(0.045)
    }

    static var accentSoft: Color {
        accent.opacity(isNight ? 0.24 : 0.12)
    }

    static var energySoft: Color {
        energy.opacity(isNight ? 0.20 : 0.10)
    }

    static var shadow: Color {
        isNight ? Color.black.opacity(0.48) : Color(red: 0.08, green: 0.10, blue: 0.14).opacity(0.12)
    }

    static let danger = Color(red: 0.88, green: 0.20, blue: 0.28)
    static let success = Color(red: 0.05, green: 0.62, blue: 0.48)
    static let warning = Color(red: 0.94, green: 0.61, blue: 0.14)
}

struct SoulBackground: View {
    var body: some View {
        ZStack {
            SoulTheme.pageGradient

            GeometryReader { proxy in
                Path { path in
                    for x in stride(from: 18.0, through: proxy.size.width, by: 42.0) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                    }

                    for y in stride(from: 12.0, through: proxy.size.height, by: 42.0) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    }
                }
                .stroke(SoulTheme.gridLine, lineWidth: 0.6)
            }

        }
        .ignoresSafeArea()
    }
}

struct SoulGlassCardBackground: View {
    var cornerRadius: CGFloat = SoulTheme.containerCornerRadius
    var accented = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(SoulTheme.cardFill)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(SoulTheme.cardStroke, lineWidth: 1)
            )
            .shadow(color: SoulTheme.shadow, radius: 18, x: 0, y: 10)
    }
}

struct SoulVisorPanelBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(SoulTheme.visorSurface)
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            }
            .shadow(color: SoulTheme.energy.opacity(0.10), radius: 24, x: 0, y: 10)
    }
}

struct SoulLiquidGlassBackground: View {
    var cornerRadius: CGFloat = 30

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(.ultraThinMaterial)
            .background(
                shape.fill(SoulTheme.cardFill.opacity(SoulTheme.isNight ? 0.46 : 0.34))
            )
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(SoulTheme.isNight ? 0.16 : 0.58),
                            Color.white.opacity(0.05),
                            SoulTheme.accent.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.plusLighter)
            }
            .overlay {
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(SoulTheme.isNight ? 0.30 : 0.78),
                            Color.white.opacity(0.08),
                            SoulTheme.cardStroke
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.white.opacity(SoulTheme.isNight ? 0.12 : 0.34))
                    .frame(width: 118, height: 1)
                    .padding(.top, 1)
                    .blur(radius: 0.35)
            }
            .shadow(color: SoulTheme.shadow.opacity(0.78), radius: 28, x: 0, y: 16)
    }
}

struct SoulLiquidGlassSelection: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.thinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(SoulTheme.isNight ? 0.20 : 0.72),
                                SoulTheme.accent.opacity(0.10),
                                Color.white.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.plusLighter)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(SoulTheme.isNight ? 0.36 : 0.90),
                                Color.white.opacity(0.12)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
            }
            .shadow(color: SoulTheme.accent.opacity(0.12), radius: 9, x: 0, y: 5)
    }
}

struct SoulGlassCapsule: View {
    var isActive = false

    var body: some View {
        Capsule()
            .fill(isActive ? SoulTheme.accentSoft : SoulTheme.cardFill)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isActive ? SoulTheme.accent.opacity(0.42) : SoulTheme.cardStroke, lineWidth: 1)
            )
    }
}

struct SoulMascotFigure: View {
    var height: CGFloat
    var haloIntensity: CGFloat = 1

    var body: some View {
        Image("SoulMascot")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .shadow(color: SoulTheme.energy.opacity(0.24 * haloIntensity), radius: 8 * haloIntensity, x: 0, y: 2)
            .shadow(color: SoulTheme.accent.opacity(0.18 * haloIntensity), radius: 12 * haloIntensity, x: 0, y: 4)
            .accessibilityHidden(true)
    }
}

struct SoulIconButton: View {
    let systemImage: String
    var isEmphasized = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(isEmphasized ? Color.white : SoulTheme.primaryText)
                .frame(width: 42, height: 42)
                .background(isEmphasized ? SoulTheme.accent : SoulTheme.cardFill, in: Circle())
                .overlay(Circle().stroke(isEmphasized ? SoulTheme.accent.opacity(0.55) : SoulTheme.cardStroke, lineWidth: 1))
                .shadow(color: isEmphasized ? SoulTheme.accent.opacity(0.24) : .clear, radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

struct SoulPageHeader<Trailing: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let trailing: Trailing

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Capsule()
                        .fill(SoulTheme.energy)
                        .frame(width: 26, height: 3)

                    Text(eyebrow.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(SoulTheme.energy)
                }

                Text(title)
                    .font(.system(size: 29, weight: .heavy, design: .rounded))
                    .foregroundStyle(SoulTheme.primaryText)

                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(SoulTheme.secondaryText)
                    .lineSpacing(2)
            }

            Spacer(minLength: 8)
            trailing
        }
    }
}

extension SoulPageHeader where Trailing == EmptyView {
    init(eyebrow: String, title: String, subtitle: String) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct SoulSectionHeader: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(SoulTheme.primaryText)

            Spacer()

            if let detail {
                Text(detail.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(SoulTheme.tertiaryText)
            }
        }
    }
}

struct SoulStatusPill: View {
    let text: String
    var systemImage = "circle.fill"

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(SoulTheme.energy)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color.white.opacity(0.07), in: Capsule())
            .overlay(Capsule().stroke(SoulTheme.energy.opacity(0.28), lineWidth: 1))
    }
}
