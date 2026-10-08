import Foundation
import Testing
@testable import SoulMark

private final class TutorialURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, String, Double))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (status, body, delay) = Self.handler!(request)
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [self] in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

private final class TutorialTokenStore: AuthTokenStoring {
    private var token: String?

    func read() -> String? { token }
    func save(_ token: String) { self.token = token }
    func clear() { token = nil }
}

@Suite(.serialized)
struct SoulTutorialTests {
    private static let accountA = "11111111-1111-1111-1111-111111111111"
    private static let accountB = "22222222-2222-2222-2222-222222222222"

    private static func userJSON(id: String, step: Int, onboarding: Bool = true) -> String {
        let completion = step == 4 ? "\"2026-10-08T10:00:00Z\"" : "null"
        return """
        {"id":"\(id)","public_id":null,"email":null,"phone_number":null,"has_wechat":false,"display_name":"Test","preferred_language":"zh","gender":"male","appearance":"light","communication_goal":null,"onboarding_completed":\(onboarding),"tutorial_step":\(step),"tutorial_completed_at":\(completion)}
        """
    }

    @MainActor private func makeSession() -> AppSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TutorialURLProtocol.self]
        return AppSession(
            networkSession: URLSession(configuration: configuration),
            tokenStore: TutorialTokenStore()
        )
    }

    private static func jsonBody(_ request: URLRequest) -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 2048)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
        }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private static func loginOrUserResponse(
        for request: URLRequest,
        steps: [String: Int]
    ) -> (Int, String, Double)? {
        if request.url!.path.hasSuffix("/auth/login") {
            let payload = jsonBody(request)
            let email = payload["email"] as? String ?? "a@example.com"
            return (200, "{\"access_token\":\"\(email)\",\"expires_in_seconds\":3600}", 0)
        }
        if request.url!.path.hasSuffix("/users/me"), request.httpMethod == "GET" {
            let token = request.value(forHTTPHeaderField: "Authorization") ?? ""
            let isB = token.contains("b@example.com")
            let id = isB ? accountB : accountA
            let step = steps[isB ? "b" : "a"] ?? 0
            return (200, userJSON(id: id, step: step), 0)
        }
        return nil
    }

    @Test func tutorialPagesStayInRequiredProductOrder() {
        let pages = SoulTutorialPage.all

        #expect(pages.count == 4)
        #expect(pages.map(\.index) == [0, 1, 2, 3])
        #expect(pages.map(\.title.zh) == ["关系图谱", "情景模拟", "沟通复盘", "关系成长"])
        #expect(Set(pages.map(\.id)).count == 4)
    }

    @Test func scenarioTutorialExplainsSwitchingPeopleAndPrompts() {
        let scenario = SoulTutorialPage.all[1]

        #expect(scenario.body.zh.contains("切换对象"))
        #expect(scenario.body.zh.contains("情景／提示词"))
        #expect(scenario.body.en.localizedCaseInsensitiveContains("person"))
        #expect(scenario.body.en.localizedCaseInsensitiveContains("prompt"))
    }

    @Test func growthTutorialExplainsDecayTitlesAndAchievementBadges() {
        let growth = SoulTutorialPage.all[3]

        #expect(growth.body.zh.contains("经验"))
        #expect(growth.body.zh.contains("衰减"))
        #expect(growth.body.zh.contains("称号"))
        #expect(growth.body.zh.contains("成就徽章"))
    }

    @Test func finalTutorialButtonStartsTheApp() {
        let titles = SoulTutorialPage.all.map(\.buttonTitle.zh)

        #expect(titles == ["下一步", "下一步", "下一步", "开始使用"])
    }

    @Test @MainActor func completedProfileRoutesToTutorialUntilStepFour() async {
        TutorialURLProtocol.handler = { request in
            Self.loginOrUserResponse(for: request, steps: ["a": 0])!
        }
        let session = makeSession()
        defer { session.signOut() }

        await session.login(email: "a@example.com", password: "password")
        #expect(session.route == .tutorial)

        TutorialURLProtocol.handler = { request in
            Self.loginOrUserResponse(for: request, steps: ["a": 4])!
        }
        await session.login(email: "a@example.com", password: "password")
        #expect(session.route == .main)
    }

    @Test @MainActor func failedTutorialAdvanceKeepsCurrentStep() async {
        TutorialURLProtocol.handler = { request in
            if let response = Self.loginOrUserResponse(for: request, steps: ["a": 0]) {
                return response
            }
            return (503, "{}", 0)
        }
        let session = makeSession()
        defer { session.signOut() }
        await session.login(email: "a@example.com", password: "password")

        let succeeded = await session.advanceTutorial(to: 1)

        #expect(!succeeded)
        #expect(session.user?.tutorialStep == 0)
        #expect(session.route == .tutorial)
        #expect(session.errorMessage != nil)
    }

    @Test @MainActor func repeatedTutorialTapCreatesOnlyOneRequest() async {
        var advanceRequests = 0
        TutorialURLProtocol.handler = { request in
            if let response = Self.loginOrUserResponse(for: request, steps: ["a": 0]) {
                return response
            }
            advanceRequests += 1
            return (200, Self.userJSON(id: Self.accountA, step: 1), 0.2)
        }
        let session = makeSession()
        defer { session.signOut() }
        await session.login(email: "a@example.com", password: "password")

        async let first = session.advanceTutorial(to: 1)
        async let second = session.advanceTutorial(to: 1)
        let results = await [first, second]

        #expect(advanceRequests == 1)
        #expect(results.filter { $0 }.count == 1)
        #expect(session.user?.tutorialStep == 1)
    }

    @Test @MainActor func lateTutorialResponseCannotOverwriteAnotherAccount() async throws {
        TutorialURLProtocol.handler = { request in
            if let response = Self.loginOrUserResponse(for: request, steps: ["a": 0, "b": 0]) {
                return response
            }
            return (200, Self.userJSON(id: Self.accountA, step: 1), 0.25)
        }
        let session = makeSession()
        defer { session.signOut() }
        await session.login(email: "a@example.com", password: "password")
        let oldAdvance = Task { await session.advanceTutorial(to: 1) }
        try await Task.sleep(for: .milliseconds(40))

        session.signOut()
        await session.login(email: "b@example.com", password: "password")
        _ = await oldAdvance.value

        #expect(session.user?.id.uuidString.lowercased() == Self.accountB)
        #expect(session.user?.tutorialStep == 0)
        #expect(session.route == .tutorial)
    }
}
