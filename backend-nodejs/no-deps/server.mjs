import http from "node:http";
import crypto from "node:crypto";
import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

// No-deps backend for RTLSyncKit.
// Implements:
// - GET  /health
// - GET  /v1/locations/latest?userId=...
// - POST /v1/locations/batch
// - WS   /v1/ws (subscribe -> broadcasts "location" envelopes)

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

await loadDotEnvIfPresent(path.join(__dirname, "..", ".env"));

const port = Number(process.env.PORT ?? 3000);
const host = String(process.env.HOST ?? "127.0.0.1");
const jwtSecret = (process.env.JWT_SECRET ?? "").trim();

/** @type {Map<string, any>} */
const latestByUser = new Map();
/** @type {Map<string, Set<import("node:net").Socket>>} */
const subscribersByUser = new Map();

const server = http.createServer(async (req, res) => {
  try {
    if (!req.url) return json(res, 400, { error: "bad request" });

    const url = new URL(req.url, `http://${req.headers.host ?? "localhost"}`);
    const pathname = url.pathname;

    if (req.method === "GET" && pathname === "/health") {
      return json(res, 200, { ok: true });
    }

    if (pathname === "/v1/locations/latest" && req.method === "GET") {
      requireAuth(req);
      const userId = String(url.searchParams.get("userId") ?? "").trim();
      if (!userId) return json(res, 400, { error: "userId is required" });
      const point = latestByUser.get(userId) ?? null;
      return json(res, 200, { point });
    }

    if (pathname === "/v1/locations/batch" && req.method === "POST") {
      requireAuth(req);

      const body = await readJson(req, 2 * 1024 * 1024);
      const points = Array.isArray(body?.points) ? body.points : null;
      if (!points) return json(res, 400, { error: "points[] is required" });

      /** @type {string[]} */
      const acceptedIds = [];
      /** @type {{id: string, reason: string}[]} */
      const rejected = [];

      for (const p of points) {
        const validation = validatePoint(p);
        if (!validation.ok) {
          rejected.push({ id: String(p?.id ?? ""), reason: validation.reason });
          continue;
        }

        acceptedIds.push(p.id);
        latestByUser.set(p.userId, p);
        broadcast(p.userId, JSON.stringify({ type: "location", point: p }));
      }

      return json(res, 200, { acceptedIds, rejected, serverTime: Date.now() });
    }

    return json(res, 404, { error: "not found" });
  } catch (e) {
    const msg = e?.message ? String(e.message) : "error";
    const code = msg.toLowerCase().includes("authorization") ? 401 : 500;
    return json(res, code, { error: msg });
  }
});

