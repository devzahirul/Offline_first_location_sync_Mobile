export type LocationPoint = {
  id: string;
  userId: string;
  deviceId: string;
  recordedAt: number; // ms since epoch
  lat: number;
  lng: number;
  horizontalAccuracy?: number | null;
  verticalAccuracy?: number | null;
  altitude?: number | null;
  speed?: number | null;
  course?: number | null;
};

export type LocationUploadBatch = {
  schemaVersion: number;
  points: LocationPoint[];
};

export type LocationUploadResult = {
  acceptedIds: string[];
  rejected: { id: string; reason: string }[];
  serverTime?: number;
};

export type WsSubscribeMessage = {
  type: "subscribe";
  userId: string;
};

export type WsLocationEnvelope = {
  type: "location";
  point: LocationPoint;
};

// WebSocket v2 Protocol Messages

export interface WsAuthMessage {
  type: "auth";
  token: string;
}

export interface WsLocationPushMessage {
  type: "location.push";
  reqId: string;
  point: LocationPoint;
}

export interface WsLocationBatchMessage {
  type: "location.batch";
  reqId: string;
  points: LocationPoint[];
}

export interface WsUnsubscribeMessage {
  type: "unsubscribe";
  userId: string;
}

export interface WsSyncPullMessage {
  type: "sync.pull";
  reqId: string;
  cursor?: string;
  limit?: number;
}

export interface WsPingMessage {
  type: "ping";
}

export type WsClientMessage =
  | WsAuthMessage
  | WsLocationPushMessage
  | WsLocationBatchMessage
  | WsSubscribeMessage
  | WsUnsubscribeMessage
  | WsSyncPullMessage
  | WsPingMessage;

// Server -> Client
export interface WsAuthOkMessage {
  type: "auth.ok";
}

export interface WsLocationAckMessage {
  type: "location.ack";
  reqId: string;
  pointId: string;
  status: "accepted" | "rejected";
}

export interface WsLocationBatchAckMessage {
  type: "location.batch_ack";
  reqId: string;
  acceptedIds: string[];
  rejected: { id: string; reason: string }[];
}

export interface WsLocationUpdateMessage {
  type: "location.update";
  point: LocationPoint;
}

export interface WsSyncResultMessage {
  type: "sync.result";
  reqId: string;
  points: LocationPoint[];
  cursor?: string;
  serverTime: number;
}

export interface WsSubscribedMessage {
  type: "subscribed";
  userId: string;
}

export interface WsPongMessage {
  type: "pong";
}

export interface WsErrorMessage {
  type: "error";
  message: string;
}

// Pull API response
export interface PullResponse {
  points: LocationPoint[];
  nextCursor?: string;
  serverTime: number;
}

