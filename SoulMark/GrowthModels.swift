import Foundation

struct GrowthSnapshot: Decodable, Equatable {
    let balance: Int
    let level: Int
    let levelExperience: Int
    let nextLevelExperience: Int
    let peakLevel: Int
    let chatExperienceToday: Int
    let titleKey: String
    let nextTitleLevel: Int?
    let decayedExperience: Int
    let nextDecayDate: String

    enum CodingKeys: String, CodingKey {
        case balance, level
        case levelExperience = "level_experience"
        case nextLevelExperience = "next_level_experience"
        case peakLevel = "peak_level"
        case chatExperienceToday = "chat_experience_today"
        case titleKey = "title_key"
        case nextTitleLevel = "next_title_level"
        case decayedExperience = "decayed_experience"
        case nextDecayDate = "next_decay_date"
    }

    var progress: Double { min(1, max(0, Double(levelExperience) / Double(max(1, nextLevelExperience)))) }
    var currentMilestone: GrowthMilestone { GrowthMilestone.all.last { $0.level <= level } ?? GrowthMilestone.all[0] }
    var unlockedMilestones: [GrowthMilestone] { GrowthMilestone.all.filter { $0.level <= peakLevel } }
}

struct GrowthMilestone: Identifiable {
    let level: Int
    let chinese: String
    let english: String
    let icon: String
    var id: Int { level }
    var title: String { localizedText(chinese, english) }
    static let all = [
        GrowthMilestone(level: 1, chinese: "关系探索者", english: "Relationship Explorer", icon: "sparkle"),
        GrowthMilestone(level: 3, chinese: "倾听学徒", english: "Thoughtful Listener", icon: "ear.badge.waveform"),
        GrowthMilestone(level: 5, chinese: "沟通达人", english: "Skilled Communicator", icon: "bubble.left.and.bubble.right.fill"),
        GrowthMilestone(level: 10, chinese: "共情专家", english: "Empathy Expert", icon: "heart.text.clipboard.fill"),
        GrowthMilestone(level: 20, chinese: "关系大师", english: "Relationship Master", icon: "crown.fill")
    ]
}

enum GrowthLoadState: Equatable {
    case loading
    case loaded(GrowthSnapshot)
    case failed
    var snapshot: GrowthSnapshot? {
        if case .loaded(let value) = self { return value }
        return nil
    }
}

struct GrowthRequestGuard {
    private var current = UUID()
    mutating func begin() -> UUID { current = UUID(); return current }
    mutating func invalidate() { current = UUID() }
    func accepts(_ id: UUID) -> Bool { current == id }
}

struct GrowthChatMessage: Encodable, Equatable {
    let role: String
    let text: String
    static func from(_ events: [RealtimeTranscriptEvent]) -> [GrowthChatMessage] {
        events.map { GrowthChatMessage(role: $0.role == .user ? "user" : "assistant", text: $0.text) }
    }
}

struct PendingGrowthPractice: Identifiable {
    let id: UUID
    let ownerID: UUID
    let duration: Int
    let participant: String
    let mode: String
    let guidance: String
    let messages: [GrowthChatMessage]
}

struct GrowthFeedback: Identifiable {
    let id = UUID()
    let awarded: Int
    let decayed: Int
    let newLevel: Int?
}

/// Owns the immutable save identity until a call is finalized, including failed calls.
struct GrowthCallCapture {
    private struct Context {
        let id = UUID()
        let participant: String
        let mode: String
        let guidance: String
    }
    private var context: Context?

    mutating func begin(participant: String, mode: String, guidance: String) {
        context = Context(participant: participant, mode: mode, guidance: guidance)
    }

    mutating func finish(ownerID: UUID, duration: Int, events: [RealtimeTranscriptEvent]) -> PendingGrowthPractice? {
        guard let current = context else { return nil }
        context = nil
        let messages = GrowthChatMessage.from(events)
        guard messages.contains(where: { $0.role == "user" && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return nil }
        return PendingGrowthPractice(id: current.id, ownerID: ownerID, duration: duration, participant: current.participant, mode: current.mode, guidance: current.guidance, messages: messages)
    }
}
