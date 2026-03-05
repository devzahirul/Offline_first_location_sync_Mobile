import 'package:rtls_core/rtls_core.dart';

sealed class RTLSWebSocketEvent {
  const RTLSWebSocketEvent();
}

class WSConnected extends RTLSWebSocketEvent {
  const WSConnected();
}

class WSDisconnected extends RTLSWebSocketEvent {
  const WSDisconnected();
}

class WSReconnecting extends RTLSWebSocketEvent {
  final int attempt;
  final Duration delay;
  const WSReconnecting({required this.attempt, required this.delay});
}

class WSLocationReceived extends RTLSWebSocketEvent {
  final RTLSLocationPoint point;
  const WSLocationReceived(this.point);
}

class WSPushAcknowledged extends RTLSWebSocketEvent {
  final String reqId;
  final String status;
  const WSPushAcknowledged({required this.reqId, required this.status});
}

class WSBatchAcknowledged extends RTLSWebSocketEvent {
  final String reqId;
  final List<String> acceptedIds;
  const WSBatchAcknowledged({required this.reqId, required this.acceptedIds});
}

class WSSubscribed extends RTLSWebSocketEvent {
  final String userId;
  const WSSubscribed(this.userId);
}

class WSError extends RTLSWebSocketEvent {
  final String message;
  const WSError(this.message);
}
