import 'dart:async';
import 'package:flutter/services.dart';
import 'package:rtls_core/rtls_core.dart';

/// Offline-first sync client. Usable independently without location or WebSocket.
///
/// Data inserted via [insert] is stored in SQLite and batch-uploaded to the
/// server via SyncEngine. Supports bidirectional pull and merge.
///
/// Usage:
/// ```dart
/// final sync = RTLSOfflineSync();
/// await sync.configure(baseUrl: 'https://api.example.com', userId: 'u1', deviceId: 'd1');
/// await sync.start();
/// await sync.insert([point1, point2]);
/// ```
class RTLSOfflineSync {
  static const _channel = MethodChannel('com.rtls.offline_sync');
  static const _eventChannel = EventChannel('com.rtls.offline_sync/events');

  Stream<RTLSEvent>? _eventStream;

  /// Stream of sync events (upload success/failure, pull events).
  Stream<RTLSEvent> get events {
    _eventStream ??= _eventChannel.receiveBroadcastStream().map(_parseEvent);
    return _eventStream!;
  }

  /// Configure the offline sync engine.
  Future<void> configure({
    required String baseUrl,
    required String userId,
    required String deviceId,
    String accessToken = '',
    RTLSBatchingPolicy batchingPolicy = const RTLSBatchingPolicy(),
  }) async {
    await _channel.invokeMethod('configure', {
      'baseUrl': baseUrl,
      'userId': userId,
      'deviceId': deviceId,
      'accessToken': accessToken,
      'maxBatchSize': batchingPolicy.maxBatchSize,
      'flushIntervalSeconds': batchingPolicy.flushIntervalSeconds,
      'maxBatchAgeSeconds': batchingPolicy.maxBatchAgeSeconds,
    });
  }

  Future<void> start() async => await _channel.invokeMethod('start');
  Future<void> stop() async => await _channel.invokeMethod('stop');

  /// Insert location points from any source. SyncEngine handles upload.
  Future<void> insert(List<RTLSLocationPoint> points) async {
    await _channel.invokeMethod('insert', {
      'points': points.map((p) => p.toMap()).toList(),
    });
  }

  Future<void> flushNow() async => await _channel.invokeMethod('flushNow');
  Future<void> pullNow() async => await _channel.invokeMethod('pullNow');

  Future<RTLSPendingStats> getStats() async {
    final result = await _channel.invokeMethod<Map>('getStats');
    return RTLSPendingStats(
      count: result?['pendingCount'] as int? ?? 0,
      oldestRecordedAtMs: result?['oldestPendingRecordedAtMs'] as int?,
    );
  }

  RTLSEvent _parseEvent(dynamic raw) {
    if (raw is! Map) return const RTLSErrorEvent('Unknown event');
    final map = Map<String, dynamic>.from(raw);
    final kind = map['kind'] as String?;
    switch (kind) {
      case 'uploadSucceeded':
        return RTLSSyncUploadSucceeded(
          accepted: map['accepted'] as int? ?? 0,
          rejected: map['rejected'] as int? ?? 0,
        );
      case 'uploadFailed':
        return RTLSSyncUploadFailed(map['message'] as String? ?? '');
      case 'pullSucceeded':
        return RTLSSyncPullSucceeded(map['count'] as int? ?? 0);
      case 'pullFailed':
        return RTLSSyncPullFailed(map['message'] as String? ?? '');
      default:
        return RTLSErrorEvent('Unknown event kind: $kind');
    }
  }
}