server.on("upgrade", (req, socket) => {
  try {
    const pathname = new URL(req.url ?? "", `http://${req.headers.host ?? "localhost"}`).pathname;
    if (pathname !== "/v1/ws") {
      socket.destroy();
      return;
    }

    requireAuth(req);

    const key = req.headers["sec-websocket-key"];
    const version = req.headers["sec-websocket-version"];
    if (!key || version !== "13") {
      socket.destroy();
      return;
    }

    const accept = crypto
      .createHash("sha1")
      .update(String(key) + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11", "utf8")
      .digest("base64");

    socket.write(
      [
        "HTTP/1.1 101 Switching Protocols",
        "Upgrade: websocket",
        "Connection: Upgrade",
        `Sec-WebSocket-Accept: ${accept}`,
        "\r\n"
      ].join("\r\n")
    );

    let subscribedUserId = null;
    let buffer = Buffer.alloc(0);

    socket.on("data", (chunk) => {
      buffer = Buffer.concat([buffer, chunk]);
      while (true) {
        const parsed = tryParseClientFrame(buffer);
        if (!parsed) return;
        buffer = buffer.subarray(parsed.bytesConsumed);

        if (parsed.opcode === 0x8) {
          // close
          socket.end();
          return;
        }
        if (parsed.opcode === 0x9) {
          // ping -> pong
          sendFrame(socket, 0xA, parsed.payload);
          continue;
        }
        if (parsed.opcode !== 0x1 && parsed.opcode !== 0x2) {
          // ignore non text/binary
          continue;
        }

        const text = parsed.opcode === 0x1 ? parsed.payload.toString("utf8") : parsed.payload.toString("utf8");
        let msg;
        try {
          msg = JSON.parse(text);
        } catch {
          sendFrame(socket, 0x1, Buffer.from(JSON.stringify({ type: "error", message: "invalid json" }), "utf8"));
          continue;
        }

        if (msg?.type !== "subscribe" || typeof msg?.userId !== "string" || !msg.userId.trim()) {
          sendFrame(
            socket,
            0x1,
            Buffer.from(JSON.stringify({ type: "error", message: "invalid subscribe message" }), "utf8")
          );
          continue;
        }

        if (subscribedUserId) {
          removeSubscriber(subscribedUserId, socket);
        }
        subscribedUserId = msg.userId.trim();
        addSubscriber(subscribedUserId, socket);
        sendFrame(socket, 0x1, Buffer.from(JSON.stringify({ type: "subscribed", userId: subscribedUserId }), "utf8"));
      }
    });

    socket.on("close", () => {
      if (subscribedUserId) removeSubscriber(subscribedUserId, socket);
    });
    socket.on("error", () => {
      if (subscribedUserId) removeSubscriber(subscribedUserId, socket);
    });
  } catch {
    try {
      socket.destroy();
    } catch {
      // ignore
    }
  }
});

server.on("error", (err) => {
  console.error(`Server error: ${err?.message ?? String(err)}`);
  process.exit(1);
});

server.listen(port, host, () => {
  console.log(`RTLS no-deps backend listening on http://${host}:${port}`);
  console.log(`WS endpoint: ws://${host}:${port}/v1/ws`);
  if (!jwtSecret) console.log("JWT_SECRET not set; auth is disabled");
});

// MARK: - Auth

function requireAuth(req) {
  if (!jwtSecret) return;

  const header = String(req.headers["authorization"] ?? "");
  const [kind, token] = header.split(" ");
  if (kind !== "Bearer" || !token) throw new Error("missing Authorization header");

  // Best-effort verification (HS256 only). If token isn't a JWT, reject.
  verifyJwtHS256(token, jwtSecret);
}

function verifyJwtHS256(token, secret) {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("invalid Authorization header");

  const [hB64, pB64, sigB64] = parts;
  let header;
  try {
    header = JSON.parse(Buffer.from(hB64, "base64url").toString("utf8"));
  } catch {
    throw new Error("invalid Authorization header");
  }
  if (header?.alg !== "HS256") throw new Error("invalid Authorization header");

  const expected = crypto.createHmac("sha256", secret).update(`${hB64}.${pB64}`).digest("base64url");
  if (!timingSafeEqualStr(expected, sigB64)) throw new Error("invalid Authorization header");

  let payload;
  try {
    payload = JSON.parse(Buffer.from(pB64, "base64url").toString("utf8"));
  } catch {
    throw new Error("invalid Authorization header");
  }

  const now = Math.floor(Date.now() / 1000);
  if (typeof payload?.nbf === "number" && now < payload.nbf) throw new Error("invalid Authorization header");
  if (typeof payload?.exp === "number" && now >= payload.exp) throw new Error("invalid Authorization header");
}

function timingSafeEqualStr(a, b) {
  const ab = Buffer.from(a);
  const bb = Buffer.from(b);
  if (ab.length !== bb.length) return false;
  return crypto.timingSafeEqual(ab, bb);
}

// MARK: - HTTP helpers

function json(res, status, obj) {
  const data = Buffer.from(JSON.stringify(obj), "utf8");
  res.statusCode = status;
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.setHeader("Content-Length", String(data.length));
  res.end(data);
}

function readJson(req, maxBytes) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let total = 0;
    req.on("data", (chunk) => {
      total += chunk.length;
      if (total > maxBytes) {
        reject(new Error("payload too large"));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      try {
        const raw = Buffer.concat(chunks).toString("utf8");
        resolve(raw ? JSON.parse(raw) : {});
      } catch (e) {
        reject(e);
      }
    });
    req.on("error", reject);
  });
}

