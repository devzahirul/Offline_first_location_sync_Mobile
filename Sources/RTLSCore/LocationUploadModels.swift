import Foundation

public struct LocationUploadBatch: Codable, Sendable {
    public var schemaVersion: Int
    public var points: [LocationPoint]

    public init(schemaVersion: Int = 1, points: [LocationPoint]) {
        self.schemaVersion = schemaVersion
        self.points = points
    }
}

public struct LocationUploadResult: Codable, Sendable, Equatable {
    public struct Rejected: Codable, Sendable, Equatable {
        public var id: UUID
        public var reason: String

        public init(id: UUID, reason: String) {
            self.id = id
            self.reason = reason
        }
    }

    public var acceptedIds: [UUID]
    public var rejected: [Rejected]
    public var serverTime: Date?

    public init(acceptedIds: [UUID], rejected: [Rejected], serverTime: Date? = nil) {
        self.acceptedIds = acceptedIds
        self.rejected = rejected
        self.serverTime = serverTime
    }
}

