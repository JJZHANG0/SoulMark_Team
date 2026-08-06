import Foundation
import Security
import SwiftUI

struct AppUser: Codable, Equatable {
    let id: UUID
    let publicID: Int?
    let email: String?
    let phoneNumber: String?
    let hasWeChat: Bool
    var displayName: String
    var preferredLanguage: String
    var gender: String?
    var appearance: String
    var communicationGoal: String?
    var onboardingCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case id, email, gender, appearance
        case publicID = "public_id"
        case phoneNumber = "phone_number"
        case hasWeChat = "has_wechat"
        case displayName = "display_name"
        case preferredLanguage = "preferred_language"
        case communicationGoal = "communication_goal"
        case onboardingCompleted = "onboarding_completed"
    }
}

private struct AuthTokenResponse: Decodable {
    let accessToken: String
    let expiresInSeconds: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresInSeconds = "expires_in_seconds"
    }
}

private struct LoginPayload: Encodable {
    let email: String
    let password: String
}

private struct PhonePayload: Encodable {
    let phoneNumber: String

    enum CodingKeys: String, CodingKey {
        case phoneNumber = "phone_number"
    }
}

private struct PhoneLoginPayload: Encodable {
    let phoneNumber: String
    let code: String

    enum CodingKeys: String, CodingKey {
        case phoneNumber = "phone_number"
        case code
    }
}

private struct WeChatLoginPayload: Encodable {
    let code: String
}

private struct MessageResponse: Decodable {
    let message: String
}

private struct RegisterPayload: Encodable {
    let email: String
    let password: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case email, password
        case displayName = "display_name"
    }
}

private struct OnboardingPayload: Encodable {
    let displayName: String
    let preferredLanguage: String
    let gender: String
    let appearance: String
    let communicationGoal: String
    let onboardingCompleted = true

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case preferredLanguage = "preferred_language"
        case gender, appearance
        case communicationGoal = "communication_goal"
        case onboardingCompleted = "onboarding_completed"
    }
}

struct DashboardStatsDTO: Decodable {
    let contactsCount: Int
    let practicesCount: Int
    let reviewsCount: Int
    let relationshipCategoriesCount: Int
    let averageReviewScore: Double?

    enum CodingKeys: String, CodingKey {
        case contactsCount = "contacts_count"
        case practicesCount = "practices_count"
        case reviewsCount = "reviews_count"
        case relationshipCategoriesCount = "relationship_categories_count"
        case averageReviewScore = "average_review_score"
    }
}

struct RemoteContact: Codable {
    let id: UUID
    let name: String
    let relationshipLabel: String
    let notes: String?
    let strength: Int
    let eventCount: Int
    let intimacyCalculated: Bool
    let positionX: Double
    let positionY: Double
    let symbol: String
    let memory: String?
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, notes, strength, symbol, memory
        case eventCount = "event_count"
        case intimacyCalculated = "intimacy_calculated"
        case relationshipLabel = "relationship_label"
        case positionX = "position_x"
        case positionY = "position_y"
        case avatarURL = "avatar_url"
    }

    var relationshipPerson: RelationshipPerson {
        let category = RelationshipCategory.fromAPIValue(relationshipLabel)
        let storedDetails = ContactMemoryStorage.decode(memory)
        return RelationshipPerson(
            id: id,
            name: name,
            note: notes ?? localizedText("新的关系", "New relationship"),
            category: category,
            strength: Double(strength) / 100,
            position: CGPoint(x: positionX, y: positionY),
            avatarColors: [category.color.opacity(0.86), Color.white.opacity(0.52)],
            symbol: symbol,
            memory: storedDetails.memory,
            avatarURL: avatarURL,
            informationFields: storedDetails.fields,
            eventCount: eventCount,
            intimacyCalculated: intimacyCalculated
        )
    }
}

private enum ContactMemoryStorage {
    private static let marker = "\n__SOULMARK_CONTACT_INFO__:"

    static func encode(memory: String, fields: [ContactInformationField]) -> String {
        guard !fields.isEmpty,
              let data = try? JSONEncoder().encode(fields) else { return memory }
        return memory + marker + data.base64EncodedString()
    }

    static func decode(_ storedMemory: String?) -> (memory: String, fields: [ContactInformationField]) {
        let fallback = localizedText("这段连接已经同步到你的关系图谱。", "This connection is synced to your map.")
        guard let storedMemory,
              let range = storedMemory.range(of: marker, options: .backwards) else {
            return (storedMemory ?? fallback, [])
        }
        let encoded = String(storedMemory[range.upperBound...])
        let fields = Data(base64Encoded: encoded)
            .flatMap { try? JSONDecoder().decode([ContactInformationField].self, from: $0) } ?? []
        return (String(storedMemory[..<range.lowerBound]), fields)
    }
}

