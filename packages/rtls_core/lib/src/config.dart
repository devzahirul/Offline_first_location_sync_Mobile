/// Batching policy for offline sync.
class RTLSBatchingPolicy {
  final int maxBatchSize;
  final int flushIntervalSeconds;
  final int maxBatchAgeSeconds;

  const RTLSBatchingPolicy({
    this.maxBatchSize = 50,
    this.flushIntervalSeconds = 10,
    this.maxBatchAgeSeconds = 60,
  });
}

/// Tracking policy for location collection.
enum RTLSTrackingMode { significant, distance, time }

class RTLSTrackingPolicy {
  final RTLSTrackingMode mode;
  final double? distanceMeters;
  final int? timeIntervalMs;
  final double maxAcceptableAccuracy;

  const RTLSTrackingPolicy({
    this.mode = RTLSTrackingMode.distance,
    this.distanceMeters = 25,
    this.timeIntervalMs,
    this.maxAcceptableAccuracy = 100,
  });

  const RTLSTrackingPolicy.significant()
      : mode = RTLSTrackingMode.significant,
        distanceMeters = null,
        timeIntervalMs = null,
        maxAcceptableAccuracy = 100;

  const RTLSTrackingPolicy.distance(double meters)
      : mode = RTLSTrackingMode.distance,
        distanceMeters = meters,
        timeIntervalMs = null,
        maxAcceptableAccuracy = 100;

  const RTLSTrackingPolicy.time(int intervalMs)
      : mode = RTLSTrackingMode.time,
        distanceMeters = null,
        timeIntervalMs = intervalMs,
        maxAcceptableAccuracy = 100;
}
