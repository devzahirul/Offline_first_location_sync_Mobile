# RTLS Backend (Node.js)

REST and WebSocket API for **Real-Time Location Sync**. When you run only this service (`npm run dev` in this folder), only this directory’s code is used. The rest of the repo (Swift package, Android, React Native, Flutter, dashboard) is not loaded by Node. Single service: batch upload of location points, latest-point query, and live stream over WebSocket. Used by all clients (iOS, Android, Flutter, React Native) under a single contract.

---

## Overview

- **Stack:** Node.js, Express, TypeScript. Optional PostgreSQL for persistence; in-memory fallback when `DATABASE_URL` is unset. Authentication via JWT when `JWT_SECRET` is set.
- **API surface:** Four entry points — `POST /v1/locations/batch`, `GET /v1/locations/latest`, `GET /v1/locations/pull`, WebSocket `/v1/ws` (v2 protocol). CORS enabled for dashboard and mobile clients.
- **Validation:** Request bodies and WebSocket messages validated with [Zod](https://github.com/colinhacks/zod); invalid payloads return 400 with error details.

---

## API specification

### Health and discovery

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/` | Service info: name, health path, API and WebSocket endpoints |
| `GET` | `/health` | Health check: `{ "ok": true }` |

### REST (JSON)

#### `POST /v1/locations/batch`

Upload a batch of location points. Requires `Authorization: Bearer <token>` when `JWT_SECRET` is set.

**Request body (Zod schema):**

```ts
{
  schemaVersion: number;  // integer >= 1
  points: Array<{
    id: string;           // UUID
    userId: string;       // non-empty
    deviceId: string;    // non-empty
    recordedAt: number;  // integer, ms since epoch, >= 0
    lat: number;
    lng: number;
    horizontalAccuracy?: number | null;
    verticalAccuracy?: number | null;
    altitude?: number | null;
    speed?: number | null;
    course?: number | null;
  }>;
}
```

**Response:** `200 OK`

```ts
{
  acceptedIds: string[];   // ids of accepted points
  rejected: Array<{ id: string; reason: string }>;
  serverTime?: number;      // server timestamp (ms)
}
```

- If PostgreSQL is configured, points are inserted (table created from `sql/001_init.sql` if needed). In-memory mode updates an internal map and broadcasts to WebSocket subscribers.
- Each point is broadcast as `{ type: "location", point }` to clients subscribed to that `userId`.

**Errors:** `400` (validation), `401` (missing or invalid JWT when auth is enabled).

---

#### `GET /v1/locations/latest?userId=<userId>`

Return the most recently stored point for a user. Requires `Authorization: Bearer <token>` when `JWT_SECRET` is set.

**Query:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `userId` | Yes | User identifier |

**Response:** `200 OK`

```ts
{ "point": LocationPoint | null }
```

**Errors:** `400` (missing `userId`), `401` (auth).

---

#### `GET /v1/locations/pull?userId=&cursor=&limit=`

Cursor-based pagination for bidirectional sync. Clients call this to pull points they may have missed (e.g. after being offline). Requires `Authorization: Bearer <token>` when `JWT_SECRET` is set.

**Query:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `userId` | Yes | -- | User identifier |
| `cursor` | No | -- | ISO 8601 timestamp; returns points recorded after this time |
| `limit` | No | `100` | Max points per page (1-500) |

**Response:** `200 OK`

```ts
{
  points: LocationPoint[];  // ordered by recorded_at ASC
  nextCursor?: string;      // ISO 8601; present when more pages exist
  serverTime: number;       // server timestamp (ms)
}
```

When `nextCursor` is present, the client should make another request with `cursor=<nextCursor>` to fetch the next page. When absent, all available points have been returned.

**Errors:** `400` (invalid parameters), `401` (auth).

---

### WebSocket v2 Protocol: `/v1/ws`

JSON messages over raw WebSocket (no STOMP/SockJS). Supports authentication, bidirectional location push, subscriptions, sync pull, and heartbeat. Backward-compatible with v1 subscribe messages.

#### Connection Flow

1. Connect to `ws://<host>/v1/ws`
2. If `JWT_SECRET` is set, send `auth` message before any other operation
3. Server responds with `auth.ok` on success or closes the connection on failure

#### Client -> Server Messages

**`auth`** -- authenticate the connection:

```json
{ "type": "auth", "token": "<jwt>" }
```

**`location.push`** -- push a single location point:

```json
{
  "type": "location.push",
  "reqId": "uuid",
  "point": {
    "id": "uuid", "userId": "user-1", "deviceId": "device-1",
    "recordedAt": 1709500000000, "lat": 37.7749, "lng": -122.4194
  }
}
```

**`location.batch`** -- push multiple points:

```json
{
  "type": "location.batch",
  "reqId": "uuid",
  "points": [ { "id": "...", "userId": "...", ... } ]
}
```

**`subscribe`** -- subscribe to live updates for a user:

```json
{ "type": "subscribe", "userId": "user-1" }
```

**`unsubscribe`** -- unsubscribe from a user:

```json
{ "type": "unsubscribe", "userId": "user-1" }
```

**`sync.pull`** -- pull missed points (cursor-based):

```json
{ "type": "sync.pull", "reqId": "uuid", "cursor": "2024-01-01T00:00:00.000Z", "limit": 100 }
```

**`ping`** -- heartbeat:

```json
{ "type": "ping" }
```

#### Server -> Client Messages

| Type | Key Fields | Description |
|------|------------|-------------|
| `auth.ok` | -- | Authentication succeeded |
| `location.ack` | `reqId`, `pointId`, `status` | Acknowledgment for `location.push` (`status`: `"accepted"` or `"rejected"`) |
| `location.batch_ack` | `reqId`, `acceptedIds[]`, `rejected[]` | Acknowledgment for `location.batch` |
| `location.update` | `point` | Live location broadcast to subscribers |
| `sync.result` | `reqId`, `points[]`, `cursor?`, `serverTime` | Response to `sync.pull`; `cursor` present when more pages exist |
| `subscribed` | `userId` | Subscription confirmed |
| `unsubscribed` | `userId` | Unsubscription confirmed |
| `pong` | -- | Heartbeat response |
| `error` | `message` | Error description |

Used by mobile clients for real-time push and by the web dashboard for live map updates.

---

## Environment configuration

| Variable | Required | Description |
|----------|----------|-------------|
| `HOST` | No | Bind address (default from Express). Use `0.0.0.0` for LAN access (e.g. physical device). |
| `PORT` | No | Port (e.g. `3000`). |
| `DATABASE_URL` | No | PostgreSQL connection string. If unset, storage is in-memory (no persistence across restarts). |
| `JWT_SECRET` | No | Secret for JWT verification. If unset or empty, all authenticated endpoints accept any request (no auth). **Set in production.** |

Example `.env` (copy from `.env.example`):

```bash
HOST=0.0.0.0
PORT=3000
DATABASE_URL=postgres://postgres:postgres@localhost:5432/rtls
JWT_SECRET=your-secret-here
```

---

## Run

```bash
cd backend-nodejs
npm install
cp .env.example .env   # edit as needed
npm run dev            # tsx watch; use npm run build && npm start for production
```

- **Without `.env`:** Server starts with auth disabled and in-memory storage; suitable for local/demo.
- **With `DATABASE_URL`:** Table is auto-created from `sql/001_init.sql` if it does not exist.

### Physical device on LAN

1. Ensure Mac and device are on the same network.
2. Set `HOST=0.0.0.0` and `PORT=3000` in `.env`.
3. Get host IP, e.g. `ipconfig getifaddr en0`.
4. In the mobile app, set base URL to `http://<HOST_IP>:3000` (not `localhost`).
5. Android emulator: use `http://10.0.2.2:3000` to reach host loopback.

---

## Project layout

| Path | Purpose |
|------|----------|
| `src/index.ts` | Express app, routes, WebSocket server, CORS |
| `src/auth.ts` | JWT extraction and verification (`requireAuth`) |
| `src/validation.ts` | Zod schemas for batch and WebSocket |
| `src/types.ts` | TypeScript types for points, batch, result, WS envelopes |
| `src/db.ts` | PostgreSQL client, table init, insert, latest-by-user, cursor-based pull |
| `src/wsHub.ts` | WebSocket hub (subscribe by userId, broadcast) |
| `src/env.ts` | Minimal `.env` loader (no dotenv dependency) |
| `sql/001_init.sql` | Table DDL for location points |

---

## Security notes

- **Production:** Set `JWT_SECRET` and issue short-lived tokens; do not disable auth in production.
- **CORS:** Currently permissive (`*`); restrict origins for production.
- **Input:** All batch and WS payloads are validated; invalid input is rejected with 400.

---

## License

See repository [LICENSE](../LICENSE).