private struct ContactPayload: Encodable {
    let name: String
    let relationshipLabel: String
    let notes: String
    let strength: Int
    let positionX: Double
    let positionY: Double
    let symbol: String
    let memory: String

    enum CodingKeys: String, CodingKey {
        case name, notes, strength, symbol, memory
        case relationshipLabel = "relationship_label"
        case positionX = "position_x"
        case positionY = "position_y"
    }

    init(person: RelationshipPerson) {
        name = person.name
        relationshipLabel = person.category.apiValue
        notes = person.note
        strength = Int((person.strength * 100).rounded())
        positionX = person.position.x
        positionY = person.position.y
        symbol = person.symbol
        memory = ContactMemoryStorage.encode(memory: person.memory, fields: person.informationFields)
    }
}

private struct ContactEventPayload: Encodable {
    let title: String
    let details: String
    let occurredAt: String
    let relationshipSignal: RelationshipSignalPayload?
    let skipRelationshipUpdate: Bool

    enum CodingKeys: String, CodingKey {
        case title, details
        case occurredAt = "occurred_at"
        case relationshipSignal = "relationship_signal"
        case skipRelationshipUpdate = "skip_relationship_update"
    }

    init(
        title: String,
        details: String,
        occurredAt: Date,
        relationshipSignal: RelationshipSignalPayload?,
        skipRelationshipUpdate: Bool
    ) {
        self.title = title
        self.details = details
        self.occurredAt = ISO8601DateFormatter().string(from: occurredAt)
        self.relationshipSignal = relationshipSignal
        self.skipRelationshipUpdate = skipRelationshipUpdate
    }
}

private struct RemoteContactEvent: Decodable {
    let id: UUID
    let contactID: UUID
    let title: String
    let details: String
    let occurredAt: Date
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case id, title, details
        case contactID = "contact_id"
        case occurredAt = "occurred_at"
        case imageURL = "image_url"
    }

    var timelineEvent: ContactTimelineEvent {
        ContactTimelineEvent(
            id: id,
            contactID: contactID,
            title: title,
            details: details,
            occurredAt: occurredAt,
            imageURL: imageURL
        )
    }
}

private struct PracticePayload: Encodable {
    let participantName: String
    let modeTitle: String
    let modeGuidance: String
    let durationSeconds: Int
    let userTranscript: String
    let assistantTranscript: String

    enum CodingKeys: String, CodingKey {
        case participantName = "participant_name"
        case modeTitle = "mode_title"
        case modeGuidance = "mode_guidance"
        case durationSeconds = "duration_seconds"
        case userTranscript = "user_transcript"
        case assistantTranscript = "assistant_transcript"
    }
}

struct PracticeRecord: Decodable, Identifiable {
    let id: UUID
    let participantName: String
    let modeTitle: String
    let durationSeconds: Int
    let userTranscript: String
    let assistantTranscript: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case participantName = "participant_name"
        case modeTitle = "mode_title"
        case durationSeconds = "duration_seconds"
        case userTranscript = "user_transcript"
        case assistantTranscript = "assistant_transcript"
        case createdAt = "created_at"
    }

    var scenarioConversationSession: ScenarioConversationSession {
        let userMessages = transcriptLines(userTranscript).map {
            ScenarioMessage(speaker: localizedText("你", "You"), text: $0, isUser: true)
        }
        let assistantMessages = transcriptLines(assistantTranscript).map {
            ScenarioMessage(speaker: participantName, text: $0, isUser: false)
        }
        return ScenarioConversationSession(
            id: id,
            participantID: nil,
            participantName: participantName,
            date: createdAt,
            messages: userMessages + assistantMessages
        )
    }

    private func transcriptLines(_ transcript: String) -> [String] {
        transcript
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private struct ReviewPayload: Encodable {
    let title: String
    let source: String
    let transcript: String
    let score: Int
    let reason: String
    let advice: String
    let detailedAdvice: String
    let relationshipImpacts: [ReviewRelationshipImpactPayload]

    enum CodingKeys: String, CodingKey {
        case title, source, transcript, score, reason, advice
        case detailedAdvice = "detailed_advice"
        case relationshipImpacts = "relationship_impacts"
    }
}

private struct ReviewRelationshipImpactPayload: Encodable {
    let contactID: UUID
    let relationshipSignal: RelationshipSignalPayload

    enum CodingKeys: String, CodingKey {
        case contactID = "contact_id"
        case relationshipSignal = "relationship_signal"
    }
}

private struct ReviewAnalysisPayload: Encodable {
    let source: String
    let transcript: String
    let language: String
}

private struct ReviewRelatedContactDTO: Decodable {
    let id: UUID
    let name: String
    let relationshipSignal: RelationshipSignalPayload?

    enum CodingKeys: String, CodingKey {
        case id, name
        case relationshipSignal = "relationship_signal"
    }
}

private struct ReviewAnalysisDTO: Decodable {
    let title: String
    let score: Int
    let reason: String
    let briefAdvice: String
    let detailedAdvice: String
    let transcript: String?
    let relatedContactName: String?
    let relatedContactID: UUID?
    let relatedContacts: [ReviewRelatedContactDTO]?
    let eventDetails: String?

    enum CodingKeys: String, CodingKey {
        case title, score, reason, transcript
        case briefAdvice = "brief_advice"
        case detailedAdvice = "detailed_advice"
        case relatedContactName = "related_contact_name"
        case relatedContactID = "related_contact_id"
        case relatedContacts = "related_contacts"
        case eventDetails = "event_details"
    }
}

struct RemoteReview: Decodable {
    let id: UUID
    let title: String
    let source: String
    let transcript: String
    let score: Int
    let reason: String
    let advice: String
    let detailedAdvice: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, source, transcript, score, reason, advice
        case detailedAdvice = "detailed_advice"
        case createdAt = "created_at"
    }

    var record: ConversationReviewRecord? {
        guard let reviewSource = ReviewSource(rawValue: source) else { return nil }
        return ConversationReviewRecord(
            id: id,
            title: title,
            source: reviewSource,
            date: createdAt,
            transcript: transcript,
            score: score,
            reason: reason,
            advice: advice,
            detailedAdvice: detailedAdvice
        )
    }
}

