import 'dart:async';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.rtls.flutter/rtls');
const _eventChannel = EventChannel('com.rtls.flutter/rtls_events');

// ---------------------------------------------------------------------------
// Typed event models — parse once from RTLSync.events for type-safe handling
// ---------------------------------------------------------------------------

/// A single recorded location point (from `recorded` events).
class RTLSRecordedPoint {
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

  const RTLSRecordedPoint({
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

  static RTLSRecordedPoint? fromMap(Map<dynamic, dynamic>? point) {
    if (point == null) return null;
    final lat = point['lat'];
    final lng = point['lng'];
    if (lat == null || lng == null) return null;
    return RTLSRecordedPoint(
      id: point['id']?.toString() ?? '',
      userId: point['userId']?.toString() ?? '',
      deviceId: point['deviceId']?.toString() ?? '',
      recordedAtMs: (point['recordedAtMs'] as num?)?.toInt() ?? 0,
      lat: (lat as num).toDouble(),
      lng: (lng as num).toDouble(),
      horizontalAccuracy: (point['horizontalAccuracy'] as num?)?.toDouble(),
      verticalAccuracy: (point['verticalAccuracy'] as num?)?.toDouble(),
      altitude: (point['altitude'] as num?)?.toDouble(),
      speed: (point['speed'] as num?)?.toDouble(),
      course: (point['course'] as num?)?.toDouble(),
    );
  }
}

/// Sync event: upload succeeded or failed.
class RTLSyncEventPayload {
  final String kind; // 'uploadSucceeded' | 'uploadFailed'
  final int? accepted;
  final int? rejected;
  final String? message;

  const RTLSyncEventPayload({
    required this.kind,
    this.accepted,
    this.rejected,
    this.message,
  });

  static RTLSyncEventPayload? fromMap(Map<dynamic, dynamic>? e) {
    if (e == null) return null;
    final ev = e['event']?.toString();
    if (ev == null) return null;
    return RTLSyncEventPayload(
      kind: ev,
      accepted: (e['accepted'] as num?)?.toInt(),
      rejected: (e['rejected'] as num?)?.toInt(),
      message: e['message']?.toString(),
    );
  }
}

/// Discriminated union for all event types from RTLSync.events.
sealed class RTLSyncEvent {
  const RTLSyncEvent();
  static RTLSyncEvent? fromMap(Map<dynamic, dynamic> raw) {
    final type = raw['type']?.toString();
    switch (type) {
      case 'recorded':
        final point = RTLSRecordedPoint.fromMap(raw['point'] as Map<dynamic, dynamic>?);
        return point != null ? RTLSRecordedEvent(point) : null;
      case 'syncEvent':
        final payload = RTLSyncEventPayload.fromMap(raw);
        return payload != null ? RTLSyncEventPayloadEvent(payload) : null;
      case 'error':
        return RTLSyncErrorEvent(raw['message']?.toString() ?? 'Unknown error');
      case 'trackingStarted':
        return const RTLSyncTrackingStartedEvent();
      case 'trackingStopped':
        return const RTLSyncTrackingStoppedEvent();
      case 'authorizationChanged':
        return RTLSyncAuthorizationChangedEvent(raw['authorization']?.toString() ?? '');
      default:
        return null;
    }
  }
}

class RTLSRecordedEvent extends RTLSyncEvent {
  final RTLSRecordedPoint point;
  const RTLSRecordedEvent(this.point);
}

class RTLSyncEventPayloadEvent extends RTLSyncEvent {
  final RTLSyncEventPayload payload;
  const RTLSyncEventPayloadEvent(this.payload);
}

class RTLSyncErrorEvent extends RTLSyncEvent {
  final String message;
  const RTLSyncErrorEvent(this.message);
}

class RTLSyncTrackingStartedEvent extends RTLSyncEvent {
  const RTLSyncTrackingStartedEvent();
}

class RTLSyncTrackingStoppedEvent extends RTLSyncEvent {
  const RTLSyncTrackingStoppedEvent();
}

class RTLSyncAuthorizationChangedEvent extends RTLSyncEvent {
  final String authorization;
  const RTLSyncAuthorizationChangedEvent(this.authorization);
}

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

class RTLSyncConfig {
  final String baseUrl;
  final String userId;
  final String deviceId;
  final String accessToken;
  /// Time-based: update interval in seconds (e.g. 360 for 6 min). Applied on Android; iOS uses RTLSyncKit defaults.
  final double? locationIntervalSeconds;
  /// Distance-based: min distance in meters between updates. If set with interval, distance is used.
  final double? locationDistanceMeters;
  /// If true, use ~500 m / less frequent updates (significant-change style).
  final bool useSignificantLocationOnly;
  /// Max points per upload batch (Android KMP; iOS uses RTLSyncKit BatchingPolicy). Default 50.
  final int? batchMaxSize;
  /// Flush interval in seconds (Android KMP). Default 10.
  final double? flushIntervalSeconds;
  /// Flush when oldest pending point is older than this many seconds (Android KMP). Default 60.
  final double? maxBatchAgeSeconds;

  const RTLSyncConfig({
    required this.baseUrl,
    required this.userId,
    required this.deviceId,
    required this.accessToken,
    this.locationIntervalSeconds,
    this.locationDistanceMeters,
    this.useSignificantLocationOnly = false,
    this.batchMaxSize,
    this.flushIntervalSeconds,
    this.maxBatchAgeSeconds,
  });

  /// Quick config with sensible defaults. Use for local/dev; override batch params if needed.
  /// [baseUrl] e.g. http://192.168.1.100:3000 (no trailing slash).
  factory RTLSyncConfig.withDefaults({
    required String baseUrl,
    required String userId,
    String? deviceId,
    String accessToken = 'dev-token',
    int batchMaxSize = 50,
    double flushIntervalSeconds = 10,
    double maxBatchAgeSeconds = 60,
    double? locationIntervalSeconds,
    double? locationDistanceMeters,
    bool useSignificantLocationOnly = false,
  }) =>
      RTLSyncConfig(
        baseUrl: baseUrl,
        userId: userId,
        deviceId: deviceId ?? 'device-${userId}_default',
        accessToken: accessToken,
        batchMaxSize: batchMaxSize,
        flushIntervalSeconds: flushIntervalSeconds,
        maxBatchAgeSeconds: maxBatchAgeSeconds,
        locationIntervalSeconds: locationIntervalSeconds,
        locationDistanceMeters: locationDistanceMeters,
        useSignificantLocationOnly: useSignificantLocationOnly,
      );

  Map<String, dynamic> toMap() => {
        'baseUrl': baseUrl,
        'userId': userId,
        'deviceId': deviceId,
        'accessToken': accessToken,
        'locationIntervalSeconds': locationIntervalSeconds,
        'locationDistanceMeters': locationDistanceMeters,
        'useSignificantLocationOnly': useSignificantLocationOnly,
        'batchMaxSize': batchMaxSize,
        'flushIntervalSeconds': flushIntervalSeconds,
        'maxBatchAgeSeconds': maxBatchAgeSeconds,
      };
}

class RTLSStats {
  final int pendingCount;
  final int? oldestPendingRecordedAtMs;

  RTLSStats({required this.pendingCount, this.oldestPendingRecordedAtMs});

  factory RTLSStats.fromMap(Map<dynamic, dynamic> m) {
    return RTLSStats(
      pendingCount: (m['pendingCount'] as num?)?.toInt() ?? 0,
      oldestPendingRecordedAtMs: m['oldestPendingRecordedAtMs'] != null
          ? (m['oldestPendingRecordedAtMs'] as num).toInt()
          : null,
    );
  }
}

class RTLSync {
  static Stream<Map<dynamic, dynamic>>? _eventStream;

  static Future<void> configure(RTLSyncConfig config) async {
    await _channel.invokeMethod('configure', config.toMap());
  }

  static Future<void> startTracking() async {
    await _channel.invokeMethod('startTracking');
  }

  static Future<void> stopTracking() async {
    await _channel.invokeMethod('stopTracking');
  }

  static Future<void> requestAlwaysAuthorization() async {
    await _channel.invokeMethod('requestAlwaysAuthorization');
  }

  static Future<RTLSStats> getStats() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getStats');
    return RTLSStats.fromMap(result ?? {});
  }

  static Future<void> flushNow() async {
    await _channel.invokeMethod('flushNow');
  }

  static Stream<Map<dynamic, dynamic>> get events {
    _eventStream ??= _eventChannel.receiveBroadcastStream().map((e) => e as Map<dynamic, dynamic>);
    return _eventStream!;
  }
}
