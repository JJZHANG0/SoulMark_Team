//
//  SelfAwarenessModels.swift
//  SoulMark
//
//  DTOs for /api/v1/challenges and /api/v1/users/me/self-awareness-report.
//

import Foundation

struct ChallengeStepDTO: Decodable, Identifiable, Equatable {
    let index: Int
    let title: String
    let instruction: String
    let prompt: String
    let kind: String
    let minChars: Int
    let response: String?
    let rating: Int?

    var id: Int { index }
    var isRating: Bool { kind == "rating" }
    var isAnswered: Bool { response != nil || rating != nil }

    enum CodingKeys: String, CodingKey {
        case index, title, instruction, prompt, kind, response, rating
        case minChars = "min_chars"
    }
}

struct ChallengeSummaryDTO: Decodable, Identifiable, Equatable {
    let key: String
    let title: String
    let subtitle: String
    let model: String
    let modelTitle: String
    let dimension: String
    let dimensionTitle: String
    let icon: String
    let durationMinutes: Int
    let spanDays: Int
    let stepCount: Int
    let rewardExperience: Int
    let status: String
    let completedSteps: Int
    let completionCount: Int

    var id: String { key }
    var isActive: Bool { status == "active" }
    var isCompleted: Bool { status == "completed" }
    var progress: Double { stepCount == 0 ? 0 : Double(completedSteps) / Double(stepCount) }
    var timeLabel: String {
        spanDays > 1 ? "约 \(durationMinutes) 分钟 · \(spanDays) 天内" : "约 \(durationMinutes) 分钟"
    }

    enum CodingKeys: String, CodingKey {
        case key, title, subtitle, model, dimension, icon, status
        case modelTitle = "model_title"
        case dimensionTitle = "dimension_title"
        case durationMinutes = "duration_minutes"
        case spanDays = "span_days"
        case stepCount = "step_count"
        case rewardExperience = "reward_experience"
        case completedSteps = "completed_steps"
        case completionCount = "completion_count"
    }
}

struct ChallengeDetailDTO: Decodable, Equatable {
    let summary: ChallengeSummaryDTO
    let intro: String
    let completionRule: String
    let steps: [ChallengeStepDTO]
    let contextNotes: [String]

    enum CodingKeys: String, CodingKey {
        case intro, steps
        case completionRule = "completion_rule"
        case contextNotes = "context_notes"
    }

    init(from decoder: Decoder) throws {
        summary = try ChallengeSummaryDTO(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intro = try container.decode(String.self, forKey: .intro)
        completionRule = try container.decode(String.self, forKey: .completionRule)
        steps = try container.decode([ChallengeStepDTO].self, forKey: .steps)
        contextNotes = try container.decodeIfPresent([String].self, forKey: .contextNotes) ?? []
    }

    var currentStepIndex: Int? {
        summary.isActive ? steps.first(where: { !$0.isAnswered })?.index : nil
    }
}

struct ChallengeListDTO: Decodable, Equatable {
    let challenges: [ChallengeSummaryDTO]
    let activeCount: Int
    let completedCount: Int

    enum CodingKeys: String, CodingKey {
        case challenges
        case activeCount = "active_count"
        case completedCount = "completed_count"
    }
}

struct ChallengeKeepDTO: Decodable, Equatable {
    let sentence: String
    let question: String
    let reflectionId: UUID
    let detail: String

    enum CodingKeys: String, CodingKey {
        case sentence, question, detail
        case reflectionId = "reflection_id"
    }
}

struct ChallengeKeepPayload: Encodable {
    let reflectionId: UUID
    let sentence: String

    enum CodingKeys: String, CodingKey {
        case sentence
        case reflectionId = "reflection_id"
    }
}

struct ChallengeActionDTO: Decodable {
    let challenge: ChallengeDetailDTO
    let awardedExperience: Int
    let growth: GrowthSnapshot?
    let keep: ChallengeKeepDTO?

    enum CodingKeys: String, CodingKey {
        case challenge, growth, keep
        case awardedExperience = "awarded_experience"
    }
}

struct ChallengeStepSubmissionPayload: Encodable {
    let response: String
    let rating: Int?
    var continueAnyway: Bool = false

    enum CodingKeys: String, CodingKey {
        case response, rating
        case continueAnyway = "continue_anyway"
    }
}

struct SelfEvidenceInput: Encodable {
    let sourceType: String
    let sourceId: UUID?
    let quote: String
    let detail: String
    let occurredOn: String?

    enum CodingKeys: String, CodingKey {
        case quote, detail
        case sourceType = "source_type"
        case sourceId = "source_id"
        case occurredOn = "occurred_on"
    }
}

struct ConfirmSelfCellPayload: Encodable {
    let slot: String
    let text: String
    let evidence: [SelfEvidenceInput]
    let continueAnyway: Bool

    enum CodingKeys: String, CodingKey {
        case slot, text, evidence
        case continueAnyway = "continue_anyway"
    }
}

struct MarkMyLinePayload: Encodable {
    let quote: String
}

struct MarkedReviewLineDTO: Decodable {
    let id: UUID
    let slot: String
    let quote: String
    let confirmed: Bool
}

struct SelfAwarenessReportDTO: Decodable, Equatable {
    struct Cell: Decodable, Equatable, Identifiable {
        let slot: String
        let title: String
        let text: String
        let covered: Bool
        let missing: [String]
        var id: String { slot }
    }

    struct DraftItem: Decodable, Equatable, Identifiable {
        let slot: String
        let sourceType: String
        let sourceId: UUID?
        let quote: String
        let detail: String
        let occurredOn: Date?
        let prompt: String
        let ready: Bool

        var id: String {
            "\(slot)|\(sourceType)|\(sourceId?.uuidString ?? "")|\(quote)|\(detail)"
        }

        enum CodingKeys: String, CodingKey {
            case slot, quote, detail, prompt, ready
            case sourceType = "source_type"
            case sourceId = "source_id"
            case occurredOn = "occurred_on"
        }
    }

    struct Bookkeeping: Decodable, Equatable {
        let contactsCount: Int
        let eventsCount: Int
        let reviewsCount: Int
        let practicesCount: Int

        enum CodingKeys: String, CodingKey {
            case contactsCount = "contacts_count"
            case eventsCount = "events_count"
            case reviewsCount = "reviews_count"
            case practicesCount = "practices_count"
        }
    }

    let weekStart: Date
    let pausedAt: Date?
    let evidenceCovered: Int
    let evidenceTotal: Int
    let weeklyStepDone: Bool
    let weeklyStepCompletedAt: Date?
    let cells: [Cell]
    let draft: [DraftItem]
    let bookkeeping: Bookkeeping

    enum CodingKeys: String, CodingKey {
        case cells, draft, bookkeeping
        case weekStart = "week_start"
        case pausedAt = "paused_at"
        case evidenceCovered = "evidence_covered"
        case evidenceTotal = "evidence_total"
        case weeklyStepDone = "weekly_step_done"
        case weeklyStepCompletedAt = "weekly_step_completed_at"
    }
}

func selfPageDayString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "Asia/Singapore")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

func selfPageSlotTitle(_ slot: String) -> String {
    switch slot {
    case "who":
        localizedText("我是谁", "Who I am")
    case "pursuit":
        localizedText("在追", "Pursuing")
    case "fear":
        localizedText("在怕", "Afraid of")
    case "pattern_1", "pattern_2", "pattern_3":
        localizedText("模式", "Pattern")
    case "blind_spot":
        localizedText("盲区", "Blind spot")
    case "weekly_step":
        localizedText("本周一步", "This week's step")
    default:
        slot
    }
}