enum SoulAPIError: LocalizedError {
    case invalidResponse
    case incompatibleBackend(Int)
    case server(String)
    case offline

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            localizedText("服务返回的数据无法识别。", "The service returned an invalid response.")
        case .incompatibleBackend(let statusCode):
            localizedText(
                "当前连接的后端与 SoulMark 不兼容（HTTP \(statusCode)）。请启动本项目的 SoulMark_backend，并执行数据库迁移。",
                "The connected backend is incompatible with SoulMark (HTTP \(statusCode)). Start this project's SoulMark_backend and apply its database migrations."
            )
        case .server(let message):
            message
        case .offline:
            localizedText("暂时无法连接 SoulMark 服务。", "SoulMark is temporarily unreachable.")
        }
    }
}

private struct APIErrorEnvelope: Decodable {
    struct Detail: Decodable {
        let message: String
    }

    let error: Detail
}

private final class SoulAPIClient {
    private let session = URLSession.shared

    func register(email: String, password: String, displayName: String) async throws {
        let payload = RegisterPayload(email: email, password: password, displayName: displayName)
        let _: AppUser = try await request(path: "/api/v1/auth/register", method: "POST", body: payload)
    }

    func login(email: String, password: String) async throws -> AuthTokenResponse {
        try await request(
            path: "/api/v1/auth/login",
            method: "POST",
            body: LoginPayload(email: email, password: password)
        )
    }

    func sendPhoneCode(phoneNumber: String) async throws {
        let _: MessageResponse = try await request(
            path: "/api/v1/auth/phone/code",
            method: "POST",
            body: PhonePayload(phoneNumber: phoneNumber)
        )
    }

    func login(phoneNumber: String, code: String) async throws -> AuthTokenResponse {
        try await request(
            path: "/api/v1/auth/phone/login",
            method: "POST",
            body: PhoneLoginPayload(phoneNumber: phoneNumber, code: code)
        )
    }

    func login(weChatCode: String) async throws -> AuthTokenResponse {
        try await request(
            path: "/api/v1/auth/wechat/login",
            method: "POST",
            body: WeChatLoginPayload(code: weChatCode)
        )
    }

    func currentUser(token: String) async throws -> AppUser {
        try await request(path: "/api/v1/users/me", token: token)
    }

    func exportUserData(token: String) async throws -> Data {
        try await requestData(path: "/api/v1/users/me/export", token: token)
    }

    func deleteAccount(token: String) async throws {
        try await requestVoid(path: "/api/v1/users/me", method: "DELETE", token: token)
    }

    func completeOnboarding(
        token: String,
        displayName: String,
        language: String,
        gender: String,
        appearance: String,
        goal: String
    ) async throws -> AppUser {
        try await request(
            path: "/api/v1/users/me",
            method: "PATCH",
            token: token,
            body: OnboardingPayload(
                displayName: displayName,
                preferredLanguage: language,
                gender: gender,
                appearance: appearance,
                communicationGoal: goal
            )
        )
    }

