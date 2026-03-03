import { useMemo } from "react";
import { MapContainer, TileLayer, Marker, Popup, Polyline } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import type { LocationPoint } from "../types";

const colors = ["#2563eb", "#dc2626", "#16a34a", "#ca8a04", "#9333ea"];
function markerIcon(index: number) {
  return L.divIcon({
    className: "custom-marker",
    html: `<span style="
      background: ${colors[index % colors.length]};
      width: 24px;
      height: 24px;
      border-radius: 50%;
      border: 2px solid white;
      box-shadow: 0 1px 3px rgba(0,0,0,0.4);
      display: block;
    "></span>`,
    iconSize: [24, 24],
    iconAnchor: [12, 12],
  });
}

interface LocationMapProps {
  pathByUser: Record<string, LocationPoint[]>;
  latestByUser: Record<string, LocationPoint>;
}

export function LocationMap({ pathByUser, latestByUser }: LocationMapProps) {
  const paths = useMemo(
    () =>
      Object.entries(pathByUser)
        .map(([userId, path]) => ({
          userId,
          latlngs: path
            .filter((p) => p?.lat != null && p?.lng != null)
            .map((p) => [p.lat, p.lng] as [number, number]),
        }))
        .filter((p) => p.latlngs.length > 0),
    [pathByUser]
  );
  const latestPoints = useMemo(
    () => Object.values(latestByUser).filter((p) => p?.lat != null && p?.lng != null),
    [latestByUser]
  );
  const userIds = useMemo(() => Object.keys(pathByUser), [pathByUser]);

  if (latestPoints.length === 0) {
    return (
      <div className="map-placeholder">
        <p>Subscribe to a user ID above. When locations arrive, they’ll appear on the map.</p>
      </div>
    );
  }

  const center: [number, number] =
    latestPoints.length === 1
      ? [latestPoints[0].lat, latestPoints[0].lng]
      : [
          latestPoints.reduce((s, p) => s + p.lat, 0) / latestPoints.length,
          latestPoints.reduce((s, p) => s + p.lng, 0) / latestPoints.length,
        ];

  return (
    <MapContainer
      center={center}
      zoom={14}
      className="location-map"
      scrollWheelZoom
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      {paths.map(({ userId, latlngs }, i) => (
        <Polyline
          key={userId}
          positions={latlngs}
          pathOptions={{ color: colors[i % colors.length], weight: 4, opacity: 0.8 }}
        />
      ))}
      {latestPoints.map((point) => (
        <Marker
          key={point.id}
          position={[point.lat, point.lng]}
          icon={markerIcon(userIds.indexOf(point.userId))}
        >
          <Popup>
            <strong>{point.userId}</strong>
            <br />
            {new Date(point.recordedAt).toLocaleString()}
            <br />
            <small>
              {point.lat.toFixed(5)}, {point.lng.toFixed(5)}
              {point.speed != null && ` · ${(point.speed * 3.6).toFixed(1)} km/h`}
            </small>
          </Popup>
        </Marker>
      ))}
    </MapContainer>
  );
}
