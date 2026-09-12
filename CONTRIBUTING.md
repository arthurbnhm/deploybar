# Contributing

## Development Setup

1. Install full Xcode 26+ and select it with `xcode-select` (Command Line Tools alone lack XCTest).
2. Clone repository.
3. Run `swift build` and `swift test`.

## Code Standards

- Prefer clear, typed interfaces.
- Keep comments minimal and intent-focused.
- Avoid adding dependencies unless justified.
- Keep V1 local-first and telemetry-free.

## Pull Request Checklist

- [ ] Build succeeds on macOS.
- [ ] Unit/smoke tests pass.
- [ ] No secrets committed.
- [ ] Architecture and behavior changes documented.

## Website and shared assets

Run `npm ci`, `npm audit --audit-level=moderate`, `npm run typecheck`, and
`npm run build` in `website/`. Include the repository's `design/` directory:
it contains the shared brand tokens imported by the site and checked by Swift tests.

## License and security

Contributions are provided under the repository's [MIT License](LICENSE).
Report vulnerabilities privately using [SECURITY.md](SECURITY.md); do not submit
exploit details or secrets in a public issue or pull request.
