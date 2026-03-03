import Foundation
import RTLSCore

public struct WebSocketLocationSubscriberConfiguration: Sendable {
    public var baseURL: URL
    public var tokenProvider: AuthTokenProvider

    public init(baseURL: URL, tokenProvider: AuthTokenProvider) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
    }
}

public actor WebSocketLocationSubscriber {
    private let config: WebSocketLocationSubscriberConfiguration
    private let session: URLSession

    public init(
        configuration: WebSocketLocationSubscriberConfiguration,
        session: URLSession = .shared
    ) {
        self.config = configuration
        self.session = session
    }

    public func subscribe(userId: String) -> AsyncThrowingStream<LocationPoint, Error> {
        let config = self.config
        let session = self.session

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let token = try await config.tokenProvider.accessToken()
                    var request = URLRequest(url: makeWebSocketURL(from: config.baseURL))
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                    let ws = session.webSocketTask(with: request)
                    ws.resume()

                    let subscribe = SubscribeMessage(userId: userId)
                    let subscribeData = try RTLSJSON.encoder().encode(subscribe)
                    try await ws.send(.data(subscribeData))

                    while !Task.isCancelled {
                        let message = try await ws.receive()
                        let data: Data
                        switch message {
                        case .data(let d): data = d
                        case .string(let s): data = Data(s.utf8)
                        @unknown default:
                            continue
                        }

                        let envelope = try RTLSJSON.decoder().decode(IncomingEnvelope.self, from: data)
                        if envelope.type == "location", let point = envelope.point {
                            continuation.yield(point)
                        }
                    }

                    ws.cancel(with: .goingAway, reason: nil)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

private func makeWebSocketURL(from baseURL: URL) -> URL {
    let httpURL = baseURL
        .appendingPathComponent("v1")
        .appendingPathComponent("ws")

    guard var components = URLComponents(url: httpURL, resolvingAgainstBaseURL: false) else {
        return httpURL
    }

    if components.scheme == "https" { components.scheme = "wss" }
    if components.scheme == "http" { components.scheme = "ws" }
    return components.url ?? httpURL
}

private struct SubscribeMessage: Codable, Sendable {
    var type: String = "subscribe"
    var userId: String
}

private struct IncomingEnvelope: Codable, Sendable {
    var type: String
    var point: LocationPoint?
}
