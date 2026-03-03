import Foundation

public struct AuthTokenProvider: Sendable {
    public var accessToken: @Sendable () async throws -> String

    public init(accessToken: @escaping @Sendable () async throws -> String) {
        self.accessToken = accessToken
    }
}

