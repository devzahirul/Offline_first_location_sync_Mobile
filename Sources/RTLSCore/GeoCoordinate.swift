import Foundation

public struct GeoCoordinate: Codable, Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

extension GeoCoordinate {
    /// Great-circle distance (meters) using haversine.
    public func distance(to other: GeoCoordinate) -> Double {
        let earthRadiusMeters = 6_371_000.0

        let lat1 = latitude * .pi / 180.0
        let lon1 = longitude * .pi / 180.0
        let lat2 = other.latitude * .pi / 180.0
        let lon2 = other.longitude * .pi / 180.0

        let dLat = lat2 - lat1
        let dLon = lon2 - lon1

        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusMeters * c
    }
}

