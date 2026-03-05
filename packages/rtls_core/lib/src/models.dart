/// A recorded location point with metadata.
class RTLSLocationPoint {
  final String id;
  final String userId;
  final String deviceId;
  final int recordedAtMs;
  final double lat;
  final double lng;
  final double? horizontalAccuracy;
  final double? verticalAccuracy;
  final double? altitude;
  final double? speed;
  final double? course;

  const RTLSLocationPoint({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.recordedAtMs,
    required this.lat,
    required this.lng,
    this.horizontalAccuracy,
    this.verticalAccuracy,
    this.altitude,
    this.speed,
    this.course,
  });

  factory RTLSLocationPoint.fromMap(Map<String, dynamic> map) {
    return RTLSLocationPoint(
      id: map['id'] as String,
      userId: map['userId'] as String,
      deviceId: map['deviceId'] as String,
      recordedAtMs: (map['recordedAt'] ?? map['recordedAtMs']) as int,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      horizontalAccuracy: (map['horizontalAccuracy'] as num?)?.toDouble(),
      verticalAccuracy: (map['verticalAccuracy'] as num?)?.toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      course: (map['course'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'deviceId': deviceId,
    'recordedAt': recordedAtMs,
    'lat': lat,
    'lng': lng,
    'horizontalAccuracy': horizontalAccuracy,
    'verticalAccuracy': verticalAccuracy,
    'altitude': altitude,
    'speed': speed,
    'course': course,
  };
}

/// Pending sync statistics.
class RTLSPendingStats {
  final int count;
  final int? oldestRecordedAtMs;

  const RTLSPendingStats({required this.count, this.oldestRecordedAtMs});
}
