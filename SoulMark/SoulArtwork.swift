import SwiftUI

enum SoulArtwork {
    static let tabHome = "SoulTabHome"
    static let tabMap = "SoulTabMap"
    static let tabPractice = "SoulTabPractice"
    static let tabReview = "SoulTabReview"
    static let tabProfile = "SoulTabProfile"
    static let signal = "SoulSignal"
    static let categoryConfidant = "SoulCategoryConfidant"
    static let emptyMirror = "SoulEmptyMirror"
    static let emptyMap = "SoulEmptyMap"
    static let emptyReview = "SoulEmptyReview"

    static func tabAsset(_ section: AppSection) -> String {
        switch section {
        case .home: tabHome
        case .relationshipGraph: tabMap
        case .scenarioSimulation: tabPractice
        case .journal: tabReview
        case .profile: tabProfile
        }
    }

    static func modeAsset(id: String) -> String? {
        switch id {
        case "conflict": "SoulModeConflict"
        case "apology": "SoulModeApology"
        case "boundary": "SoulModeBoundary"
        case "interview": "SoulModeInterview"
        default: nil
        }
    }

    /// Pure single-color glyphs keep the surrounding accent tint.
    static func modeIsTemplate(id: String) -> Bool {
        id == "conflict" || id == "apology" || id == "interview"
    }

    static func challengeAsset(symbol: String) -> String? {
        switch symbol {
        case "eye.trianglebadge.exclamationmark": "SoulChallengeBlindSpot"
        case "window.casement": "SoulChallengeOpenWindow"
        case "safari": "SoulChallengeValues"
        case "person.text.rectangle": "SoulChallengeSelfConcept"
        case "heart.text.square": "SoulChallengeEmotion"
        case "pause.circle": "SoulChallengePause"
        case "circle.hexagongrid": "SoulChallengeWheel"
        case "person.2.wave.2": "SoulChallengeRelationMirror"
        case "person.crop.rectangle": "SoulChallengeSeen"
        case "clock.arrow.circlepath": "SoulChallengeEnergy"
        case "person.3.sequence": "SoulChallengeRole"
        default: nil
        }
    }

    static func titleAsset(level: Int) -> String? {
        switch level {
        case 3: "SoulTitleListener"
        case 5: "SoulTitleCommunicator"
        case 10: "SoulTitleEmpathy"
        case 20: "SoulTitleMaster"
        default: nil
        }
    }
}

struct SoulSlotIcon: View {
    let asset: String
    var template = false

    var body: some View {
        Image(asset)
            .renderingMode(template ? .template : .original)
            .resizable()
            .scaledToFit()
    }
}

struct SoulModeIcon: View {
    let mode: ScenarioMode
    var pointSize: CGFloat = 15

    var body: some View {
        if let asset = SoulArtwork.modeAsset(id: mode.id) {
            SoulSlotIcon(asset: asset, template: SoulArtwork.modeIsTemplate(id: mode.id))
                .frame(width: pointSize, height: pointSize)
        } else {
            Image(systemName: mode.systemImage)
                .font(.system(size: pointSize, weight: .bold))
        }
    }
}