    func contacts(token: String) async throws -> [RemoteContact] {
        try await request(path: "/api/v1/contacts", token: token)
    }

    func createContact(token: String, person: RelationshipPerson) async throws -> RemoteContact {
        try await request(
            path: "/api/v1/contacts",
            method: "POST",
            token: token,
            body: ContactPayload(person: person)
        )
    }

    func updateContact(token: String, person: RelationshipPerson) async throws -> RemoteContact {
        try await request(
            path: "/api/v1/contacts/\(person.id.uuidString)",
            method: "PATCH",
            token: token,
            body: ContactPayload(person: person)
        )
    }

    func deleteContact(token: String, id: UUID) async throws {
        try await requestVoid(path: "/api/v1/contacts/\(id.uuidString)", method: "DELETE", token: token)
    }

    func uploadContactAvatar(token: String, id: UUID, imageData: Data) async throws -> RemoteContact {
        guard let url = BackendURLResolver.apiURL("/api/v1/contacts/\(id.uuidString)/avatar") else {
            throw SoulAPIError.invalidResponse
        }
        let boundary = "SoulMark-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        return try await perform(request)
    }

    func deleteContactAvatar(token: String, id: UUID) async throws -> RemoteContact {
        try await request(
            path: "/api/v1/contacts/\(id.uuidString)/avatar",
            method: "DELETE",
            token: token
        )
    }

    func contactEvents(token: String, contactID: UUID) async throws -> [RemoteContactEvent] {
        try await request(
            path: "/api/v1/contacts/\(contactID.uuidString)/events",
            token: token
        )
    }

    func createContactEvent(
        token: String,
        contactID: UUID,
        title: String,
        details: String,
        occurredAt: Date,
        relationshipSignal: RelationshipSignalPayload?,
        skipRelationshipUpdate: Bool
    ) async throws -> RemoteContactEvent {
        try await request(
            path: "/api/v1/contacts/\(contactID.uuidString)/events",
            method: "POST",
            token: token,
            body: ContactEventPayload(
                title: title,
                details: details,
                occurredAt: occurredAt,
                relationshipSignal: relationshipSignal,
                skipRelationshipUpdate: skipRelationshipUpdate
            )
        )
    }

