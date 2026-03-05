import 'dart:async';
import 'package:rtls_core/rtls_core.dart';
import 'package:rtls_offline_sync/rtls_offline_sync.dart';
import 'package:rtls_websocket/rtls_websocket.dart';
import 'package:rtls_location/rtls_location.dart';

/// Unified RTLS client combining any combination of:
/// - Offline sync (batch upload + bidirectional pull)
/// - WebSocket (real-time push + subscribe)
/// - Location (background GPS collection)
///
/// Each capability is optional. Use individual packages for more control.
///
/// Usage:
/// ```dart
/// final client = RTLSUnifiedClient(
///   offlineSync: RTLSOfflineSync(),         // optional
///   webSocket: RTLSRealTimeClient(...),     // optional
///   locationTracker: RTLSLocationTracker(), // optional
/// );
/// await client.configure(...);
/// await client.start();
/// ```
class RTLSUnifiedClient {
  final RTLSOfflineSync? offlineSync;
  final RTLSRealTimeClient? webSocket;
  final RTLSLocationTracker? locationTracker;

  StreamSubscription? _locationSub;
  final _eventsController = StreamController<RTLSEvent>.broadcast();

  /// Unified event stream from all enabled capabilities.
  Stream<RTLSEvent> get events => _eventsController.stream;

  /// Incoming locations from WebSocket subscriptions.
  Stream<RTLSLocationPoint>? get incomingLocations => webSocket?.incomingLocations;

  RTLSUnifiedClient({
    this.offlineSync,
    this.webSocket,
    this.locationTracker,
  });

  /// Configure all enabled capabilities.
  Future<void> configure({
    required String baseUrl,
    required String userId,
    required String deviceId,
    String accessToken = '',
    RTLSBatchingPolicy batchingPolicy = const RTLSBatchingPolicy(),
    RTLSTrackingPolicy trackingPolicy = const RTLSTrackingPolicy(),
  }) async {
    if (offlineSync != null) {
      await offlineSync!.configure(
        baseUrl: baseUrl,
        userId: userId,
        deviceId: deviceId,
        accessToken: accessToken,
        batchingPolicy: batchingPolicy,
      );
    }

    if (locationTracker != null) {
      await locationTracker!.configure(
        userId: userId,
        deviceId: deviceId,
        trackingPolicy: trackingPolicy,
      );
    }
  }

  /// Start all enabled capabilities.
  Future<void> start() async {
    if (offlineSync != null) await offlineSync!.start();
    if (webSocket != null) await webSocket!.connect();
    if (locationTracker != null) {
      await locationTracker!.start();
      _locationSub = locationTracker!.locations.listen(_onLocationReceived);
    }

    if (offlineSync != null) {
      offlineSync!.events.listen((e) => _eventsController.add(e));
    }

    if (webSocket != null) {
      webSocket!.events.listen((wsEvent) {
        if (wsEvent is WSLocationReceived) {
          _eventsController.add(RTLSRecordedEvent(wsEvent.point));
        } else if (wsEvent is WSError) {
          _eventsController.add(RTLSErrorEvent(wsEvent.message));
        }
      });
    }
  }

  /// Stop all enabled capabilities.
  Future<void> stop() async {
    _locationSub?.cancel();
    if (locationTracker != null) await locationTracker!.stop();
    if (webSocket != null) await webSocket!.disconnect();
    if (offlineSync != null) await offlineSync!.stop();
  }

  Future<void> flushNow() async => await offlineSync?.flushNow();
  Future<void> pullNow() async => await offlineSync?.pullNow();

  void subscribeToUser(String userId) => webSocket?.subscribe(userId);
  void unsubscribeFromUser(String userId) => webSocket?.unsubscribe(userId);

  void dispose() {
    stop();
    webSocket?.dispose();
    _eventsController.close();
  }

  void _onLocationReceived(RTLSLocationPoint point) {
    _eventsController.add(RTLSRecordedEvent(point));

    // Store locally for offline sync
    offlineSync?.insert([point]);

    // Push in real-time via WebSocket
    webSocket?.pushLocation(point);
  }
}
