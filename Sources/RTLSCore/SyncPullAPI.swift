import Foundation

/// Opaque token from server for incremental fetch. Client persists and passes on next fetch.
public struct SyncCursor: Sendable, Equatable {
    public let value: Data

    public init(value: Data) {
        self.value = value
    }

    public init(string: String) {
        self.value = Data(string.utf8)
    }

    public var stringValue: String? {
        String(data: value, encoding: .utf8)
    }
}

/// Result of a pull (fetch) from server.
public struct SyncFetchResult: Sendable {
    public var items: [LocationPoint]
    public var nextCursor: SyncCursor?
    public var serverTime: Date?

    public init(items: [LocationPoint], nextCursor: SyncCursor? = nil, serverTime: Date? = nil) {
        self.items = items
        self.nextCursor = nextCursor
        self.serverTime = serverTime
    }
}

/// Optional: implement for bidirectional sync. If not provided, engine is upload-only.
public protocol LocationPullAPI: Sendable {
    /// Fetch server changes since last known cursor. Returns items and next cursor.
    func fetch(since cursor: SyncCursor?) async throws -> SyncFetchResult
}
