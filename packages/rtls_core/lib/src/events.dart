import 'models.dart';

/// Base event type for all RTLS events.
sealed class RTLSEvent {
  const RTLSEvent();
}

class RTLSRecordedEvent extends RTLSEvent {
  final RTLSLocationPoint point;
  const RTLSRecordedEvent(this.point);
}

class RTLSSyncUploadSucceeded extends RTLSEvent {
  final int accepted;
  final int rejected;
  const RTLSSyncUploadSucceeded({required this.accepted, required this.rejected});
}

class RTLSSyncUploadFailed extends RTLSEvent {
  final String message;
  const RTLSSyncUploadFailed(this.message);
}

class RTLSSyncPullSucceeded extends RTLSEvent {
  final int count;
  const RTLSSyncPullSucceeded(this.count);
}

class RTLSSyncPullFailed extends RTLSEvent {
  final String message;
  const RTLSSyncPullFailed(this.message);
}

class RTLSTrackingStarted extends RTLSEvent {
  const RTLSTrackingStarted();
}

class RTLSTrackingStopped extends RTLSEvent {
  const RTLSTrackingStopped();
}

class RTLSErrorEvent extends RTLSEvent {
  final String message;
  const RTLSErrorEvent(this.message);
}

class RTLSAuthorizationChanged extends RTLSEvent {
  final String status;
  const RTLSAuthorizationChanged(this.status);
}
