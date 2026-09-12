# Security Policy

## Reporting a vulnerability

Use [GitHub Private Vulnerability Reporting](https://github.com/arthurbnhm/deploybar/security/advisories/new)
for confidential reports about DeployBar or its website. Do not post exploit
details, tokens, or private deployment logs in public issues or pull requests.

The reporting form requires a public repository with private vulnerability
reporting enabled. While this repository is private, that public intake is not
available. Maintainers must enable and verify it as part of the
[publication checklist](docs/PUBLISHING.md) before announcing the project.

Include the affected version or commit, macOS version, reproduction steps,
expected and actual behavior, and impact. Use synthetic credentials and redact
customer data. Keep the report private while a fix is being prepared.

## Supported versions

During initial development, security fixes target the latest code on `main`.
There is no published stable release or support commitment for older builds yet.
Once releases exist, report the exact affected release and test the latest one
when practical.

## Credentials and network access

- The Vercel access token is stored in macOS Keychain, using a device-bound
  data-protection entry. Existing file-based Keychain entries are migrated.
- DeployBar does not intentionally write the authentication token to JSON or
  SQLite. Remote build output may contain secrets emitted by a user's build;
  treat cached logs as potentially sensitive.
- Monitoring and build cancellation send authenticated HTTPS requests to
  `api.vercel.com`. Vercel enforces the token's permissions.
- A manual update check contacts `api.github.com` without the Vercel token.
  It opens a release link; it does not download or install software.
- No analytics or telemetry are included. Browser links are opened only when
  requested by the user.

## Local data and disconnect

Settings, deployment metadata, and cached build logs are stored under
`~/Library/Application Support/DeployBar`. Settings and logs are not separately
encrypted by DeployBar; macOS account permissions and disk protection apply.
Logs older than seven days are purged periodically while monitoring runs.

Disconnect invalidates ongoing account and log operations, stops monitoring,
waits for already-started log writes, and clears the Keychain token, settings,
cached statuses, and local deployment logs. Late responses from the previous
session are ignored. Cleanup failures are shown in the app.

Clearing this data is a logical deletion, not a promise of forensic erasure from
storage, backups, or previously delivered system notifications. Disconnecting
removes the local token; revoke it in Vercel if it may have been exposed.

## Distribution

Local builds should use a stable signing identity for Keychain continuity.
Public app releases must be Developer ID signed, timestamped, hardened-runtime
enabled, and notarized. An ordinary local build is not a verified public release.
See [publishing](docs/PUBLISHING.md) for the release checks.
