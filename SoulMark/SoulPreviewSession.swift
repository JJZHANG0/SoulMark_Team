import Foundation

/// Session for Xcode canvas previews. It never has a token, and its URL session
/// cannot open a connection, so a preview does not call the API.
enum SoulPreviewSession {
    @MainActor static let shared: AppSession = AppSession(
        networkSession: offlineSession,
        tokenStore: EmptyPreviewTokenStore(),
        previewChallenges: notStartedChallenges
    )

    /// Same titles as the API catalog, with no progress. The canvas never requests them.
    private static let notStartedChallenges = ChallengeListDTO(
        challenges: [
            challenge("johari_blind_spot", "盲区来信", "请两位信任的人，说一个你没注意到的自己", "johari", "乔哈里视窗", "openness", "开放与反馈", "eye.trianglebadge.exclamationmark", 15, 3, 4),
            challenge("johari_open_window", "打开一扇窗", "向一个人分享一个 TA 还不知道的你", "johari", "乔哈里视窗", "openness", "开放与反馈", "window.casement", 10, 2, 3),
            challenge("values_compass", "价值指南针", "找到真正驱动你做选择的 3 个词", "values", "价值观澄清", "clarity", "价值与自我清晰", "safari", 12, 1, 4),
            challenge("self_concept_ten", "十个“我是”", "用十句话描摹此刻的自己", "values", "价值观澄清", "clarity", "价值与自我清晰", "person.text.rectangle", 8, 1, 3),
            challenge("emotion_naming", "情绪命名三天", "每天一次，给情绪一个更准确的名字", "emotional_intelligence", "情绪智力", "emotion", "情绪觉察", "heart.text.square", 3, 3, 4),
            challenge("six_second_pause", "暂停六秒", "在下一次被触发时，先停六秒再回应", "emotional_intelligence", "情绪智力", "emotion", "情绪觉察", "pause.circle", 5, 3, 3),
            challenge("awareness_wheel", "觉察之轮", "把一次关系里的卡点拆成五块", "awareness_wheel", "觉察之轮", "relation", "关系中的自己", "circle.hexagongrid", 10, 1, 5),
            challenge("relation_mirror", "关系里的我", "在三段关系里，看看不同的自己", "johari", "乔哈里视窗", "relation", "关系中的自己", "person.2.wave.2", 12, 1, 4),
            challenge("how_i_want_to_be_seen", "希望被如何看待", "写下日常里的自己，以及你希望被看成什么样", "values", "价值观澄清", "clarity", "价值与自我清晰", "person.crop.rectangle", 8, 1, 2),
            challenge("energy_and_reply_pace", "精力与回复快慢", "时间实际去了哪，以及对谁回得最快、最慢", "awareness_wheel", "觉察之轮", "relation", "关系中的自己", "clock.arrow.circlepath", 10, 1, 3),
            challenge("role_stance", "角色里的端着与放松", "在已有的人里标出角色，并各配一句原话", "johari", "乔哈里视窗", "relation", "关系中的自己", "person.3.sequence", 10, 1, 3)
        ],
        activeCount: 0,
        completedCount: 0
    )

    private static func challenge(
        _ key: String,
        _ title: String,
        _ subtitle: String,
        _ model: String,
        _ modelTitle: String,
        _ dimension: String,
        _ dimensionTitle: String,
        _ icon: String,
        _ durationMinutes: Int,
        _ spanDays: Int,
        _ stepCount: Int
    ) -> ChallengeSummaryDTO {
        ChallengeSummaryDTO(
            key: key,
            title: title,
            subtitle: subtitle,
            model: model,
            modelTitle: modelTitle,
            dimension: dimension,
            dimensionTitle: dimensionTitle,
            icon: icon,
            durationMinutes: durationMinutes,
            spanDays: spanDays,
            stepCount: stepCount,
            rewardExperience: 20,
            status: "not_started",
            completedSteps: 0,
            completionCount: 0
        )
    }

    private static let offlineSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PreviewOfflineURLProtocol.self]
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 1
        configuration.timeoutIntervalForResource = 1
        return URLSession(configuration: configuration)
    }()
}

private final class EmptyPreviewTokenStore: AuthTokenStoring {
    func read() -> String? { nil }
    func save(_ token: String) {}
    func clear() {}
}

private final class PreviewOfflineURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}
