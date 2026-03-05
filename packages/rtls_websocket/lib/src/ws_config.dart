/// Configuration for the real-time WebSocket connection.
class RTLSWebSocketConfig {
  final String baseUrl;
  final String accessToken;
  final bool autoReconnect;
  final Duration reconnectBaseDelay;
  final Duration reconnectMaxDelay;
  final Duration pingInterval;

  const RTLSWebSocketConfig({
    required this.baseUrl,
    this.accessToken = '',
    this.autoReconnect = true,
    this.reconnectBaseDelay = const Duration(seconds: 1),
    this.reconnectMaxDelay = const Duration(seconds: 30),
    this.pingInterval = const Duration(seconds: 30),
  });
}
