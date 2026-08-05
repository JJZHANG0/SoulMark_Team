//
//  SoulModels.swift
//  SoulMark
//

import SwiftUI

enum FreeRelationshipPolicy {
    static let maximumPeople = 5

    static func canAddPerson(currentCount: Int) -> Bool {
        currentCount < maximumPeople
    }
}

enum ScenarioParticipantAccessPolicy {
    static let freeLimit = 2

    static func isUnlocked(index: Int) -> Bool {
        index >= 0 && index < freeLimit
    }

    static func isUnlocked(participantID: String, in participantIDs: [String]) -> Bool {
        guard let index = participantIDs.firstIndex(of: participantID) else {
            return false
        }
        return isUnlocked(index: index)
    }

    static func canAddParticipant(currentCount: Int) -> Bool {
        currentCount < freeLimit
    }
}

struct RelationshipLabelLayout: Equatable {
    let horizontalDirection: Int
}

enum RelationshipLabelPlacement {
    static func layout(node: CGPoint, center: CGPoint) -> RelationshipLabelLayout {
        RelationshipLabelLayout(horizontalDirection: node.x >= center.x ? 1 : -1)
    }
}

struct AchievementProgress: Equatable {
    var peopleCount: Int
    var practiceCount: Int
    var reviewCount: Int
    var relationshipCategoryCount: Int

    static let empty = AchievementProgress(
        peopleCount: 0,
        practiceCount: 0,
        reviewCount: 0,
        relationshipCategoryCount: 0
    )
}

struct SoulAchievement: Identifiable {
    let id: String
    let chineseTitle: String
    let englishTitle: String
    let chineseRequirement: String
    let englishRequirement: String
    let systemImage: String
    let isUnlocked: Bool

    var title: String {
        localizedText(chineseTitle, englishTitle)
    }

    var requirement: String {
        localizedText(chineseRequirement, englishRequirement)
    }

    static func all(progress: AchievementProgress) -> [SoulAchievement] {
        [
            SoulAchievement(
                id: "first-connection",
                chineseTitle: "初次连接",
                englishTitle: "First Connection",
                chineseRequirement: "在关系网中添加 1 个人",
                englishRequirement: "Add 1 person to your map",
                systemImage: "person.crop.circle.badge.plus",
                isUnlocked: progress.peopleCount >= 1
            ),
            SoulAchievement(
                id: "inner-circle",
                chineseTitle: "五人小队",
                englishTitle: "Inner Circle",
                chineseRequirement: "在关系网中添加 5 个人",
                englishRequirement: "Add 5 people to your map",
                systemImage: "person.3.fill",
                isUnlocked: progress.peopleCount >= 5
            ),
            SoulAchievement(
                id: "first-practice",
                chineseTitle: "第一次开口",
                englishTitle: "First Practice",
                chineseRequirement: "完成 1 次情景模拟",
                englishRequirement: "Complete 1 simulation",
                systemImage: "waveform.and.mic",
                isUnlocked: progress.practiceCount >= 1
            ),
            SoulAchievement(
                id: "reflection-starter",
                chineseTitle: "复盘起点",
                englishTitle: "Reflection Starter",
                chineseRequirement: "完成 1 次沟通复盘",
                englishRequirement: "Complete 1 conversation review",
                systemImage: "text.bubble.fill",
                isUnlocked: progress.reviewCount >= 1
            ),
            SoulAchievement(
                id: "clear-voice",
                chineseTitle: "表达渐清晰",
                englishTitle: "Clear Voice",
                chineseRequirement: "完成 3 次情景模拟",
                englishRequirement: "Complete 3 simulations",
                systemImage: "sparkles",
                isUnlocked: progress.practiceCount >= 3
            ),
            SoulAchievement(
                id: "relationship-explorer",
                chineseTitle: "关系探索者",
                englishTitle: "Relationship Explorer",
                chineseRequirement: "使用 3 种不同关系类型",
                englishRequirement: "Use 3 relationship categories",
                systemImage: "point.3.connected.trianglepath.dotted",
                isUnlocked: progress.relationshipCategoryCount >= 3
            )
        ]
    }
}

