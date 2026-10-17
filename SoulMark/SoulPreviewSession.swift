import Foundation

/// Session for Xcode canvas previews. It never has a token, and its URL session
/// cannot open a connection, so a preview does not call the API.
enum SoulPreviewSession {
    @MainActor static let shared: AppSession = AppSession(
        networkSession: offlineSession,
        tokenStore: EmptyPreviewTokenStore()
    )

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