function validatePoint(p) {
  if (!p || typeof p !== "object") return { ok: false, reason: "invalid point" };
  if (typeof p.id !== "string" || !p.id) return { ok: false, reason: "missing id" };
  if (typeof p.userId !== "string" || !p.userId) return { ok: false, reason: "missing userId" };
  if (typeof p.deviceId !== "string" || !p.deviceId) return { ok: false, reason: "missing deviceId" };
  if (typeof p.recordedAt !== "number") return { ok: false, reason: "missing recordedAt" };
  if (typeof p.lat !== "number" || typeof p.lng !== "number") return { ok: false, reason: "missing lat/lng" };
  return { ok: true };
}

// MARK: - WS helpers

function addSubscriber(userId, socket) {
  let set = subscribersByUser.get(userId);
  if (!set) {
    set = new Set();
    subscribersByUser.set(userId, set);
  }
  set.add(socket);
}

function removeSubscriber(userId, socket) {
  const set = subscribersByUser.get(userId);
  if (!set) return;
  set.delete(socket);
  if (set.size === 0) subscribersByUser.delete(userId);
}

function broadcast(userId, text) {
  const set = subscribersByUser.get(userId);
  if (!set) return;
  const payload = Buffer.from(text, "utf8");
  for (const socket of set) {
    if (socket.destroyed) continue;
    try {
      sendFrame(socket, 0x1, payload);
    } catch {
      // ignore
    }
  }
}

function sendFrame(socket, opcode, payload) {
  const finOpcode = 0x80 | (opcode & 0x0f);
  const len = payload.length;

  let header;
  if (len < 126) {
    header = Buffer.alloc(2);
    header[0] = finOpcode;
    header[1] = len;
  } else if (len < 65536) {
    header = Buffer.alloc(4);
    header[0] = finOpcode;
    header[1] = 126;
    header.writeUInt16BE(len, 2);
  } else {
    header = Buffer.alloc(10);
    header[0] = finOpcode;
    header[1] = 127;
    header.writeBigUInt64BE(BigInt(len), 2);
  }

  socket.write(Buffer.concat([header, payload]));
}

function tryParseClientFrame(buffer) {
  if (buffer.length < 2) return null;

  const b0 = buffer[0];
  const b1 = buffer[1];
  const fin = (b0 & 0x80) !== 0;
  const opcode = b0 & 0x0f;
  const masked = (b1 & 0x80) !== 0;
  let len = b1 & 0x7f;
  let offset = 2;

  if (!fin) {
    // For simplicity, ignore fragmented messages.
    return null;
  }

  if (len === 126) {
    if (buffer.length < offset + 2) return null;
    len = buffer.readUInt16BE(offset);
    offset += 2;
  } else if (len === 127) {
    if (buffer.length < offset + 8) return null;
    const big = buffer.readBigUInt64BE(offset);
    if (big > BigInt(Number.MAX_SAFE_INTEGER)) return null;
    len = Number(big);
    offset += 8;
  }

  if (!masked) {
    // Client-to-server frames must be masked.
    return null;
  }
  if (buffer.length < offset + 4) return null;
  const mask = buffer.subarray(offset, offset + 4);
  offset += 4;

  if (buffer.length < offset + len) return null;
  const payload = buffer.subarray(offset, offset + len);

  const out = Buffer.alloc(len);
  for (let i = 0; i < len; i++) {
    out[i] = payload[i] ^ mask[i % 4];
  }

  return { opcode, payload: out, bytesConsumed: offset + len };
}

// MARK: - .env

async function loadDotEnvIfPresent(filePath) {
  if (!existsSync(filePath)) return;
  const raw = await readFile(filePath, "utf8");
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq <= 0) continue;
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if (!key) continue;
    if (process.env[key] !== undefined) continue;
    if (
      (value.startsWith("\"") && value.endsWith("\"")) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    process.env[key] = value;
  }
}