    func uploadContactEventImage(
        token: String,
        contactID: UUID,
        eventID: UUID,
        imageData: Data
    ) async throws -> RemoteContactEvent {
        guard let url = BackendURLResolver.apiURL(
            "/api/v1/contacts/\(contactID.uuidString)/events/\(eventID.uuidString)/image"
        ) else {
            throw SoulAPIError.invalidResponse
        }
        let boundary = "SoulMark-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"event.jpg\"\r\n"
                .data(using: .utf8)!
        )
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 60
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        return try await perform(request)
    }

    func deleteContactEvent(
        token: String,
        contactID: UUID,
        eventID: UUID
    ) async throws {
        try await requestVoid(
            path: "/api/v1/contacts/\(contactID.uuidString)/events/\(eventID.uuidString)",
            method: "DELETE",
            token: token
        )
    }

    func stats(token: String) async throws -> DashboardStatsDTO {
        try await request(path: "/api/v1/stats", token: token)
    }

    func savePractice(
        token: String,
        participant: String,
        mode: String,
        guidance: String,
        duration: Int,
        userTranscript: String,
        assistantTranscript: String
    ) async throws {
        let _: PracticeRecord = try await request(
            path: "/api/v1/practices",
            method: "POST",
            token: token,
            body: PracticePayload(
                participantName: participant,
                modeTitle: mode,
                modeGuidance: guidance,
                durationSeconds: duration,
                userTranscript: userTranscript,
                assistantTranscript: assistantTranscript
            )
        )
    }

    func saveReview(
        token: String,
        record: ConversationReviewRecord,
        relationshipImpacts: [ReviewRelationshipImpactPayload]
    ) async throws -> RemoteReview {
        try await request(
            path: "/api/v1/reviews",
            method: "POST",
            token: token,
            body: ReviewPayload(
                title: record.title,
                source: record.source.rawValue,
                transcript: record.transcript,
                score: record.score,
                reason: record.reason,
                advice: record.advice,
                detailedAdvice: record.detailedAdvice,
                relationshipImpacts: relationshipImpacts
            )
        )
    }

    func analyzeReview(
        token: String,
        source: ReviewSource,
        transcript: String,
        language: String
    ) async throws -> ReviewAnalysisDTO {
        try await request(
            path: "/api/v1/reviews/analyze",
            method: "POST",
            token: token,
            body: ReviewAnalysisPayload(
                source: source.rawValue,
                transcript: transcript,
                language: language
            ),
            timeoutInterval: 90
        )
    }

    func analyzeReviewMedia(
        token: String,
        source: ReviewSource,
        data: Data,
        filename: String,
        mimeType: String,
        language: String
    ) async throws -> ReviewAnalysisDTO {
        guard let url = BackendURLResolver.apiURL("/api/v1/reviews/analyze-media") else {
            throw SoulAPIError.invalidResponse
        }
        let boundary = "SoulMark-\(UUID().uuidString)"
        var body = Data()

        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField("source", source.rawValue)
        appendField("language", language)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n"
                .data(using: .utf8)!
        )
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 180
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        return try await perform(request)
    }

    func reviews(token: String) async throws -> [RemoteReview] {
        try await request(path: "/api/v1/reviews", token: token)
    }

    func practices(token: String) async throws -> [PracticeRecord] {
        try await request(path: "/api/v1/practices", token: token)
    }

    func deletePractice(token: String, id: UUID) async throws {
        try await requestVoid(
            path: "/api/v1/practices/\(id.uuidString)",
            method: "DELETE",
            token: token
        )
    }

    func deleteReview(token: String, id: UUID) async throws {
        try await requestVoid(
            path: "/api/v1/reviews/\(id.uuidString)",
            method: "DELETE",
            token: token
        )
    }

    private func request<Response: Decodable>(
        path: String,
        method: String = "GET",
        token: String? = nil
    ) async throws -> Response {
        try await request(path: path, method: method, token: token, bodyData: nil)
    }

    private func requestVoid(path: String, method: String, token: String) async throws {
        let base = UserDefaults.standard.string(forKey: "soulMarkBackendURL")
            ?? RealtimeVoiceServiceConfiguration.defaultBackendURL
        guard let baseURL = URL(string: base), let url = URL(string: path, relativeTo: baseURL) else {
            throw SoulAPIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 120
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SoulAPIError.offline
        }
        guard let http = response as? HTTPURLResponse else {
            throw SoulAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            throw SoulAPIError.server(
                envelope?.error.message
                    ?? localizedText("请求没有完成，请稍后再试。", "The request could not be completed.")
            )
        }
    }

    private func requestData(path: String, token: String) async throws -> Data {
        let base = UserDefaults.standard.string(forKey: "soulMarkBackendURL")
            ?? RealtimeVoiceServiceConfiguration.defaultBackendURL
        guard let baseURL = URL(string: base), let url = URL(string: path, relativeTo: baseURL) else {
            throw SoulAPIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 120
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SoulAPIError.offline
        }
        guard let http = response as? HTTPURLResponse else {
            throw SoulAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            throw SoulAPIError.server(
                envelope?.error.message
                    ?? localizedText("请求没有完成，请稍后再试。", "The request could not be completed.")
            )
        }
        return data
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        token: String? = nil,
        body: Body,
        timeoutInterval: TimeInterval = 15
    ) async throws -> Response {
        let bodyData = try JSONEncoder().encode(body)
        return try await request(
            path: path,
            method: method,
            token: token,
            bodyData: bodyData,
            timeoutInterval: timeoutInterval
        )
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        token: String?,
        bodyData: Data?,
        timeoutInterval: TimeInterval = 15
    ) async throws -> Response {
        let base = UserDefaults.standard.string(forKey: "soulMarkBackendURL")
            ?? RealtimeVoiceServiceConfiguration.defaultBackendURL
        guard let baseURL = URL(string: base), let url = URL(string: path, relativeTo: baseURL) else {
            throw SoulAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = bodyData
        request.timeoutInterval = timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return try await perform(request)
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SoulAPIError.offline
        }
        guard let http = response as? HTTPURLResponse else {
            throw SoulAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            throw SoulAPIError.server(
                envelope?.error.message
                    ?? localizedText("请求没有完成，请稍后再试。", "The request could not be completed.")
            )
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let value = try container.decode(String.self)
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: value) {
                    return date
                }
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: value) {
                    return date
                }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid ISO-8601 date"
                )
            }
            return try decoder.decode(Response.self, from: data)
        } catch {
#if DEBUG
            print("SoulMark response decoding failed for \(request.url?.path ?? "unknown path"): \(error)")
#endif
            throw SoulAPIError.incompatibleBackend(http.statusCode)
        }
    }
}

final class AuthTokenStore {
    static let shared = AuthTokenStore()
    private let service = "com.jjzhang828.soulmark.auth"
    private let account = "access-token"
    private let simulatorTokenKey = "soulMarkSimulatorAccessToken"

