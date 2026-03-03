import { useState, useCallback, useMemo } from "react";
import { useLocationStream } from "./useLocationStream";
import { LocationMap } from "./components/LocationMap";
import type { LocationPoint } from "./types";
import "./App.css";

const DEFAULT_BASE_URL = "http://192.168.0.103:3000";

function formatTime(ms: number) {
  return new Date(ms).toLocaleTimeString();
}

function LocationRow({ point }: { point: LocationPoint }) {
  return (
    <tr>
      <td>{point.userId}</td>
      <td>{point.lat.toFixed(5)}, {point.lng.toFixed(5)}</td>
      <td>{point.speed != null ? `${(point.speed * 3.6).toFixed(1)} km/h` : "—"}</td>
      <td>{formatTime(point.recordedAt)}</td>
    </tr>
  );
}

export default function App() {
  const [baseURL, setBaseURL] = useState(DEFAULT_BASE_URL);
  const [userInput, setUserInput] = useState("");
  const [userIds, setUserIds] = useState<string[]>([]);

  const addUser = useCallback(() => {
    const id = userInput.trim();
    if (id && !userIds.includes(id)) {
      setUserIds((prev) => [...prev, id]);
      setUserInput("");
    }
  }, [userInput, userIds]);

  const removeUser = useCallback((id: string) => {
    setUserIds((prev) => prev.filter((u) => u !== id));
  }, []);

  const { pathByUser, latestByUser, status, error } = useLocationStream(baseURL, userIds);
  const allPoints = useMemo(() => {
    const byKey = new Map<string, LocationPoint>();
    Object.values(pathByUser).forEach((path) =>
      path.forEach((p) => {
        const key = p.id ?? `${p.userId}-${p.recordedAt}`;
        byKey.set(key, p);
      })
    );
    return Array.from(byKey.values())
      .sort((a, b) => b.recordedAt - a.recordedAt)
      .slice(0, 100);
  }, [pathByUser]);

  return (
    <div className="app">
      <header className="header">
        <h1>RTLS live map</h1>
        <p className="subtitle">Real-time location updates from the backend</p>
      </header>

      <section className="config">
        <div className="field">
          <label>Backend URL</label>
          <input
            type="url"
            value={baseURL}
            onChange={(e) => setBaseURL(e.target.value)}
            placeholder="http://192.168.0.103:3000"
          />
        </div>
        <div className="field">
          <label>Subscribe to user ID</label>
          <div className="row">
            <input
              type="text"
              value={userInput}
              onChange={(e) => setUserInput(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && addUser()}
              placeholder="e.g. user_123 (must match iOS app)"
            />
            <button type="button" onClick={addUser}>
              Add
            </button>
          </div>
        </div>
        {userIds.length > 0 && (
          <div className="chips">
            {userIds.map((id) => (
              <span key={id} className="chip">
                {id}
                <button type="button" onClick={() => removeUser(id)} aria-label={`Remove ${id}`}>
                  ×
                </button>
              </span>
            ))}
          </div>
        )}
        <div className="status" data-status={status}>
          {status === "connecting" && "Connecting…"}
          {status === "connected" && "Connected"}
          {status === "disconnected" && (userIds.length ? "Disconnected" : "Add a user ID to connect")}
          {status === "error" && (error || "Error")}
        </div>
      </section>

      <section className="content">
        <div className="list-panel">
          <h2>All positions (newest first)</h2>
          {allPoints.length === 0 ? (
            <p className="muted">
            No locations yet. Add the <strong>exact same User ID</strong> as in the iOS app (e.g. user_123), 
            ensure the app is sending to the same Backend URL, then wait a few seconds.
          </p>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>User</th>
                  <th>Lat, Lng</th>
                  <th>Speed</th>
                  <th>Time</th>
                </tr>
              </thead>
              <tbody>
                {allPoints.map((p) => (
                  <LocationRow key={p.id ?? `${p.userId}-${p.recordedAt}`} point={p} />
                ))}
              </tbody>
            </table>
          )}
        </div>
        <div className="map-panel">
          <LocationMap pathByUser={pathByUser} latestByUser={latestByUser} />
        </div>
      </section>
    </div>
  );
}