enum RelationshipFilter: String, CaseIterable, Identifiable {
    case all
    case confidant
    case friend
    case family
    case collaborator
    case classmate
    case newContact
    case lightTie
    case distant

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: localizedText("全部", "All")
        case .confidant: localizedText("知己", "Close")
        case .friend: localizedText("好友", "Friend")
        case .family: localizedText("家庭", "Family")
        case .collaborator: localizedText("合作", "Work")
        case .classmate: localizedText("同路", "Peer")
        case .newContact: localizedText("新识", "New")
        case .lightTie: localizedText("浅交", "Light")
        case .distant: localizedText("远联", "Distant")
        }
    }

    var subtitle: String {
        switch self {
        case .all: localizedText("关系全景", "Full view")
        case .confidant: localizedText("深度联结", "Deep bond")
        case .friend: localizedText("舒适同频", "Easy rhythm")
        case .family: localizedText("亲密家人", "Close family")
        case .collaborator: localizedText("一起做事", "Do things together")
        case .classmate: localizedText("同频同行", "Shared path")
        case .newContact: localizedText("刚刚认识", "Recently met")
        case .lightTie: localizedText("轻度联系", "Light contact")
        case .distant: localizedText("很久未见", "Long time no see")
        }
    }

    var category: RelationshipCategory? {
        switch self {
        case .all: nil
        case .confidant: .confidant
        case .friend: .friend
        case .family: .family
        case .collaborator: .collaborator
        case .classmate: .classmate
        case .newContact: .newContact
        case .lightTie: .lightTie
        case .distant: .distant
        }
    }

    var tint: Color {
        category?.color ?? SoulTheme.energy
    }

    var systemImage: String {
        switch self {
        case .all: "circle.grid.2x2.fill"
        case .confidant: "heart.fill"
        case .friend: "sparkles"
        case .family: "house.fill"
        case .collaborator: "hammer.fill"
        case .classmate: "point.topleft.down.curvedto.point.bottomright.up"
        case .newContact: "person.badge.plus"
        case .lightTie: "paperplane.fill"
        case .distant: "moon.stars.fill"
        }
    }

    func filteredPeople(from people: [RelationshipPerson]) -> [RelationshipPerson] {
        guard let category else { return people }
        return people.filter { $0.category == category }
    }
}

enum RelationshipCategory: Identifiable, Equatable, Hashable {
    case confidant
    case friend
    case family
    case collaborator
    case classmate
    case newContact
    case lightTie
    case distant
    case custom(String)

    static let builtIns: [RelationshipCategory] = [
        .confidant,
        .friend,
        .family,
        .collaborator,
        .classmate,
        .newContact,
        .lightTie,
        .distant
    ]

    var id: String {
        switch self {
        case .confidant: "confidant"
        case .friend: "friend"
        case .family: "family"
        case .collaborator: "collaborator"
        case .classmate: "classmate"
        case .newContact: "new-contact"
        case .lightTie: "light-tie"
        case .distant: "distant"
        case .custom(let name): "custom-\(name)"
        }
    }

    var apiValue: String { id }

    static func fromAPIValue(_ value: String) -> RelationshipCategory {
        if let builtIn = builtIns.first(where: { $0.id == value }) {
            return builtIn
        }
        return .custom(value.hasPrefix("custom-") ? String(value.dropFirst(7)) : value)
    }

    var displayTitle: String {
        switch self {
        case .confidant: localizedText("知己", "Confidant")
        case .friend: localizedText("好友", "Friend")
        case .family: localizedText("家人", "Family")
        case .collaborator: localizedText("合作伙伴", "Collaborator")
        case .classmate: localizedText("同路人", "Peer")
        case .newContact: localizedText("新认识", "New Contact")
        case .lightTie: localizedText("浅交", "Light Tie")
        case .distant: localizedText("远联系", "Distant Tie")
        case .custom(let name): name
        }
    }

