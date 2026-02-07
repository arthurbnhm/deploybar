# DeployBar Architecture

## Overview

DeployBar uses a modular architecture:

- `Core`: shared domain types and interfaces.
- `VercelAPI`: typed REST client using `URLSession`.
- `Persistence`: local stores (Keychain, JSON settings, SQLite cache).
- `Features`: application state (`DeployBarAppStore`), monitoring engine, and UI components.
- `DeployBarApp`: macOS scene setup and lifecycle integration.

## Runtime Flow

1. App starts and loads local settings.
2. If token exists, DeployBar validates with `GET /v2/user`.
3. User selects scope and projects (max 20).
4. Monitoring loop refreshes production deployment status.
5. State transitions trigger notifications/sounds.
6. Logs are fetched on demand and cached in SQLite.

## Polling Strategy

Polling intervals are derived from selected profile and runtime conditions:

- Menu open: frequent refresh.
- Active menu-closed: regular refresh.
- Idle with no changes: backoff interval.
- In-progress deployments: boost interval.

## Persistence

- Token: Keychain generic password entry.
- Settings: `Application Support/DeployBar/settings.json`.
- Logs: `Application Support/DeployBar/deployments.sqlite`.

## Security Notes

- Token is never written to logs.
- No third-party analytics SDKs.
- Sign-out clears token and local caches.
