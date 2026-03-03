import 'dart:async';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.rtls.flutter/rtls');
const _eventChannel = EventChannel('com.rtls.flutter/rtls_events');

class RTLSyncConfig {
  final String baseUrl;
  final String userId;
  final String deviceId;
  final String accessToken;

  const RTLSyncConfig({
    required this.baseUrl,
    required this.userId,
    required this.deviceId,
    required this.accessToken,
  });

  Map<String, dynamic> toMap() => {
        'baseUrl': baseUrl,
        'userId': userId,
        'deviceId': deviceId,
        'accessToken': accessToken,
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
