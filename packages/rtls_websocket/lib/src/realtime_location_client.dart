import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:rtls_core/rtls_core.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'ws_config.dart';
import 'ws_events.dart';

/// Real-time bidirectional WebSocket client for location streaming.
/// Independently usable — no offline sync or native location tracking required.
///
/// Usage:
/// ```dart
/// final ws = RTLSRealTimeClient(config: RTLSWebSocketConfig(baseUrl: 'ws://...'));
/// await ws.connect();
/// ws.pushLocation(point);
/// ws.subscribe('other-user');
/// ws.events.listen((event) { ... });
/// ```
class RTLSRealTimeClient {
  final RTLSWebSocketConfig config;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _running = false;
  int _reconnectAttempt = 0;
  final Set<String> _subscribedUserIds = {};

  final _eventsController = StreamController<RTLSWebSocketEvent>.broadcast();
  final _locationsController = StreamController<RTLSLocationPoint>.broadcast();

  /// Stream of WebSocket events (connected, disconnected, locations, acks, errors).
  Stream<RTLSWebSocketEvent> get events => _eventsController.stream;

  /// Stream of incoming location points from subscribed users.
  Stream<RTLSLocationPoint> get incomingLocations => _locationsController.stream;

  bool get isConnected => _channel != null;

  RTLSRealTimeClient({required this.config});

  Future<void> connect() async {
    _running = true;
    _reconnectAttempt = 0;
    await _doConnect();
  }

  Future<void> disconnect() async {
    _running = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _eventsController.add(const WSDisconnected());
  }

  void pushLocation(RTLSLocationPoint point) {
    _send({
      'type': 'location.push',
      'reqId': _uuid(),
      'point': point.toMap(),
    });
  }

  void pushBatch(List<RTLSLocationPoint> points) {
    _send({
      'type': 'location.batch',
      'reqId': _uuid(),
      'points': points.map((p) => p.toMap()).toList(),
    });
  }

  void subscribe(String userId) {
    _subscribedUserIds.add(userId);
    _send({'type': 'subscribe', 'userId': userId});
  }

  void unsubscribe(String userId) {
    _subscribedUserIds.remove(userId);
    _send({'type': 'unsubscribe', 'userId': userId});
  }

  void dispose() {
    disconnect();
    _eventsController.close();
    _locationsController.close();
  }

  // Private

  Future<void> _doConnect() async {
    try {
      final wsUrl = _buildWsUrl(config.baseUrl);
      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: null,
      );

      await _channel!.ready;

      _send({'type': 'auth', 'token': config.accessToken});

      _reconnectAttempt = 0;
      _eventsController.add(const WSConnected());

      for (final uid in _subscribedUserIds) {
        _send({'type': 'subscribe', 'userId': uid});
      }

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          _eventsController.add(WSError(error.toString()));
          if (_running && config.autoReconnect) _scheduleReconnect();
        },
        onDone: () {
          _eventsController.add(const WSDisconnected());
          if (_running && config.autoReconnect) _scheduleReconnect();
        },
      );

      _startPing();
    } catch (e) {
      _eventsController.add(WSError(e.toString()));
      if (_running && config.autoReconnect) _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = map['type'] as String?;

      switch (type) {
        case 'auth.ok':
          break;
        case 'location.ack':
          _eventsController.add(WSPushAcknowledged(
            reqId: map['reqId'] as String? ?? '',
            status: map['status'] as String? ?? 'accepted',
          ));
        case 'location.batch_ack':
          _eventsController.add(WSBatchAcknowledged(
            reqId: map['reqId'] as String? ?? '',
            acceptedIds: List<String>.from(map['acceptedIds'] ?? []),
          ));
        case 'location.update' || 'location':
          if (map['point'] != null) {
            final point = RTLSLocationPoint.fromMap(
              Map<String, dynamic>.from(map['point'] as Map),
            );
            _locationsController.add(point);
            _eventsController.add(WSLocationReceived(point));
          }
        case 'subscribed':
          _eventsController.add(WSSubscribed(map['userId'] as String? ?? ''));
        case 'pong':
          break;
        case 'error':
          _eventsController.add(WSError(map['message'] as String? ?? 'Server error'));
        default:
          break;
      }
    } catch (e) {
      _eventsController.add(WSError('Failed to parse message: $e'));
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(config.pingInterval, (_) {
      _send({'type': 'ping'});
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempt++;
    final exp = pow(2, min(_reconnectAttempt - 1, 10)).toDouble();
    final delayMs = min(
      config.reconnectMaxDelay.inMilliseconds,
      (config.reconnectBaseDelay.inMilliseconds * exp).toInt(),
    );
    final delay = Duration(milliseconds: delayMs);
    _eventsController.add(WSReconnecting(attempt: _reconnectAttempt, delay: delay));
    _reconnectTimer = Timer(delay, () {
      if (_running) _doConnect();
    });
  }

  void _send(Map<String, dynamic> msg) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode(msg));
  }

  String _buildWsUrl(String baseUrl) {
    var url = baseUrl.trimRight();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (!url.endsWith('/v1/ws')) url = '$url/v1/ws';
    url = url.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    if (!url.startsWith('ws')) url = 'ws://$url';
    return url;
  }

  String _uuid() {
    final r = Random();
    return '${_hex(r, 8)}-${_hex(r, 4)}-4${_hex(r, 3)}-${_hex(r, 4)}-${_hex(r, 12)}';
  }

  String _hex(Random r, int count) =>
      List.generate(count, (_) => r.nextInt(16).toRadixString(16)).join();
}