    func read() -> String? {
#if targetEnvironment(simulator)
        return UserDefaults.standard.string(forKey: simulatorTokenKey)
#else
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
#endif
    }

    func save(_ token: String) {
#if targetEnvironment(simulator)
        UserDefaults.standard.set(token, forKey: simulatorTokenKey)
#else
        clear()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(token.utf8)
        ]
        SecItemAdd(query as CFDictionary, nil)
#endif
    }

    func clear() {
#if targetEnvironment(simulator)
        UserDefaults.standard.removeObject(forKey: simulatorTokenKey)
#else
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
#endif
    }
}

@MainActor
final class AppSession: ObservableObject {
    enum Route {
        case launch
        case authentication
        case onboarding
        case main
    }

    @Published private(set) var route: Route = .launch
    @Published private(set) var user: AppUser?
    @Published private(set) var isWorking = false
    @Published private(set) var contactsRevision = UUID()
    @Published var errorMessage: String?

    private let api = SoulAPIClient()
    private let tokenStore = AuthTokenStore.shared
    private let expiryKey = "soulMarkSessionExpiresAt"
    private let cachedUserKey = "soulMarkCachedUser"

    func bootstrap() async {
        let startedAt = Date()
        defer {
            let elapsed = Date().timeIntervalSince(startedAt)
            if elapsed < 1.1 {
                Thread.sleep(forTimeInterval: 1.1 - elapsed)
            }
        }

        guard let token = tokenStore.read(), sessionIsCurrent else {
            signOut()
            return
        }

        do {
            let current = try await api.currentUser(token: token)
            applyUser(current)
        } catch SoulAPIError.offline {
            if let cached = cachedUser {
                applyUser(cached)
            } else {
                signOut()
            }
        } catch {
            signOut()
        }
    }

    func login(email: String, password: String) async {
        await performAuth {
            try await self.authenticate(email: email, password: password)
        }
    }

    func register(displayName: String, email: String, password: String) async {
        await performAuth {
            try await self.api.register(email: email, password: password, displayName: displayName)
            try await self.authenticate(email: email, password: password)
        }
    }

