# DeployBar

DeployBar is a native macOS menu bar app for monitoring Vercel production deployments.

## Highlights

- Native SwiftUI with the macOS 26 Liquid Glass design language
- Token-only Vercel auth (stored in macOS Keychain)
- Personal and team scope project selection (up to 20 projects)
- Dynamic menu bar status icon
- Smart polling profiles (Balanced, Aggressive, Eco)
- Local notifications with designed alert sounds (three selectable themes, preview in Settings)
- Embedded deployment event logs
- Local-only persistence (settings JSON + SQLite cache)
- One-click disconnect for clearing token, settings, cached statuses, and local logs

## Requirements

- macOS 26+ (Tahoe)
- Apple Silicon (`arm64`) target for V1

## Download

Download from [deploybar.com](https://deploybar.com) or
[GitHub Releases](https://github.com/arthurbnhm/deploybar/releases/latest).

**The current release is an unsigned preview.** It is ad-hoc signed for Apple
Silicon execution, but has no Apple Developer ID signature and is not notarized.
Unzip the download, move DeployBar to Applications, and try opening it once.
If macOS blocks it, use **System Settings → Privacy & Security → Open Anyway**
for DeployBar. Only approve a copy downloaded from this project. See the
[installation guide](docs/INSTALLATION.md) and the checksum attached to the release.

Homebrew installs the same unsigned build:

```bash
brew install --cask arthurbnhm/deploybar/deploybar
```

## Build

Building from source requires Xcode 26+ / Swift 6.2+. The downloaded app does not
require Xcode or Apple Developer membership.

```bash
git clone https://github.com/arthurbnhm/deploybar.git
cd deploybar
swift build
```

## Install Locally

DeployBar stores its Vercel token in Keychain, so local installs should be signed
with a stable identity. If you have an Apple signing certificate, the installer
will pick it automatically:

```bash
./scripts/install_app.sh
```

If you do not have an Apple Developer certificate, create a local code-signing
identity once:

```bash
./scripts/create_dev_codesign_identity.sh
./scripts/install_app.sh
```

The first install after creating this identity may ask whether `codesign` can use
the new private key. Choose `Always Allow` so future local installs can sign
without asking again.

Ad-hoc signing is available only as an explicit one-off fallback:

```bash
ALLOW_ADHOC_SIGNING=1 ./scripts/install_app.sh
```

## Package a Public Release

An explicitly labeled unsigned preview does not require Apple Developer membership:

```bash
./scripts/package_release.sh --unsigned
```

This creates `dist/DeployBar.zip` and `dist/DeployBar.zip.sha256` and renders the
Homebrew cask. It does not install or publish the files.

The separate Developer ID signed and notarized release path requires Apple
Developer membership and a Developer ID Application certificate. This also
applies to direct downloads outside the Mac App Store.

Create a notarytool profile once:

```bash
xcrun notarytool store-credentials deploybar-notary \
  --apple-id you@example.com \
  --team-id TEAMID \
  --password app-specific-password
```

Then create the release zip:

```bash
NOTARY_PROFILE=deploybar-notary ./scripts/package_release.sh
```

The default release path requires a `Developer ID Application` identity.
`SKIP_NOTARIZATION=1` remains a local dry run; use `--unsigned` for the unsigned
preview path. See the [publication checklist](docs/PUBLISHING.md).

## Test

```bash
swift test
```

## Website

A marketing site lives in `website/` (Next.js 16 + React 19).

```bash
cd website
npm ci
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

DeployBar contacts Vercel directly to monitor deployments and perform requested
build cancellations. Checking for updates manually contacts GitHub Releases
without sending the Vercel token. The app has no analytics or telemetry.

Settings, deployment metadata, and build logs are stored locally. Build logs may
contain sensitive output from your builds. Disconnect clears local account data
and rejects late responses from the old session; it does not revoke the token at
Vercel or erase backups. See [SECURITY.md](SECURITY.md) for details.

## Keychain Prompts

DeployBar stores your Vercel token in macOS Keychain under `com.deploybar.token`.

If macOS keeps asking for Keychain access:

1. Make sure the app is signed with a stable identity. Rebuilt ad-hoc apps look
   like different apps to Keychain.
2. Use one installed app location (`~/Applications/DeployBar.app` or `/Applications/DeployBar.app`).
3. After changing from ad-hoc to stable signing, approve the existing Keychain
   item once with `Always Allow` so Keychain updates its trust entry.

```bash
./scripts/create_dev_codesign_identity.sh
./scripts/install_app.sh
```

Apple explains that if an already trusted app changes, Keychain may ask you to
authorize it again. Stable code signing gives Keychain a durable app identity
across rebuilds.

## License and security reports

DeployBar is licensed under the [MIT License](LICENSE). Third-party dependencies
retain their own licenses. This is an independent project, not affiliated with
or endorsed by Vercel or Apple.

Use the confidential reporting channel described in [SECURITY.md](SECURITY.md).
Do not include credentials or private build logs in public issues.
