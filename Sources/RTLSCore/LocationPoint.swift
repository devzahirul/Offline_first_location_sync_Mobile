import Foundation

public struct LocationPoint: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var userId: String
    public var deviceId: String
    public var recordedAt: Date
    public var coordinate: GeoCoordinate

    public var horizontalAccuracy: Double?
    public var verticalAccuracy: Double?
    public var altitude: Double?
    public var speed: Double?
    public var course: Double?

    public init(
        id: UUID = UUID(),
        userId: String,
        deviceId: String,
        recordedAt: Date,
        coordinate: GeoCoordinate,
        horizontalAccuracy: Double? = nil,
        verticalAccuracy: Double? = nil,
        altitude: Double? = nil,
        speed: Double? = nil,
        course: Double? = nil
    ) {
        self.id = id
        self.userId = userId
        self.deviceId = deviceId
        self.recordedAt = recordedAt
        self.coordinate = coordinate
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.altitude = altitude
        self.speed = speed
        self.course = course
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case userId
        case deviceId
        case recordedAt
        case lat
        case lng
        case horizontalAccuracy
        case verticalAccuracy
        case altitude
        case speed
        case course
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.userId = try c.decode(String.self, forKey: .userId)
        self.deviceId = try c.decode(String.self, forKey: .deviceId)
        self.recordedAt = try c.decode(Date.self, forKey: .recordedAt)

        let lat = try c.decode(Double.self, forKey: .lat)
        let lng = try c.decode(Double.self, forKey: .lng)
        self.coordinate = GeoCoordinate(latitude: lat, longitude: lng)

        self.horizontalAccuracy = try c.decodeIfPresent(Double.self, forKey: .horizontalAccuracy)
        self.verticalAccuracy = try c.decodeIfPresent(Double.self, forKey: .verticalAccuracy)
        self.altitude = try c.decodeIfPresent(Double.self, forKey: .altitude)
        self.speed = try c.decodeIfPresent(Double.self, forKey: .speed)
        self.course = try c.decodeIfPresent(Double.self, forKey: .course)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(userId, forKey: .userId)
        try c.encode(deviceId, forKey: .deviceId)
        try c.encode(recordedAt, forKey: .recordedAt)

        try c.encode(coordinate.latitude, forKey: .lat)
        try c.encode(coordinate.longitude, forKey: .lng)

        try c.encodeIfPresent(horizontalAccuracy, forKey: .horizontalAccuracy)
        try c.encodeIfPresent(verticalAccuracy, forKey: .verticalAccuracy)
        try c.encodeIfPresent(altitude, forKey: .altitude)
        try c.encodeIfPresent(speed, forKey: .speed)
        try c.encodeIfPresent(course, forKey: .course)
    }
}
