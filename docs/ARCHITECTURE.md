# DeployBar Architecture

## Overview

DeployBar uses a modular architecture:

- `Core`: shared domain types and interfaces.
- `VercelAPI`: typed REST client using `URLSession`.
- `Persistence`: local stores (Keychain, JSON settings, SQLite cache).
- `Features`: application state (`DeployBarAppStore`), monitoring engine, and UI components.
- `DeployBarApp`: macOS scene setup and lifecycle integration.

## Runtime Flow

1. App creates its live environment and loads local settings. If environment creation fails, it displays an explicit startup error with Retry and Quit; production never falls back to mock data.
2. If token exists, DeployBar validates with `GET /v2/user`.
3. User selects scope and projects (max 20). Teams and projects are loaded across all Vercel pagination pages.
4. Monitoring loop refreshes production deployment status.
5. State transitions trigger notifications/sounds.
6. Logs are fetched on demand and cached in SQLite.

## State & UI Organization

- `DeployBarAppStore.swift`: root observable state and startup entry points.
- `DeployBarAppStore+Lifecycle.swift`: bootstrap, persistence helpers, and onboarding error mapping.
- `DeployBarAppStore+Setup.swift`: token connect, scope/project loading, onboarding completion.
- `DeployBarAppStore+Monitoring.swift`: polling loop, cadence selection, transition handling.
- `DeployBarAppStore+LogsAndAccount.swift`: logs sheet data flow and account/data reset actions.
- `ProjectSelectionService.swift`, `TransitionNotificationService.swift`: pure domain helpers extracted from the store.
- UI shared components are split by concern:
  - `DesignSystem.swift` (layout metrics + status color/symbol metadata; fills and typography come from system semantic styles)
  - `StatusComponents.swift`
  - `ProjectsSelectionSection.swift`

## Design Language

DeployBar targets macOS 26 and adopts the native design language directly:

- Liquid Glass button styles (`.glass`, `.glassProminent`) for the popover's deployment actions.
- System semantic colors (`.green`, `.orange`, `.red`, `.indigo`) and hierarchical fills (`.quaternary`, `.quinary`) instead of hand-rolled palettes.
- Semantic type styles (`.headline`, `.body`, `.subheadline`, `.caption`) instead of fixed font sizes.
- Native scenes: `MenuBarExtra` (window style), `Settings` (opened via the `openSettings` environment action), and a `Window` for logs with a standard toolbar.
- The app runs as an accessory (`LSUIElement`), so it has no Dock icon.

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
- Disconnect clears the Keychain token, settings, cached statuses, and local deployment logs.

## Session boundaries

Account operations capture a session generation. Disconnect, token replacement,
and hard authentication failures invalidate that generation and stop monitoring
and log work. Responses from an older session cannot restore authentication,
settings, statuses, or logs. Log windows also have a generation so switching or
closing a window invalidates its outstanding requests.

Disconnect waits for log writes already admitted before clearing the event store.
MonitoringEngine rejects a refresh that completes after its state was reset.
Startup initialization and retry are owned by `DeployBarStartup`; preview data
is used explicitly by development previews and tests only.

Manual update checks contact GitHub Releases without the Vercel token. See
`SECURITY.md` for local data handling and `PUBLISHING.md` for publication gates.
