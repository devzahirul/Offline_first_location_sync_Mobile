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

