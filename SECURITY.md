# Security Policy

## Token Handling

- Vercel access tokens are stored in macOS Keychain using generic password records.
- Tokens are never persisted in JSON settings or SQLite logs.
- Disconnecting the Vercel account removes the token from Keychain.
- Local builds should use a stable code-signing identity so Keychain can keep trusting the same app across rebuilds.
- Public releases should be Developer ID signed, timestamped, hardened-runtime enabled, and notarized before upload.

## Local Data

- Settings and logs are local to the current user account under Application Support.
- The Disconnect action clears settings, selected projects, cached statuses, and local deployment logs.
- No telemetry or third-party analytics are included in V1.

## Reporting

If you discover a security issue, do not open a public issue with exploit details. Share a private report with maintainers first.
