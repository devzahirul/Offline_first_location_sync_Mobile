import Foundation

public protocol LocationStore: Sendable {
    func insert(points: [LocationPoint]) async throws

    func fetchPendingPoints(limit: Int) async throws -> [LocationPoint]
    func pendingCount() async throws -> Int
    func oldestPendingRecordedAt() async throws -> Date?

    func markSent(pointIds: [UUID], sentAt: Date) async throws
    func markFailed(pointIds: [UUID], errorMessage: String) async throws
}

