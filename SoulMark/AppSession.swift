import Foundation
import Security
import SwiftUI

struct AppUser: Codable, Equatable {
    let id: UUID
    let email: String
    var displayName: String
    var preferredLanguage: String
    var gender: String?
    var appearance: String
    var communicationGoal: String?
    var onboardingCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case id, email, gender, appearance
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
    let positionX: Double
    let positionY: Double
    let symbol: String
    let memory: String?

    enum CodingKeys: String, CodingKey {
        case id, name, notes, strength, symbol, memory
        case relationshipLabel = "relationship_label"
        case positionX = "position_x"
        case positionY = "position_y"
    }

    var relationshipPerson: RelationshipPerson {
        let category = RelationshipCategory.fromAPIValue(relationshipLabel)
        return RelationshipPerson(
            id: id,
            name: name,
            note: notes ?? localizedText("新的关系", "New relationship"),
            category: category,
            strength: Double(strength) / 100,
            position: CGPoint(x: positionX, y: positionY),
            avatarColors: [category.color.opacity(0.86), Color.white.opacity(0.52)],
            symbol: symbol,
            memory: memory ?? localizedText("这段连接已经同步到你的关系图谱。", "This connection is synced to your map.")
        )
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
        memory = person.memory
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

private struct PracticeResponseDTO: Decodable {
    let id: UUID
}

private struct ReviewPayload: Encodable {
    let title: String
    let source: String
    let transcript: String
    let score: Int
    let reason: String
    let advice: String
}

struct RemoteReview: Decodable {
    let id: UUID
    let title: String
    let source: String
    let transcript: String
    let score: Int
    let reason: String
    let advice: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, source, transcript, score, reason, advice
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
            advice: advice
        )
    }
}

enum SoulAPIError: LocalizedError {
    case invalidResponse
    case server(String)
    case offline

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            localizedText("服务返回的数据无法识别。", "The service returned an invalid response.")
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

    func currentUser(token: String) async throws -> AppUser {
        try await request(path: "/api/v1/users/me", token: token)
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
        let _: PracticeResponseDTO = try await request(
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

    func saveReview(token: String, record: ConversationReviewRecord) async throws {
        let _: RemoteReview = try await request(
            path: "/api/v1/reviews",
            method: "POST",
            token: token,
            body: ReviewPayload(
                title: record.title,
                source: record.source.rawValue,
                transcript: record.transcript,
                score: record.score,
                reason: record.reason,
                advice: record.advice
            )
        )
    }

    func reviews(token: String) async throws -> [RemoteReview] {
        try await request(path: "/api/v1/reviews", token: token)
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
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SoulAPIError.invalidResponse
        }
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        token: String? = nil,
        body: Body
    ) async throws -> Response {
        let bodyData = try JSONEncoder().encode(body)
        return try await request(path: path, method: method, token: token, bodyData: bodyData)
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        token: String?,
        bodyData: Data?
    ) async throws -> Response {
        let base = UserDefaults.standard.string(forKey: "soulMarkBackendURL")
            ?? RealtimeVoiceServiceConfiguration.defaultBackendURL
        guard let baseURL = URL(string: base), let url = URL(string: path, relativeTo: baseURL) else {
            throw SoulAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = bodyData
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

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
            throw SoulAPIError.invalidResponse
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
            UserDefaults.standard.set(language, forKey: "soulMarkLanguage")
            UserDefaults.standard.set(gender, forKey: "soulMarkGenderTheme")
            UserDefaults.standard.set(appearance == "light" ? "day" : appearance == "dark" ? "night" : "auto", forKey: "soulMarkAppearanceMode")
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

    func recordReview(_ record: ConversationReviewRecord) async {
        guard let token = tokenStore.read() else { return }
        try? await api.saveReview(token: token, record: record)
    }

    func loadReviews() async -> [ConversationReviewRecord]? {
        guard let token = tokenStore.read() else { return nil }
        return try? await api.reviews(token: token).compactMap(\.record)
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