    @discardableResult
    func sendPhoneCode(_ phoneNumber: String) async -> Bool {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await api.sendPhoneCode(phoneNumber: phoneNumber)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func login(phoneNumber: String, code: String) async {
        await performAuth {
            let response = try await self.api.login(phoneNumber: phoneNumber, code: code)
            try await self.accept(response)
        }
    }

    func login(weChatAuthorizationCode: String) async {
        await performAuth {
            let response = try await self.api.login(weChatCode: weChatAuthorizationCode)
            try await self.accept(response)
        }
    }

    func reportWeChatSDKNotConfigured() {
        errorMessage = localizedText(
            "微信登录后端已接入；请先配置微信开放平台 SDK，再发起客户端授权。",
            "The WeChat backend is ready. Configure the WeChat Open Platform SDK before requesting authorization."
        )
    }

    func finishOnboarding(
        displayName: String,
        language: String,
        gender: String,
        appearance: String,
        goal: String
    ) async {
        guard let token = tokenStore.read() else {
            signOut()
            return
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let updated = try await api.completeOnboarding(
                token: token,
                displayName: displayName,
                language: language,
                gender: gender,
                appearance: appearance,
                goal: goal
            )
            SoulPreferencesStore.shared.apply(
                language: language,
                genderTheme: gender,
                appearanceMode: appearance == "light" ? "day" : appearance == "dark" ? "night" : "auto"
            )
            applyUser(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        tokenStore.clear()
        UserDefaults.standard.removeObject(forKey: expiryKey)
        UserDefaults.standard.removeObject(forKey: cachedUserKey)
        user = nil
        route = .authentication
    }

    func createDataExportFile() async throws -> URL {
        guard let token = tokenStore.read() else { throw SoulAPIError.offline }
        let data = try await api.exportUserData(token: token)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SoulMark-Data-\(Date().formatted(.iso8601)).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    func deleteAccount() async throws {
        guard let token = tokenStore.read() else { throw SoulAPIError.offline }
        try await api.deleteAccount(token: token)
        signOut()
    }

    func loadContacts() async -> [RelationshipPerson]? {
        guard let token = tokenStore.read() else { return nil }
        return try? await api.contacts(token: token).map(\.relationshipPerson)
    }

    func createContact(_ person: RelationshipPerson) async -> RelationshipPerson? {
        guard let token = tokenStore.read() else { return nil }
        return try? await api.createContact(token: token, person: person).relationshipPerson
    }

    func updateContact(_ person: RelationshipPerson) async {
        guard let token = tokenStore.read() else { return }
        _ = try? await api.updateContact(token: token, person: person)
    }

    func updateContacts(_ people: [RelationshipPerson]) async {
        for person in people {
            await updateContact(person)
        }
    }

    func deleteContact(_ id: UUID) async {
        guard let token = tokenStore.read() else { return }
        try? await api.deleteContact(token: token, id: id)
    }

    func uploadContactAvatar(contactID: UUID, imageData: Data) async -> RelationshipPerson? {
        guard let token = tokenStore.read() else { return nil }
        return try? await api.uploadContactAvatar(
            token: token,
            id: contactID,
            imageData: imageData
        ).relationshipPerson
    }

    func deleteContactAvatar(contactID: UUID) async -> RelationshipPerson? {
        guard let token = tokenStore.read() else { return nil }
        return try? await api.deleteContactAvatar(token: token, id: contactID).relationshipPerson
    }

    func loadContactEvents(contactID: UUID) async throws -> [ContactTimelineEvent] {
        guard let token = tokenStore.read() else { throw SoulAPIError.offline }
        return try await api.contactEvents(token: token, contactID: contactID)
            .map(\.timelineEvent)
    }

    func createContactEvent(
        contactID: UUID,
        title: String,
        details: String,
        occurredAt: Date,
        imageData: Data?,
        relationshipSignal: RelationshipSignalPayload? = nil,
        skipRelationshipUpdate: Bool = false
    ) async throws -> ContactTimelineEvent {
        guard let token = tokenStore.read() else { throw SoulAPIError.offline }
        var remote = try await api.createContactEvent(
            token: token,
            contactID: contactID,
            title: title,
            details: details,
            occurredAt: occurredAt,
            relationshipSignal: relationshipSignal,
            skipRelationshipUpdate: skipRelationshipUpdate
        )
        if let imageData {
            do {
                remote = try await api.uploadContactEventImage(
                    token: token,
                    contactID: contactID,
                    eventID: remote.id,
                    imageData: imageData
                )
            } catch {
                try? await api.deleteContactEvent(
                    token: token,
                    contactID: contactID,
                    eventID: remote.id
                )
                throw error
            }
        }
        contactsRevision = UUID()
        return remote.timelineEvent
    }

    func createContactEvents(
        contactIDs: [UUID],
        title: String,
        details: String,
        occurredAt: Date,
        imageData: Data?,
        relationshipSignals: [UUID: RelationshipSignalPayload] = [:],
        skipRelationshipUpdate: Bool = false
    ) async throws -> [ContactTimelineEvent] {
        let uniqueContactIDs = Array(NSOrderedSet(array: contactIDs))
            .compactMap { $0 as? UUID }
        var createdEvents: [ContactTimelineEvent] = []
        do {
            for contactID in uniqueContactIDs {
                let event = try await createContactEvent(
                    contactID: contactID,
                    title: title,
                    details: details,
                    occurredAt: occurredAt,
                    imageData: imageData,
                    relationshipSignal: relationshipSignals[contactID],
                    skipRelationshipUpdate: skipRelationshipUpdate
                )
                createdEvents.append(event)
            }
            return createdEvents
        } catch {
            for event in createdEvents {
                try? await deleteContactEvent(
                    contactID: event.contactID,
                    eventID: event.id
                )
            }
            throw error
        }
    }

    func deleteContactEvent(contactID: UUID, eventID: UUID) async throws {
        guard let token = tokenStore.read() else { throw SoulAPIError.offline }
        try await api.deleteContactEvent(
            token: token,
            contactID: contactID,
            eventID: eventID
        )
        contactsRevision = UUID()
    }

    func loadStats() async -> DashboardStatsDTO? {
        guard let token = tokenStore.read() else { return nil }
        return try? await api.stats(token: token)
    }

    func recordPractice(
        duration: Int,
        participant: String,
        mode: String,
        guidance: String,
        messages: [ScenarioMessage]
    ) async {
        guard let token = tokenStore.read() else { return }
        let userText = messages.filter(\.isUser).map(\.text).joined(separator: "\n")
        let assistantText = messages.filter { !$0.isUser }.map(\.text).joined(separator: "\n")
        try? await api.savePractice(
            token: token,
            participant: participant,
            mode: mode,
            guidance: guidance,
            duration: duration,
            userTranscript: userText,
            assistantTranscript: assistantText
        )
    }

    func recordReview(_ analysis: AnalyzedConversationReview) async throws -> ConversationReviewRecord {
        guard let token = tokenStore.read() else { throw SoulAPIError.offline }
        let relationshipImpacts = (analysis.timelineSuggestion?.contacts ?? []).compactMap { contact in
            contact.relationshipSignal.map {
                ReviewRelationshipImpactPayload(
                    contactID: contact.id,
                    relationshipSignal: $0
                )
            }
        }
        guard let saved = try await api.saveReview(
            token: token,
            record: analysis.record,
            relationshipImpacts: relationshipImpacts
        ).record else {
            throw SoulAPIError.invalidResponse
        }
        contactsRevision = UUID()
        return saved
    }

    func analyzeReview(
        title: String,
        source: ReviewSource,
        transcript: String,
        language: String,
        media: ReviewMediaAttachment? = nil
    ) async throws -> AnalyzedConversationReview {
        guard let token = tokenStore.read() else { throw SoulAPIError.offline }
        let analysis: ReviewAnalysisDTO
        if let media {
            analysis = try await api.analyzeReviewMedia(
                token: token,
                source: source,
                data: media.data,
                filename: media.filename,
                mimeType: media.mimeType,
                language: language
            )
        } else {
            analysis = try await api.analyzeReview(
                token: token,
                source: source,
                transcript: transcript,
                language: language
            )
        }
        let suppliedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let analyzedTranscript = analysis.transcript?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let suppliedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTranscript = analyzedTranscript?.isEmpty == false
            ? analyzedTranscript ?? suppliedTranscript
            : suppliedTranscript
        let record = ConversationReviewRecord(
            title: suppliedTitle.isEmpty
                ? localizedText("未命名复盘", "Untitled Review")
                : suppliedTitle,
            source: source,
            date: Date(),
            transcript: finalTranscript,
            score: analysis.score,
            reason: analysis.reason,
            advice: analysis.briefAdvice,
            detailedAdvice: analysis.detailedAdvice
        )
        var matchedContacts = (analysis.relatedContacts ?? []).map {
            ReviewSuggestedContact(
                id: $0.id,
                name: $0.name,
                relationshipSignal: $0.relationshipSignal
            )
        }
        if matchedContacts.isEmpty,
           let contactID = analysis.relatedContactID,
           let contactName = analysis.relatedContactName {
            matchedContacts = [
                ReviewSuggestedContact(
                    id: contactID,
                    name: contactName,
                    relationshipSignal: nil
                )
            ]
        }
        let suggestion: ReviewTimelineSuggestion?
        if !matchedContacts.isEmpty {
            let generatedDetails = analysis.eventDetails?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            suggestion = ReviewTimelineSuggestion(
                contacts: matchedContacts,
                title: analysis.title,
                details: generatedDetails?.isEmpty == false
                    ? generatedDetails ?? finalTranscript
                    : finalTranscript
            )
        } else {
            suggestion = nil
        }
        return AnalyzedConversationReview(
            record: record,
            timelineSuggestion: suggestion
        )
    }

    func deleteReview(_ id: UUID) async throws {
        guard let token = tokenStore.read() else { throw SoulAPIError.offline }
        try await api.deleteReview(token: token, id: id)
        contactsRevision = UUID()
    }

    func loadReviews() async -> [ConversationReviewRecord]? {
        guard let token = tokenStore.read() else { return nil }
        return try? await api.reviews(token: token).compactMap(\.record)
    }

    func loadPractices() async -> [PracticeRecord]? {
        guard let token = tokenStore.read() else { return nil }
        return try? await api.practices(token: token)
    }

    func deletePractice(_ id: UUID) async throws {
        guard let token = tokenStore.read() else { throw SoulAPIError.offline }
        try await api.deletePractice(token: token, id: id)
    }

    private var sessionIsCurrent: Bool {
        guard let expiry = UserDefaults.standard.object(forKey: expiryKey) as? Date else { return false }
        return expiry > Date()
    }

    private var cachedUser: AppUser? {
        guard let data = UserDefaults.standard.data(forKey: cachedUserKey) else { return nil }
        return try? JSONDecoder().decode(AppUser.self, from: data)
    }

    private func authenticate(email: String, password: String) async throws {
        let response = try await api.login(email: email, password: password)
        try await accept(response)
    }

    private func accept(_ response: AuthTokenResponse) async throws {
        tokenStore.save(response.accessToken)
        UserDefaults.standard.set(
            Date().addingTimeInterval(TimeInterval(response.expiresInSeconds)),
            forKey: expiryKey
        )
        let current = try await api.currentUser(token: response.accessToken)
        applyUser(current)
    }

    private func performAuth(_ action: () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyUser(_ user: AppUser) {
        self.user = user
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: cachedUserKey)
        }
        route = user.onboardingCompleted ? .main : .onboarding
    }
}
