import { useEffect, useRef, useState } from "react";
import type { LocationPoint } from "./types";

export type ConnectionStatus = "disconnected" | "connecting" | "connected" | "error";

function wsUrl(base: string): string {
  const url = new URL(base);
  url.protocol = url.protocol === "https:" ? "wss:" : "ws:";
  return `${url.origin}${url.pathname.replace(/\/$/, "")}/v1/ws`;
}

const POLL_INTERVAL_MS = 2000;
const MAX_POINTS_PER_USER = 500;

export function useLocationStream(baseURL: string, userIds: string[]) {
  const [pathByUser, setPathByUser] = useState<Record<string, LocationPoint[]>>({});
  const [status, setStatus] = useState<ConnectionStatus>("disconnected");
  const [error, setError] = useState<string | null>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const subscribedRef = useRef<Set<string>>(new Set());
  const baseURLRef = useRef(baseURL);
  const userIdsRef = useRef(userIds);
  baseURLRef.current = baseURL;
  userIdsRef.current = userIds;

  const addPoint = (point: LocationPoint | null) => {
    if (!point || point.userId == null) return;
    setPathByUser((prev) => {
      const path = prev[point.userId] ?? [];
      const next = [...path, point].sort((a, b) => a.recordedAt - b.recordedAt);
      const trimmed = next.length > MAX_POINTS_PER_USER ? next.slice(-MAX_POINTS_PER_USER) : next;
      return { ...prev, [point.userId]: trimmed };
    });
  };

  // Poll GET /v1/locations/latest for each userId so we show data even if WS misses
  useEffect(() => {
    if (!baseURL.trim() || userIds.length === 0) return;
    const ids = userIds.map((id) => id.trim()).filter(Boolean);
    if (ids.length === 0) return;

    const poll = async () => {
      for (const userId of ids) {
        try {
          const u = `${baseURLRef.current.replace(/\/$/, "")}/v1/locations/latest?userId=${encodeURIComponent(userId)}`;
          const res = await fetch(u);
          if (res.ok) {
            const json = await res.json();
            if (json.point) addPoint(json.point);
          }
        } catch {
          // ignore
        }
      }
    };

    poll();
    const interval = setInterval(poll, POLL_INTERVAL_MS);
    return () => clearInterval(interval);
  }, [baseURL, userIds.join(",")]);

  useEffect(() => {
    if (!baseURL.trim() || userIds.length === 0) {
      setStatus("disconnected");
      if (wsRef.current) {
        wsRef.current.close();
        wsRef.current = null;
      }
      return;
    }

    const url = wsUrl(baseURL);
    setStatus("connecting");
    setError(null);
    const ws = new WebSocket(url);
    wsRef.current = ws;

    ws.onopen = () => {
      setStatus("connected");
      userIds.forEach((userId) => {
        if (userId.trim()) {
          ws.send(JSON.stringify({ type: "subscribe", userId: userId.trim() }));
          subscribedRef.current.add(userId.trim());
        }
      });
    };

    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data as string);
        if (data.type === "location" && data.point) {
          addPoint(data.point as LocationPoint);
        }
      } catch {
        // ignore parse errors
      }
    };

    ws.onerror = () => setError("WebSocket error");
    ws.onclose = () => {
      setStatus("disconnected");
      wsRef.current = null;
      subscribedRef.current.clear();
    };

    return () => {
      ws.close();
      wsRef.current = null;
      subscribedRef.current.clear();
    };
  }, [baseURL, userIds.join(",")]);

  // When userIds change, send new subscribe messages (if we're connected)
  useEffect(() => {
    const ws = wsRef.current;
    if (ws?.readyState !== WebSocket.OPEN || !baseURL.trim()) return;

    const current = new Set(userIds.map((id) => id.trim()).filter(Boolean));
    current.forEach((userId) => {
      if (!subscribedRef.current.has(userId)) {
        ws.send(JSON.stringify({ type: "subscribe", userId }));
        subscribedRef.current.add(userId);
      }
    });
  }, [baseURL, userIds]);

  const latestByUser = Object.fromEntries(
    Object.entries(pathByUser)
      .filter(([, path]) => path.length > 0)
      .map(([userId, path]) => [userId, path[path.length - 1]])
  );

  return { pathByUser, latestByUser, status, error };
}