    var shortTitle: String {
        switch self {
        case .confidant: localizedText("知己", "Close")
        case .friend: localizedText("好友", "Friend")
        case .family: localizedText("家人", "Family")
        case .collaborator: localizedText("合作", "Work")
        case .classmate: localizedText("同路", "Peer")
        case .newContact: localizedText("新识", "New")
        case .lightTie: localizedText("浅交", "Light")
        case .distant: localizedText("远联", "Distant")
        case .custom(let name): name
        }
    }

    var color: Color {
        switch self {
        case .confidant: SoulTheme.accent
        case .friend: SoulTheme.support
        case .family: SoulTheme.accent.opacity(0.82)
        case .collaborator: SoulTheme.secondaryText
        case .classmate: SoulTheme.support.opacity(0.86)
        case .newContact: SoulTheme.accent.opacity(0.58)
        case .lightTie: SoulTheme.secondaryText.opacity(0.72)
        case .distant: SoulTheme.secondaryText.opacity(0.54)
        case .custom: SoulTheme.accent.opacity(0.78)
        }
    }

    var isDashed: Bool {
        switch self {
        case .newContact, .lightTie, .distant:
            true
        default:
            false
        }
    }

    var systemImage: String {
        switch self {
        case .confidant: "heart.fill"
        case .friend: "sparkles"
        case .family: "house.fill"
        case .collaborator: "hammer.fill"
        case .classmate: "point.topleft.down.curvedto.point.bottomright.up"
        case .newContact: "person.badge.plus"
        case .lightTie: "paperplane.fill"
        case .distant: "moon.stars.fill"
        case .custom: "tag.fill"
        }
    }

    func filteredPeople(from people: [RelationshipPerson]) -> [RelationshipPerson] {
        people.filter { $0.category == self }
    }
}

struct RelationshipPerson: Identifiable, Equatable {
    var id: UUID = UUID()
    let name: String
    let note: String
    var category: RelationshipCategory
    let strength: Double
    var position: CGPoint
    let avatarColors: [Color]
    let symbol: String
    let memory: String
    var avatarURL: String? = nil

    static func == (lhs: RelationshipPerson, rhs: RelationshipPerson) -> Bool {
        lhs.id == rhs.id
    }

    var displayNote: String {
        switch name {
        case "Torin": localizedText(note, "Long time no contact")
        case "Wren": localizedText(note, "Deep listener")
        case "Rhea": localizedText(note, "Warm and free")
        case "Jasper": localizedText(note, "Thought partner")
        case "Hugo": localizedText(note, "Someone from the past")
        case "Feel": localizedText(note, "Playful idea buddy")
        case "Zora": localizedText(note, "Light short-term companion")
        case "Lune": localizedText(note, "Brief encounter")
        case "Beau": localizedText(note, "Cared-for family member")
        case "Owen": localizedText(note, "Easygoing playmate")
        case "Silas": localizedText(note, "Inspires new thinking")
        case "Vivi": localizedText(note, "Shared memories")
        case "Kai": localizedText(note, "Inspiration observer")
        case "Marduk": localizedText(note, "Old acquaintance far away")
        default: note
        }
    }

    var displayMemory: String {
        switch name {
        case "Torin": localizedText(memory, "You met during school days and still think of them sometimes.")
        case "Wren": localizedText(memory, "A recent long talk helped you clarify your goals again.")
        case "Rhea": localizedText(memory, "They can make difficult things feel lighter.")
        case "Jasper": localizedText(memory, "You often exchange different perspectives on the same question.")
        case "Hugo": localizedText(memory, "You once completed an important milestone together.")
        case "Feel": localizedText(memory, "Good for playing, brainstorming, and creating joy together.")
        case "Zora": localizedText(memory, "Being together feels low-pressure, with occasional updates.")
        case "Lune": localizedText(memory, "The tie is still light, but carries a gentle family feeling.")
        case "Beau": localizedText(memory, "A steady presence in your family circle.")
        case "Owen": localizedText(memory, "You do not need to explain too much around him.")
        case "Silas": localizedText(memory, "He often brings you new paths of thinking.")
        case "Vivi": localizedText(memory, "Some memories remain, while interaction slowly becomes less frequent.")
        case "Kai": localizedText(memory, "You notice their updates, but rarely contact them directly.")
        case "Marduk": localizedText(memory, "The name is still on the map, but the relationship has become light.")
        default: memory
        }
    }
}

