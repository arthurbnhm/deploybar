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

## State & UI Organization

- `DeployBarAppStore.swift`: root observable state and startup entry points.
- `DeployBarAppStore+Lifecycle.swift`: bootstrap, persistence helpers, and onboarding error mapping.
- `DeployBarAppStore+Onboarding.swift`: token connect, scope/project loading, onboarding completion.
- `DeployBarAppStore+Monitoring.swift`: polling loop, cadence selection, transition handling.
- `DeployBarAppStore+LogsAndAccount.swift`: logs sheet data flow and account/data reset actions.
- `AuthBootstrapService.swift`, `ProjectSelectionService.swift`, `TransitionNotificationService.swift`: pure domain helpers extracted from the store.
- UI shared components are split by concern:
  - `DesignSystem.swift`
  - `SurfaceCards.swift`
  - `StatusComponents.swift`
  - `ProjectsSelectionSection.swift`

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
