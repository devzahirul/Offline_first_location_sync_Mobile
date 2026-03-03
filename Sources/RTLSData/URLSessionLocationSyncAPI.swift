import Foundation
import RTLSCore

public enum LocationSyncAPIError: Error, Equatable {
    case nonHTTPResponse
    case httpStatus(Int, body: String?)
    case decodingFailed
}

public struct URLSessionLocationSyncAPI: LocationSyncAPI {
    public var baseURL: URL
    public var tokenProvider: AuthTokenProvider
    public var session: URLSession

    public init(
        baseURL: URL,
        tokenProvider: AuthTokenProvider,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.session = session
    }

    public func upload(batch: LocationUploadBatch) async throws -> LocationUploadResult {
        let url = baseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("locations")
            .appendingPathComponent("batch")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let token = try await tokenProvider.accessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        request.httpBody = try RTLSJSON.encoder().encode(batch)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LocationSyncAPIError.nonHTTPResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LocationSyncAPIError.httpStatus(http.statusCode, body: String(data: data, encoding: .utf8))
        }

        do {
            return try RTLSJSON.decoder().decode(LocationUploadResult.self, from: data)
        } catch {
            throw LocationSyncAPIError.decodingFailed
        }
    }
}

