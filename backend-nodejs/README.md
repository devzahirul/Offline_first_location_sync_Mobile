# RTLSyncKit Backend (Node.js)

Implements:

- `POST /v1/locations/batch` (matches `URLSessionLocationSyncAPI`)
- `GET /v1/locations/latest?userId=...`
- WebSocket `ws(s)://<host>/v1/ws` (matches `WebSocketLocationSubscriber`)

## Run

1. `cd backend-nodejs`
2. `npm i`
3. (Optional) `cp .env.example .env` and edit values
   - If `.env` is missing, the server runs with auth disabled and in-memory storage.
4. `npm run dev`

### Physical iPhone over Wi‑Fi (LAN)

1. Make sure your Mac and iPhone are on the same Wi‑Fi.
2. Set `HOST=0.0.0.0` (and `PORT=3000`) in `.env`.
3. Find your Mac's IP:
   - Wi‑Fi: `ipconfig getifaddr en0`
4. In the iOS demo app, set Base URL to `http://<YOUR_MAC_IP>:3000` (not `localhost`).

If `DATABASE_URL` is set, it will auto-create the table from `sql/001_init.sql`.
