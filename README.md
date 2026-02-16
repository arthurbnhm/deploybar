# DeployBar

DeployBar is a native macOS menu bar app for monitoring Vercel production deployments.

## Highlights

- Native SwiftUI + AppKit material styling
- Token-only Vercel auth (stored in macOS Keychain)
- Personal and team scope project selection (up to 20 projects)
- Dynamic menu bar status icon
- Smart polling profiles (Balanced, Aggressive, Eco)
- Local notifications and subtle sound effects
- Embedded deployment event logs
- Local-only persistence (settings JSON + SQLite cache)

## Requirements

- macOS 14+
- Apple Silicon (`arm64`) target for V1
- Xcode 16+ / Swift 6+

## Download

For end users, download the latest app build from GitHub Releases:

- https://github.com/arthurbnhm/DeployBar/releases/latest

After downloading:

1. Move `DeployBar.app` to `/Applications` (or `~/Applications`).
2. Open DeployBar and approve Keychain access when prompted.

## Build

```bash
swift build
```

## Test

```bash
swift test
```

## Website

A marketing site lives in `website/` (Next.js 16 + React 19).

```bash
cd website
npm install
npm run dev
```

Website checks:

```bash
cd website
npm run build
npm run typecheck
```

## Project Layout

- `DeployBarApp/` app entrypoint and scene setup
- `Packages/Core/` domain models + protocols
- `Packages/VercelAPI/` Vercel REST client + DTO mapping
- `Packages/Persistence/` Keychain + settings + SQLite event cache
- `Packages/Features/` UI, state, polling engine, notifications, sound
- `DeployBarTests/` unit tests
- `DeployBarUITests/` smoke-style view tests
- `website/` Next.js marketing website

## Privacy

DeployBar sends API requests only to Vercel and stores data locally. No analytics or telemetry are included in V1.

## Keychain Prompts

DeployBar stores your Vercel token in macOS Keychain under `com.deploybar.token`.

If macOS keeps asking for Keychain access:

1. Choose `Always Allow` in the Keychain prompt (not just `Allow`).
2. Use one installed app location (`~/Applications/DeployBar.app` or `/Applications/DeployBar.app`).
3. Prefer signing with a stable identity when installing during development:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/install_app.sh
```

Using ad-hoc signatures (`-`) may trigger repeated Keychain trust prompts after app updates.
