import http from "node:http";
import os from "node:os";
import express from "express";

function getLanIp(): string | null {
  const ifaces = os.networkInterfaces();
  for (const a of Object.values(ifaces)) {
    if (!a) continue;
    for (const i of a) {
      if (i.family === "IPv4" && !i.internal) return i.address;
    }
  }
  return null;
}
import WebSocket, { WebSocketServer } from "ws";
import { UploadBatchSchema, WsSubscribeSchema } from "./validation.js";
import type { LocationUploadResult, WsLocationEnvelope } from "./types.js";
import { createDB, insertPoints, latestPointForUser } from "./db.js";
import { requireAuth } from "./auth.js";
import { WsHub } from "./wsHub.js";
import { loadDotEnvIfPresent } from "./env.js";

await loadDotEnvIfPresent();

const app = express();
app.use((req, res, next) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
  if (req.method === "OPTIONS") return res.sendStatus(204);
  next();
});
app.use(express.json({ limit: "2mb" }));

const hub = new WsHub();
const latestByUser = new Map<string, any>();
const db = await createDB();

app.get("/", (_req, res) =>
  res.json({
    name: "RTLS backend",
    health: "/health",
    api: "/v1/locations/latest, POST /v1/locations/batch",
    ws: "ws://<this-host>/v1/ws",
  })
);
app.get("/health", (_req, res) => res.json({ ok: true }));

app.get("/v1/locations/latest", async (req, res) => {
  const userId = String(req.query.userId ?? "");
  if (!userId) return res.status(400).json({ error: "userId is required" });

  try {
    requireAuth(req);
    const p = db ? await latestPointForUser(db, userId) : (latestByUser.get(userId) ?? null);
    res.json({ point: p });
  } catch (e: any) {
    res.status(401).json({ error: e?.message ?? "unauthorized" });
  }
});

app.post("/v1/locations/batch", async (req, res) => {
  try {
    requireAuth(req);
    const batch = UploadBatchSchema.parse(req.body);

    if (db) await insertPoints(db, batch.points);

    for (const p of batch.points) {
      latestByUser.set(p.userId, p);
      const env: WsLocationEnvelope = { type: "location", point: p };
      hub.broadcast(p.userId, JSON.stringify(env));
    }

    const out: LocationUploadResult = {
      acceptedIds: batch.points.map((p) => p.id),
      rejected: [],
      serverTime: Date.now()
    };
    res.json(out);
  } catch (e: any) {
    if (e?.name === "ZodError") return res.status(400).json({ error: e.issues });
    const msg = e?.message ?? "error";
    const code = msg.includes("Authorization") ? 401 : 500;
    res.status(code).json({ error: msg });
  }
});

const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: "/v1/ws" });

wss.on("connection", (socket, req) => {
  const auth = req.headers["authorization"]?.toString();
  const secret = process.env.JWT_SECRET;
  if (secret && !auth) {
    socket.close(1008, "missing Authorization header");
    return;
  }

  let subscribedUserId: string | null = null;

  socket.on("message", (data) => {
    try {
      const raw = JSON.parse(data.toString("utf8"));
      const msg = WsSubscribeSchema.parse(raw);
      subscribedUserId = msg.userId;
      hub.addSubscriber(subscribedUserId, socket);
      socket.send(JSON.stringify({ type: "subscribed", userId: subscribedUserId }));
    } catch {
      socket.send(JSON.stringify({ type: "error", message: "invalid subscribe message" }));
    }
  });

  socket.on("close", () => {
    if (subscribedUserId) hub.removeSubscriber(subscribedUserId, socket);
  });
});

const port = Number(process.env.PORT ?? 3000);
const host = String(process.env.HOST ?? "0.0.0.0");
server.listen(port, host, () => {
  console.log(`RTLS backend listening on http://${host}:${port}`);
  console.log(`WS endpoint: ws://${host}:${port}/v1/ws`);
  if (host === "0.0.0.0") {
    const lan = getLanIp();
    if (lan) console.log(`LAN URL: http://${lan}:${port}/ (use from phone/other devices on same Wi‑Fi)`);
    else console.log("Tip: use your Mac's LAN IP (e.g. http://192.168.x.x:3000) from your iPhone");
  }
  if (!process.env.JWT_SECRET) console.log("JWT_SECRET not set; auth is disabled");
  if (!process.env.DATABASE_URL) console.log("DATABASE_URL not set; using in-memory latest-point only");
});