struct ScenarioParticipant: Identifiable, Equatable {
    let id: String
    let name: String
    let note: String
    let relationshipLabel: String
    let color: Color
    let symbol: String
    let isCustom: Bool

    static func from(_ person: RelationshipPerson) -> ScenarioParticipant {
        ScenarioParticipant(
            id: person.id.uuidString,
            name: person.name,
            note: person.displayNote,
            relationshipLabel: person.category.shortTitle,
            color: person.category.color,
            symbol: person.symbol,
            isCustom: false
        )
    }

    static func custom(name: String, note: String, relationshipLabel: String) -> ScenarioParticipant {
        ScenarioParticipant(
            id: "custom-\(UUID().uuidString)",
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? localizedText("自定义模拟对象", "Custom simulation partner") : note.trimmingCharacters(in: .whitespacesAndNewlines),
            relationshipLabel: relationshipLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? localizedText("自定义", "Custom") : relationshipLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            color: SoulTheme.accent,
            symbol: "person.crop.circle.badge.questionmark",
            isCustom: true
        )
    }

    static var soul: ScenarioParticipant {
        ScenarioParticipant(
            id: "soul-ai",
            name: "Soul",
            note: localizedText("你的 AI 沟通陪练", "Your AI communication partner"),
            relationshipLabel: localizedText("AI 陪练", "AI Coach"),
            color: SoulTheme.accent,
            symbol: "waveform.and.mic",
            isCustom: false
        )
    }
}

extension Array where Element == ScenarioParticipant {
    func withSoulFallback() -> [ScenarioParticipant] {
        isEmpty ? [.soul] : self
    }
}

struct ScenarioMode: Identifiable, Equatable {
    let id: String
    let title: String
    let guidance: String
    let systemImage: String
    let isCustom: Bool

    static let defaultModes: [ScenarioMode] = [
        ScenarioMode(id: "conflict", title: "冲突沟通", guidance: "先说事实，再说感受，最后提出你希望的改变。", systemImage: "bolt.heart.fill", isCustom: false),
        ScenarioMode(id: "apology", title: "道歉修复", guidance: "先承认影响，再解释原因，不急着为自己辩护。", systemImage: "heart.text.square.fill", isCustom: false),
        ScenarioMode(id: "boundary", title: "设立边界", guidance: "把边界说清楚，同时保留对对方的尊重。", systemImage: "hand.raised.fill", isCustom: false),
        ScenarioMode(id: "interview", title: "面试练习", guidance: "回答保持具体，用一个真实经历支撑观点。", systemImage: "person.text.rectangle.fill", isCustom: false)
    ]

    var displayTitle: String {
        switch id {
        case "conflict": localizedText(title, "Conflict Talk")
        case "apology": localizedText(title, "Repair Apology")
        case "boundary": localizedText(title, "Set Boundaries")
        case "interview": localizedText(title, "Interview Practice")
        default: title
        }
    }

    var displayGuidance: String {
        switch id {
        case "conflict": localizedText(guidance, "Start with facts, then feelings, then the change you hope for.")
        case "apology": localizedText(guidance, "Acknowledge the impact first, then explain without rushing to defend yourself.")
        case "boundary": localizedText(guidance, "Make the boundary clear while keeping respect for the other person.")
        case "interview": localizedText(guidance, "Keep your answer specific and support it with one real experience.")
        default: guidance
        }
    }
}

struct RecordingTimer: Equatable {
    private(set) var elapsedSeconds = 0
    private(set) var isRunning = false

    var displayText: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    mutating func start() {
        elapsedSeconds = 0
        isRunning = true
    }

    mutating func stop() {
        isRunning = false
    }

    mutating func cancel() {
        elapsedSeconds = 0
        isRunning = false
    }

