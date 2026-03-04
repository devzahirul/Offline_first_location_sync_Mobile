import Foundation

/// Context passed to merge strategy when resolving a conflict.
public struct MergeContext: Sendable {
    public var lastSyncAt: Date?
    public var serverTime: Date?

    public init(lastSyncAt: Date? = nil, serverTime: Date? = nil) {
        self.lastSyncAt = lastSyncAt
        self.serverTime = serverTime
    }
}

/// Result of resolving a conflict: keep local, keep server, or use a merged item.
public enum LocationMergeResult: Sendable {
    case keepLocal
    case keepServer
    case use(LocationPoint)
}

/// Optional. If not provided, default is server-wins for pull (overwrite local with server).
public protocol LocationMergeStrategy: Sendable {
    /// Called when local and server both have an item with the same id.
    /// Return the resolved result to persist.
    func resolve(
        local: LocationPoint?,
        server: LocationPoint,
        context: MergeContext
    ) -> LocationMergeResult
}
