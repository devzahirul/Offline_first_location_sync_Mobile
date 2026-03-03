import Foundation

public protocol LocationSyncAPI: Sendable {
    func upload(batch: LocationUploadBatch) async throws -> LocationUploadResult
}