    mutating func finish() -> Int {
        let submittedSeconds = elapsedSeconds
        elapsedSeconds = 0
        isRunning = false
        return submittedSeconds
    }

    mutating func tick() {
        guard isRunning else { return }
        elapsedSeconds += 1
    }
}

extension Array where Element == ScenarioMode {
    mutating func addCustomMode(title: String, guidance: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let trimmedGuidance = guidance.trimmingCharacters(in: .whitespacesAndNewlines)
        append(
            ScenarioMode(
                id: "custom-\(UUID().uuidString)",
                title: trimmedTitle,
                guidance: trimmedGuidance.isEmpty ? localizedText("按你设定的情景自由练习表达。", "Practice freely in the situation you created.") : trimmedGuidance,
                systemImage: "slider.horizontal.3",
                isCustom: true
            )
        )
    }
}

extension Array where Element == ScenarioParticipant {
    mutating func deleteCustomParticipant(_ id: ScenarioParticipant.ID) {
        removeAll { participant in
            participant.id == id && participant.isCustom
        }
    }
}

struct ScenarioMessage: Identifiable, Equatable {
    let id = UUID()
    let speaker: String
    let text: String
    let isUser: Bool

    static let sample: [ScenarioMessage] = [
        ScenarioMessage(speaker: "AI", text: localizedText("我会按真实语气回应，也会提醒你表达是否清楚。", "I will respond naturally and help you notice whether your message is clear."), isUser: false),
        ScenarioMessage(speaker: localizedText("你", "You"), text: localizedText("我想练习一次比较难开口的沟通。", "I want to practice a conversation that feels hard to start."), isUser: true)
    ]
}

struct ScenarioConversationSession: Identifiable, Equatable {
    let id = UUID()
    let participantID: ScenarioParticipant.ID?
    let participantName: String
    let date: Date
    let messages: [ScenarioMessage]

    var dateText: String {
        date.formatted(date: .numeric, time: .shortened)
    }

    func matches(_ query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return true }

        return participantName.localizedCaseInsensitiveContains(trimmedQuery) ||
        messages.contains { message in
            message.speaker.localizedCaseInsensitiveContains(trimmedQuery) ||
            message.text.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }
}

enum ReviewSource: String, CaseIterable, Identifiable {
    case scenario
    case wechat
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scenario: localizedText("情景模拟", "Simulation")
        case .wechat: localizedText("微信聊天", "WeChat Chat")
        case .manual: localizedText("手动记录", "Manual Note")
        }
    }

    var systemImage: String {
        switch self {
        case .scenario: "figure.wave"
        case .wechat: "message.fill"
        case .manual: "square.and.pencil"
        }
    }
}

struct ConversationReviewRecord: Identifiable, Equatable {
    var id: UUID = UUID()
    let title: String
    let source: ReviewSource
    let date: Date
    let transcript: String
    let score: Int
    let reason: String
    let advice: String

    static func make(title: String, source: ReviewSource, transcript: String, date: Date = Date()) -> ConversationReviewRecord {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let clarityBonus = trimmedTranscript.contains("我") ? 8 : 0
        let actionBonus = trimmedTranscript.contains("下次") || trimmedTranscript.contains("希望") ? 8 : 0
        let lengthBonus = min(trimmedTranscript.count / 18, 16)
        let score = min(96, 64 + clarityBonus + actionBonus + lengthBonus)

        return ConversationReviewRecord(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? localizedText("未命名复盘", "Untitled Review") : title.trimmingCharacters(in: .whitespacesAndNewlines),
            source: source,
            date: date,
            transcript: trimmedTranscript,
            score: score,
            reason: localizedText("分数主要来自表达清晰度、是否说明感受、是否提出下一步行动。", "The score mainly reflects clarity, whether feelings were explained, and whether a next step was proposed."),
            advice: score >= 85 ? localizedText("整体表达较完整，可以继续练习更自然的语气。", "The message is mostly complete. Keep practicing a more natural tone.") : localizedText("建议补充你的感受和具体需求，让对方更容易回应。", "Add your feelings and specific needs so the other person can respond more easily.")
        )
    }

