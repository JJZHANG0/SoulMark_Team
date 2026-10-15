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

    enum CodingKeys: String, CodingKey {
        case intro, steps
        case completionRule = "completion_rule"
    }

    init(from decoder: Decoder) throws {
        summary = try ChallengeSummaryDTO(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intro = try container.decode(String.self, forKey: .intro)
        completionRule = try container.decode(String.self, forKey: .completionRule)
        steps = try container.decode([ChallengeStepDTO].self, forKey: .steps)
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

struct ChallengeActionDTO: Decodable {
    let challenge: ChallengeDetailDTO
    let awardedExperience: Int
    let growth: GrowthSnapshot?

    enum CodingKeys: String, CodingKey {
        case challenge, growth
        case awardedExperience = "awarded_experience"
    }
}

struct ChallengeStepSubmissionPayload: Encodable {
    let response: String
    let rating: Int?
}

struct SelfAwarenessReportDTO: Decodable, Equatable {
    struct Dimension: Decodable, Equatable, Identifiable {
        let key: String
        let title: String
        let score: Int
        let completedChallenges: Int
        let insight: String
        var id: String { key }
        enum CodingKeys: String, CodingKey {
            case key, title, score, insight
            case completedChallenges = "completed_challenges"
        }
    }

    struct Highlight: Decodable, Equatable, Identifiable {
        let challengeTitle: String
        let stepTitle: String
        let response: String
        var id: String { challengeTitle + stepTitle + response }
        enum CodingKeys: String, CodingKey {
            case response
            case challengeTitle = "challenge_title"
            case stepTitle = "step_title"
        }
    }

    struct Mix: Decodable, Equatable, Identifiable {
        let label: String
        let count: Int
        var id: String { label }
    }

    let displayName: String
    let headline: String
    let summary: String
    let overallScore: Int
    let level: Int
    let titleKey: String
    let challengesCompleted: Int
    let challengesActive: Int
    let reflectionsCount: Int
    let reviewsCount: Int
    let averageReviewScore: Double?
    let practicesCount: Int
    let contactsCount: Int
    let dimensions: [Dimension]
    let strengths: [String]
    let growthEdges: [String]
    let nextSteps: [String]
    let highlights: [Highlight]
    let relationshipMix: [Mix]

    enum CodingKeys: String, CodingKey {
        case headline, summary, level, dimensions, strengths, highlights
        case displayName = "display_name"
        case overallScore = "overall_score"
        case titleKey = "title_key"
        case challengesCompleted = "challenges_completed"
        case challengesActive = "challenges_active"
        case reflectionsCount = "reflections_count"
        case reviewsCount = "reviews_count"
        case averageReviewScore = "average_review_score"
        case practicesCount = "practices_count"
        case contactsCount = "contacts_count"
        case growthEdges = "growth_edges"
        case nextSteps = "next_steps"
        case relationshipMix = "relationship_mix"
    }
}
