# Plan 009 spike findings — Distribution: Homebrew cask and an update mechanism

Recorded after implementing the prototype scope of `plans/009-distribution-homebrew-updates.md`.
All claims below are backed by commands actually run in this worktree during the spike
(see the executor's report for the exact commands and output).

## 1. Cask home: official `homebrew/cask` vs a self-hosted tap

**Decision: start with a self-hosted tap, `arthurbnhm/homebrew-deploybar`.**

Current `homebrew/cask` notability policy (fetched from `docs.brew.sh/Acceptable-Casks`,
2026-07-12): an automated check rejects "an app from a code repository that is not notable
enough (under 30 forks, 30 watchers, 75 stars)." PR authors submitting their own repo face a
*higher* bar: under 90 forks, 90 watchers, 225 stars. Exceptions exist (apps with their own
website but GitHub-hosted binaries; submissions by prolific Homebrew contributors; software
with a recent surge of social-media attention) but are explicitly "not a guarantee for
inclusion."

**Distance to the bar, measured directly**: `curl https://api.github.com/repos/arthurbnhm/DeployBar`
returned `404 Not Found` (verified from this sandbox, unauthenticated). The repository is
either private or does not exist publicly yet. That means the distance to homebrew/cask's
notability bar isn't "close" or "far" — it's currently undefined, because there is nothing
public to count stars/forks/watchers on. **This is a precondition finding, not just a
distance measurement: the repo must be public with at least one real GitHub Release before
any of this (cask, update-checker, notability) can function for real users.** A self-hosted
tap has no such gate — `brew tap arthurbnhm/homebrew-deploybar && brew install --cask
deploybar` works the moment the tap repo exists, regardless of star count.

## 2. Cask versioning: template + script render (recommended) vs `brew bump-cask-pr`

**Decision: template rendered by `scripts/package_release.sh` (implemented).**

`brew bump-cask-pr` automates *opening a PR against an existing tap* when a new version is
detected upstream — it doesn't help mint the first cask, and it still needs something to
compute/know the correct SHA256 for a not-yet-public release artifact. Since this repo
already owns the release pipeline (`scripts/package_release.sh`), it is both simpler and more
correct to compute the SHA256 of the exact zip that pipeline just built/signed/notarized and
stamp it straight into the cask, rather than have a second, separate tool re-derive it after
the fact (which risks drift if the release zip is rebuilt).

Implemented:
- `packaging/homebrew/deploybar.rb.tmpl` — the committed source-of-truth template, with
  `__VERSION__`/`__SHA256__` placeholders.
- `scripts/package_release.sh` — now computes `shasum -a 256` of the final zip (post-staple
  for notarized builds, or the dry-run zip under `SKIP_NOTARIZATION=1`) and renders
  `packaging/homebrew/deploybar.rb` via a `render_cask()` shell function (`sed` substitution).

**Verified**: the exact `render_cask()` body from `scripts/package_release.sh` was copied into
an isolated shell and run against the real template; its output matched (after substituting
the same version/sha as a control) the committed `packaging/homebrew/deploybar.rb` byte for
byte. `brew style packaging/homebrew/deploybar.rb` reports exactly one offense —
`Style/FrozenStringLiteralComment` — and this offense **disappears entirely** when the same
file is copied into a directory literally named `Casks/` (verified locally: 0 offenses).
Homebrew's cask-specific rubocop relaxations are keyed off the `Casks/` path segment, not
file content. **Consequence**: `packaging/homebrew/deploybar.rb` in *this* repo will never be
100% `brew style`-clean at that exact path — it must be copied to
`Casks/deploybar.rb` in the real tap repo (`arthurbnhm/homebrew-deploybar`) to lint cleanly
and to be installable at all. The plan's requested path is honored literally as a staging
location; a follow-up (creating the actual tap repo) is required for the real thing.

## 3. Update mechanism: Sparkle 2 vs a minimal GitHub-releases checker

**Decision: ship the minimal checker now (implemented); design Sparkle on paper for later.**

Implemented `Packages/Features/Sources/Features/UpdateChecker.swift`:
- `UpdateChecker.isNewer(remote:current:)` / `parseVersion(_:)` — pure, dependency-free
  version comparison. Strips an optional leading `v`/`V`, splits on `.`, compares
  component-wise, zero-pads the shorter side. Fails closed (never reports "newer") on any
  non-numeric component, so a malformed or unexpected tag can never trigger an update
  prompt. 21 unit tests in `DeployBarTests/UpdateCheckerTests.swift` cover newer/equal/older/
  malformed/empty/prefixed/differing-length cases — zero real network calls.
- `UpdateChecker.checkForUpdate(currentVersion:session:)` — fetches
  `https://api.github.com/repos/arthurbnhm/DeployBar/releases/latest`, decodes `tag_name` and
  `html_url` (field names verified against a real, live GitHub API response — see below),
  and returns `.upToDate` / `.updateAvailable(latestVersion:releaseURL:)` /
  `.checkFailed(message:)`.
- Settings UI: a new "About" section in the Monitoring pane (`SettingsView.swift`) shows the
  running version and a "Check for Updates…" button. On tap it calls `checkForUpdate` and, if
  newer, opens the release page via `NSWorkspace.shared.open(_:)` (same pattern already used
  by `LogsView.swift`/`MenuBarContentView.swift` for external links) — no auto-download, no
  auto-install, matching the plan's out-of-scope boundary.

**GitHub API shape verified live**: `curl https://api.github.com/repos/steipete/CodexBar/releases/latest`
(a real, public repo) returned `"html_url": "https://github.com/steipete/CodexBar/releases/tag/v0.42.1"`
and `"tag_name": "v0.42.1"` — confirming both the field names used in
`LatestReleaseResponse` and the "v"-prefixed tag convention that `parseVersion` strips.

**Why minimal-checker-first is right for now**: DeployBar has zero SwiftPM dependencies today
(`Package.swift`), and the repo rule that `Package.resolved` must be committed the moment a
first dependency lands is a real one-way door (`.gitignore:6`). A "check and link out" flow
needs no dependency, no code signing changes, and no appcast infrastructure — it's a
same-day ship. Sparkle earns its keep once there's real install-base pain from users staying
on stale versions; the minimal checker at least stops that from being *silent*.

## 4. If Sparkle (design only — not implemented)

- **Appcast hosting**: `website/` is already a Next.js app on Vercel. A static/route-handler
  `GET /appcast.xml` (or a build-time-generated static file under `website/public/`) is
  trivial to add — no new infrastructure. Vercel serves it over HTTPS by default, which
  Sparkle 2 requires (or accepts EdDSA-signed content over HTTP, but HTTPS is free here).
- **EdDSA key custody**: generate with Sparkle's `generate_keys` tool once; the **private**
  key must live only in the release operator's local Keychain / a password manager — never in
  this repo, never in CI secrets unless CI is trusted to sign releases unattended (out of
  scope to decide here). The **public** key goes into the shipped `Info.plist` via
  `SUPublicEDKey`. Document the storage location (e.g. "1Password vault: DeployBar Release"),
  not the key itself, in an internal runbook — not in git.
- **Info.plist additions** (would be added to `scripts/install_app.sh`'s generated plist):
  `SUFeedURL` (pointing at the Vercel-hosted appcast), `SUPublicEDKey`, `SUEnableAutomaticChecks`.
- **Dependency cost**: adding Sparkle triggers the `Package.resolved`-must-be-committed rule
  and is the repo's first-ever external dependency — a maintainer call, correctly marked
  out-of-scope for this spike.

## 5. Version source of truth

**Decision: implemented.** Added `VERSION` (repo root, currently `0.1.0`, no `v` prefix) as
the single source. Both `scripts/install_app.sh` and `scripts/package_release.sh` now default
`APP_VERSION` to `$(cat "$ROOT/VERSION")`, falling back to the previous hardcoded `0.1.0` only
if the file is somehow missing; an explicit `APP_VERSION=` env var still overrides both (used
by CI or a manual release bump without editing the file, if ever needed).
`package_release.sh` also exports `APP_VERSION` through to the `install_app.sh` subprocess it
invokes, so both scripts and the rendered cask agree on one number per invocation.

**Not implemented, recorded as follow-up per the plan's explicit note**:
`Packages/VercelAPI/Sources/VercelAPI/VercelAPIClient.swift:5` still hardcodes
`private static let appVersion = "0.1.0"` for its `User-Agent` header. Wiring this to the
same `VERSION` file is not "cheap" the way the shell-script wiring was: `VercelAPIClient` is a
plain Swift library target with no build-time code generation step and no access to
`Bundle.main`'s Info.plist in a way that's meaningful for a package target (it isn't the app
bundle). The two realistic options are (a) a build-time codegen step (new SwiftPM plugin or a
pre-build script phase) that stamps a generated `Version.swift` from `VERSION`, or (b)
inject the version into `VercelAPIClient` from the app layer (`DeployBarEnvironment`/
`DeployBarAppStore`) at construction time, reading `Bundle.main`'s `CFBundleShortVersionString`
(same technique `UpdateChecker.runningVersion` now uses). (b) is low-risk and requires no new
build machinery — recommended as the concrete follow-up, deliberately left undone here since
it touches `VercelAPIClient`'s public initializer signature and its call sites, which is
explicitly out of scope for this spike per the plan.

## Summary of decisions

| Question | Decision |
|---|---|
| Cask home | Self-hosted tap (`arthurbnhm/homebrew-deploybar`), not yet created; `homebrew/cask` blocked on the GitHub repo being public at all (currently 404) |
| Cask versioning | Template + `package_release.sh` render (implemented); `brew bump-cask-pr` doesn't apply until a tap exists |
| Update mechanism | Minimal GitHub-releases checker (implemented, prototype only — no auto-download/install) |
| Sparkle | Designed on paper only; explicitly not added (zero new SwiftPM dependencies, as required) |
| Version source of truth | `VERSION` file (implemented) for shell scripts; `VercelAPIClient.appVersion` left hardcoded, follow-up recommended |