    func matches(source selectedSource: ReviewSource?, query: String) -> Bool {
        if let selectedSource, source != selectedSource {
            return false
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return true }

        return title.localizedCaseInsensitiveContains(trimmedQuery) ||
        transcript.localizedCaseInsensitiveContains(trimmedQuery) ||
        source.title.localizedCaseInsensitiveContains(trimmedQuery)
    }
}

enum RelationshipSampleData {
    static let people: [RelationshipPerson] = [
        .init(name: "Torin", note: "很久未曾联系", category: .distant, strength: 0.28, position: CGPoint(x: 0.16, y: 0.16), avatarColors: [.mint.opacity(0.35), .orange.opacity(0.28)], symbol: "leaf.fill", memory: "学生时期认识，偶尔想起对方。"),
        .init(name: "Wren", note: "能够深度倾诉", category: .confidant, strength: 0.88, position: CGPoint(x: 0.24, y: 0.34), avatarColors: [.cyan, .orange], symbol: "sunset.fill", memory: "最近一次长聊让你重新梳理了自己的目标。"),
        .init(name: "Rhea", note: "热烈且自由", category: .confidant, strength: 0.82, position: CGPoint(x: 0.78, y: 0.23), avatarColors: [.orange, .pink], symbol: "figure.run", memory: "总能把低落的事情讲得轻一点。"),
        .init(name: "Jasper", note: "思想交流伙伴", category: .friend, strength: 0.64, position: CGPoint(x: 0.80, y: 0.38), avatarColors: [.blue.opacity(0.6), .green.opacity(0.45)], symbol: "book.closed.fill", memory: "你们常在一个问题上交换不同角度。"),
        .init(name: "Hugo", note: "停留在过去的人", category: .collaborator, strength: 0.38, position: CGPoint(x: 0.82, y: 0.51), avatarColors: [.brown, .teal.opacity(0.4)], symbol: "moon.fill", memory: "曾经一起完成过一个重要节点。"),
        .init(name: "Feel", note: "脑洞丰富的玩伴", category: .friend, strength: 0.72, position: CGPoint(x: 0.76, y: 0.64), avatarColors: [.yellow, .red.opacity(0.65)], symbol: "sparkles", memory: "适合一起玩、发散想法、制造快乐。"),
        .init(name: "Zora", note: "轻松短暂的相伴", category: .classmate, strength: 0.48, position: CGPoint(x: 0.64, y: 0.74), avatarColors: [.blue, .yellow.opacity(0.7)], symbol: "face.smiling", memory: "相处没有压力，偶尔同步近况。"),
        .init(name: "Lune", note: "一面之缘", category: .family, strength: 0.42, position: CGPoint(x: 0.50, y: 0.82), avatarColors: [.yellow, .green.opacity(0.5)], symbol: "heart.circle.fill", memory: "关系还浅，但带着温柔的家庭感。"),
        .init(name: "Beau", note: "被照顾的小家人", category: .family, strength: 0.58, position: CGPoint(x: 0.67, y: 0.90), avatarColors: [.orange.opacity(0.35), .white], symbol: "house.fill", memory: "家庭里的安定存在。"),
        .init(name: "Owen", note: "轻松自在的玩伴", category: .friend, strength: 0.78, position: CGPoint(x: 0.35, y: 0.78), avatarColors: [.red, .orange.opacity(0.6)], symbol: "gamecontroller.fill", memory: "和他在一起时不用解释太多。"),
        .init(name: "Silas", note: "予思路启发", category: .classmate, strength: 0.52, position: CGPoint(x: 0.20, y: 0.66), avatarColors: [.pink.opacity(0.75), .yellow.opacity(0.55)], symbol: "pencil.and.outline", memory: "他常带来新的思考路径。"),
        .init(name: "Vivi", note: "共同回忆", category: .lightTie, strength: 0.34, position: CGPoint(x: 0.16, y: 0.51), avatarColors: [.green, .blue.opacity(0.45)], symbol: "mountain.2.fill", memory: "一些记忆还在，但互动慢慢变少。"),
        .init(name: "Kai", note: "灵感观察者", category: .lightTie, strength: 0.30, position: CGPoint(x: 0.70, y: 0.14), avatarColors: [.gray.opacity(0.45), .yellow.opacity(0.35)], symbol: "eye.fill", memory: "你会留意他的动态，但不常直接联系。"),
        .init(name: "Marduk", note: "远方的旧识", category: .distant, strength: 0.24, position: CGPoint(x: 0.48, y: 0.10), avatarColors: [.purple.opacity(0.25), .white], symbol: "circle.dashed", memory: "名字还在图谱里，关系已经很轻。")
    ]
}

