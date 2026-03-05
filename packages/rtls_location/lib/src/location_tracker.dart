import 'dart:async';
import 'package:flutter/services.dart';
import 'package:rtls_core/rtls_core.dart';

/// Background location tracker. Usable independently without sync or WebSocket.
///
/// Collects GPS locations with configurable filtering (accuracy, distance, time)
/// and foreground service support on Android.
///
/// Usage:
/// ```dart
/// final tracker = RTLSLocationTracker();
/// await tracker.configure(userId: 'u1', deviceId: 'd1');
/// await tracker.requestPermission();
/// await tracker.start();
/// tracker.locations.listen((point) { ... });
/// ```
class RTLSLocationTracker {
  static const _channel = MethodChannel('com.rtls.location');
  static const _eventChannel = EventChannel('com.rtls.location/events');

  Stream<RTLSLocationPoint>? _locationStream;

  /// Stream of GPS location points after filtering.
  Stream<RTLSLocationPoint> get locations {
    _locationStream ??= _eventChannel.receiveBroadcastStream().map((raw) {
      final map = Map<String, dynamic>.from(raw as Map);
      return RTLSLocationPoint.fromMap(map);
    });
    return _locationStream!;
  }

  Future<void> configure({
    required String userId,
    required String deviceId,
    RTLSTrackingPolicy trackingPolicy = const RTLSTrackingPolicy(),
    int locationIntervalMs = 10000,
    int minUpdateDistanceMeters = 10,
  }) async {
    await _channel.invokeMethod('configure', {
      'userId': userId,
      'deviceId': deviceId,
      'trackingMode': trackingPolicy.mode.name,
      'distanceMeters': trackingPolicy.distanceMeters,
      'timeIntervalMs': trackingPolicy.timeIntervalMs ?? locationIntervalMs,
      'maxAcceptableAccuracy': trackingPolicy.maxAcceptableAccuracy,
      'locationIntervalMs': locationIntervalMs,
      'minUpdateDistanceMeters': minUpdateDistanceMeters,
    });
  }

  Future<void> requestPermission() async {
    await _channel.invokeMethod('requestPermission');
  }

  Future<void> start() async => await _channel.invokeMethod('start');
  Future<void> stop() async => await _channel.invokeMethod('stop');
}
