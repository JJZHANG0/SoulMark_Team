import Foundation
import Testing
@testable import SoulMark

private final class GrowthURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, String, Double))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, text, delay) = Self.handler!(request)
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [self] in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(text.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}

@Suite(.serialized)
struct GrowthNetworkTests {
    private static let a = "11111111-1111-1111-1111-111111111111"
    private static let b = "22222222-2222-2222-2222-222222222222"
    static func snapshot(_ balance: Int) -> String {
        """
        {"balance":\(balance),"level":1,"level_experience":\(balance),"next_level_experience":100,"peak_level":1,"chat_experience_today":0,"title_key":"explorer","next_title_level":3,"decayed_experience":0,"next_decay_date":"2026-10-20"}
        """
    }
    private static func jsonBody(_ request: URLRequest) -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 2048)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
        }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
    private static func auth(_ request: URLRequest) -> (Int, String, Double)? {
        if request.url!.path.hasSuffix("/auth/login") {
            let email = jsonBody(request)["email"] as? String ?? "a@example.com"
            return (200, "{\"access_token\":\"\(email)\",\"expires_in_seconds\":3600}", 0)
        }
        if request.url!.path.hasSuffix("/users/me") {
            let id = request.value(forHTTPHeaderField: "Authorization")!.contains("b@example.com") ? b : a
            return (200, """
            {"id":"\(id)","has_wechat":false,"display_name":"Test","preferred_language":"zh","appearance":"light","onboarding_completed":true}
            """, 0)
        }
        return nil
    }
    @MainActor private func makeSession() -> AppSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [GrowthURLProtocol.self]
        return AppSession(networkSession: URLSession(configuration: config))
    }

    @Test @MainActor func oldAccountResponseCannotOverwriteNewAccount() async throws {
        GrowthURLProtocol.handler = { request in
            if let auth = Self.auth(request) { return auth }
            let old = request.value(forHTTPHeaderField: "Authorization")!.contains("a@example.com")
            return (200, Self.snapshot(old ? 90 : 30), old ? 0.25 : 0)
        }
        let session = makeSession()
        defer { session.signOut() }
        await session.login(email: "a@example.com", password: "test")
        let oldRequest = Task { await session.refreshGrowth() }
        try await Task.sleep(for: .milliseconds(40))
        session.signOut()
        await session.login(email: "b@example.com", password: "test")
        await session.recordForegroundActivity()
        await oldRequest.value
        #expect(session.user?.id.uuidString.lowercased() == Self.b)
        #expect(session.growthState.snapshot?.balance == 30)
    }

    @Test @MainActor func failedForegroundReportCanBeRetried() async {
        var attempts = 0
        var paths: [String] = []
        GrowthURLProtocol.handler = { request in
            if let auth = Self.auth(request) { return auth }
            attempts += 1
            paths.append(request.url!.path)
            return attempts == 1 ? (503, "{}", 0) : (200, Self.snapshot(40), 0)
        }
        let session = makeSession()
        defer { session.signOut() }
        await session.login(email: "a@example.com", password: "test")
        await session.recordForegroundActivity()
        #expect(session.growthState == .failed)
        await session.refreshGrowth()
        #expect(session.growthState.snapshot?.balance == 40)
        #expect(attempts == 2)
        #expect(paths == ["/api/v1/growth/active", "/api/v1/growth/active"])
    }

    @Test @MainActor func practiceRetryUsesSameEventAndStopsAfterSuccess() async throws {
        var savedIDs: [String] = []
        GrowthURLProtocol.handler = { request in
            if let auth = Self.auth(request) { return auth }
            if request.url!.path.hasSuffix("/practices") {
                savedIDs.append(Self.jsonBody(request)["event_id"] as? String ?? "missing")
                if savedIDs.count == 1 { return (503, "{}", 0) }
                return (200, """
                {"id":"33333333-3333-3333-3333-333333333333","participant_name":"Soul","mode_title":"Practice","duration_seconds":5,"user_transcript":"Hi","assistant_transcript":"Hello","created_at":"2026-10-08T10:00:00Z","growth":\(Self.snapshot(5)),"awarded_experience":5}
                """, 0)
            }
            return (200, Self.snapshot(0), 0)
        }
        let session = makeSession()
        defer { session.signOut() }
        await session.login(email: "a@example.com", password: "test")
        await session.recordForegroundActivity()
        let event = UUID()
        session.queuePractice(id: event, duration: 5, participant: "Soul", mode: "Practice", guidance: "", messages: [GrowthChatMessage(role: "user", text: "Hi"), GrowthChatMessage(role: "assistant", text: "Hello")])
        for _ in 0..<100 {
            if session.practiceSaveError != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(session.practiceSaveError != nil)
        await session.retryPendingPractices()
        #expect(session.practiceSaveError == nil)
        #expect(session.growthState.snapshot?.balance == 5)
        #expect(savedIDs == [event.uuidString, event.uuidString])
        await session.retryPendingPractices()
        #expect(savedIDs.count == 2)
    }
}