extension Array where Element == RelationshipPerson {
    func scenarioParticipants(limit: Int? = nil) -> [ScenarioParticipant] {
        let sortedPeople = sorted { left, right in
            if left.strength != right.strength {
                return left.strength > right.strength
            }

            return left.name < right.name
        }

        if let limit {
            return sortedPeople.prefix(limit).map(ScenarioParticipant.from)
        }

        return sortedPeople.map(ScenarioParticipant.from)
    }

    mutating func updateRelationship(for id: RelationshipPerson.ID, to category: RelationshipCategory) {
        guard let index = firstIndex(where: { $0.id == id }) else { return }
        self[index].category = category
    }

    mutating func deleteRelationship(_ category: RelationshipCategory) {
        removeAll { $0.category == category }
    }

    mutating func deletePerson(_ id: RelationshipPerson.ID) {
        removeAll { $0.id == id }
    }

    mutating func updatePosition(for id: RelationshipPerson.ID, to position: CGPoint) {
        guard let index = firstIndex(where: { $0.id == id }) else { return }
        self[index].position = CGPoint(
            x: Swift.min(Swift.max(position.x, 0.10), 0.90),
            y: Swift.min(Swift.max(position.y, 0.08), 0.92)
        )
    }

    mutating func organizePositions() {
        let orderedIndices = indices.sorted { left, right in
            let leftRank = categoryRank(self[left].category)
            let rightRank = categoryRank(self[right].category)

            if leftRank != rightRank {
                return leftRank < rightRank
            }

            if self[left].strength != self[right].strength {
                return self[left].strength > self[right].strength
            }

            return self[left].name < self[right].name
        }

        guard !orderedIndices.isEmpty else { return }

        for (order, index) in orderedIndices.enumerated() {
            let angle = (-Double.pi / 2) + (Double(order) / Double(orderedIndices.count)) * Double.pi * 2
            let ringOffset = order.isMultiple(of: 2) ? 0.00 : 0.05
            let radiusX = 0.33 + ringOffset
            let radiusY = 0.37 + ringOffset
            self[index].position = CGPoint(
                x: Swift.min(Swift.max(0.50 + cos(angle) * radiusX, 0.12), 0.88),
                y: Swift.min(Swift.max(0.51 + sin(angle) * radiusY, 0.12), 0.90)
            )
        }
    }

    mutating func addPerson(name: String, note: String, category: RelationshipCategory) {
        let nextIndex = count
        let angle = (Double(nextIndex) * 0.73).truncatingRemainder(dividingBy: Double.pi * 2)
        let radiusX = 0.34
        let radiusY = 0.39
        let position = CGPoint(
            x: Swift.min(Swift.max(0.50 + cos(angle) * radiusX, 0.12), 0.88),
            y: Swift.min(Swift.max(0.50 + sin(angle) * radiusY, 0.10), 0.92)
        )

        append(
            RelationshipPerson(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? localizedText("新的关系", "New relationship") : note.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                strength: 0.46,
                position: position,
                avatarColors: [category.color.opacity(0.86), Color.white.opacity(0.52)],
                symbol: "person.fill",
                memory: localizedText("这是你刚刚添加到关系图谱中的人。", "This is someone you just added to the relationship map.")
            )
        )
    }

    private func categoryRank(_ category: RelationshipCategory) -> Int {
        if let index = RelationshipCategory.builtIns.firstIndex(of: category) {
            return index
        }

        return RelationshipCategory.builtIns.count
    }
}
