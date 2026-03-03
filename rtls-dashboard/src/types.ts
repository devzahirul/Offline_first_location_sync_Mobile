export interface LocationPoint {
  id: string;
  userId: string;
  deviceId: string;
  recordedAt: number;
  lat: number;
  lng: number;
  horizontalAccuracy?: number | null;
  verticalAccuracy?: number | null;
  altitude?: number | null;
  speed?: number | null;
  course?: number | null;
}

export interface WsLocationEnvelope {
  type: "location";
  point: LocationPoint;
}
