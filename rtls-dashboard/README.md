# RTLS Dashboard

Web dashboard for **Real-Time Location Sync**. When you run only this app (`npm run dev` in this folder), only this directory’s code is used. The rest of the repo (Swift package, Android, React Native, Flutter, backend) is not loaded. live map of location points streamed from the backend over WebSocket, with optional REST fallback for latest positions.

---

## Overview

- **Stack:** React 19, TypeScript, Vite 7, [Leaflet](https://leafletjs.com/) via [react-leaflet](https://react-leaflet.js.org/). No backend of its own; consumes the RTLS Node.js API (REST + WebSocket).
- **Role:** Operational view of tracked users/devices: enter backend base URL and user IDs, subscribe to the WebSocket, and display points on a map with connection status and basic controls.
- **Data flow:** WebSocket `/v1/ws` (v2 protocol with bidirectional push) for real-time `location.update` messages; periodic `GET /v1/locations/latest?userId=` for resilience against missed WS frames; `GET /v1/locations/pull` for historical data retrieval. Points are kept per user (capped in memory) and rendered as paths.

---

## Features

- **Configurable backend URL** — Point to any RTLS backend (e.g. `http://localhost:3000` or `https://api.example.com`).
- **Multi-user subscription** — Specify one or more `userId` values; dashboard subscribes to each over the same WebSocket and polls latest as backup.
- **Live map** — Leaflet map with points and paths per user; viewport and zoom under user control.
- **Connection status** — Disconnected / connecting / connected / error with simple feedback.
- **No server-side rendering** — Pure SPA; all API calls from the browser (CORS must allow the dashboard origin on the backend).

---

## Development

### Prerequisites

- Node.js 18+
- Backend running (see [backend-nodejs/README.md](../backend-nodejs/README.md)) so that `/v1/locations/latest` and `/v1/ws` are available.

### Commands

```bash
cd rtls-dashboard
npm install
npm run dev
```

- **Build:** `npm run build` (output in `dist/`).
- **Preview build:** `npm run preview`.
- **Lint:** `npm run lint`.

### Usage

1. Open the app in the browser (e.g. `http://localhost:5173`).
2. Enter the **backend base URL** (e.g. `http://localhost:3000`).
3. Enter one or more **user IDs** (comma-separated or as configured by your backend).
4. Connect; the map subscribes via WebSocket and optionally polls latest. Start the mobile/client apps and push locations to see updates.

**Note:** If the backend uses JWT, the dashboard may need to send a token (e.g. query param or header); current implementation may assume auth-disabled or public endpoints. Extend the fetch/WebSocket logic as needed for your auth scheme.

---

## Project structure

| Path | Purpose |
|------|----------|
| `src/App.tsx` | Root component, URL/user state, connection UI, map container |
| `src/useLocationStream.ts` | Hook: WebSocket + polling, per-user point list, connection status |
| `src/components/LocationMap.tsx` | Leaflet map, paths and markers per user |
| `src/types.ts` | TypeScript types (e.g. `LocationPoint`) aligned with backend |
| `src/main.tsx` | Entry point, React root |
| `vite.config.ts` | Vite config; React plugin |
| `tsconfig.*.json` | TypeScript configs |

---

## Technology choices

- **Vite:** Fast HMR and build; ESM-native.
- **React 19:** Current React with hooks for state and effects.
- **Leaflet + react-leaflet:** Mature, mobile-friendly maps with minimal setup; no API key required for default tiles.
- **Single WebSocket:** One connection; multiple `subscribe` messages for multiple users to reduce resource use. The backend now supports the v2 WebSocket protocol with enhanced `location.update` messages containing richer metadata.
- **Historical pull:** The new `GET /v1/locations/pull` endpoint allows fetching historical location data for replay or gap-filling when the dashboard reconnects after a disconnection.

---

## Modular Architecture

The RTLS SDK has been restructured into independent packages across all platforms (iOS, Android/KMP, Flutter). The backend has been enhanced with the WebSocket v2 protocol and a new `GET /v1/locations/pull` endpoint. The dashboard consumes these backend APIs and benefits from the richer v2 message format without requiring changes to its own architecture.

For full details, see [MODULAR_ARCHITECTURE.md](../MODULAR_ARCHITECTURE.md).

---

## License

See repository [LICENSE](../LICENSE).
