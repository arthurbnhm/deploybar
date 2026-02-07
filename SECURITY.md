# Security Policy

## Token Handling

- Vercel access tokens are stored in macOS Keychain using generic password records.
- Tokens are never persisted in JSON settings or SQLite logs.
- On sign-out, tokens are removed from Keychain.

## Local Data

- Settings and logs are local to the current user account under Application Support.
- No telemetry or third-party analytics are included in V1.

## Reporting

If you discover a security issue, do not open a public issue with exploit details. Share a private report with maintainers first.
