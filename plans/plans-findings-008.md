# Plan 008 (spike) — Findings: Act on deployments — cancel and redeploy

Spike executed against commit `e6a8487`, merged forward with `advisor/004-vercel-api-hardening`
(fast-forwarded to `bb4efde`) for the shared `VercelAPITestSupport.swift` stub harness.

## 1. Endpoint contracts (verified via WebFetch against vercel.com/docs/rest-api, 2026-07-12)

### Cancel a deployment (implemented in this spike)

- **Method/path**: `PATCH /v12/deployments/{id}/cancel`
- **Path params**: `id` (string, required) — the deployment's unique identifier.
- **Query params**: `teamId` (string, optional), `slug` (string, optional) — team scoping. This
  spike uses `teamId` only (matches the rest of `VercelAPIClient`'s team-scoping convention).
- **Auth**: HTTP bearer token.
- **200 response**: returns the full updated deployment object with `readyState` set to
  `"CANCELED"`. Doc quote: *"The build has been stopped and this action is irreversible."*
- **400 response**: *"One of the provided values in the request query is invalid."* — this is
  also the documented behavior when the deployment is no longer cancelable: *"Returns 400 if the
  deployment is no longer cancelable (already READY, ERROR, or CANCELED)."* There is no distinct
  error code/shape carved out for "already finished" vs. other 400s in the reference doc — both
  fall under the same 400 response definition.
- **401**: "The request is not authorized." (token itself invalid/expired.)
- **403**: "You do not have permission to access this resource." (token valid, but lacks scope —
  e.g. a fine-grained token without deployment write access, or a personal token trying to act on
  a team it doesn't belong to.)
- **404**: deployment not found (no description given in the reference doc).

Source: `https://vercel.com/docs/rest-api/reference/endpoints/deployments/cancel-a-deployment`
(fetched fresh this session; canonical URL `/docs/rest-api/deployments/cancel-a-deployment`).

### Redeploy (design only — NOT implemented, per plan scope)

- **Method/path**: `POST /v13/deployments` (the same "create a new deployment" endpoint used for
  fresh deploys — there is no separate `/redeploy` endpoint).
- **Mechanism**: pass `deploymentId` (string) in the JSON body — *"The ID of an existing
  deployment to redeploy. All project settings and environment variables are inherited from the
  original unless explicitly overridden in this request. The redeployment gets a new ID, URL, and
  build."* `name` is still required by the schema (the project name) even when `deploymentId` is
  supplied.
- **Other relevant body fields**: `target` (`"staging"` | `"production"` | custom environment
  slug | omitted → defaults to `preview`), `project` (overrides `name` to target a specific
  project id), `gitSource`, `withCache` (when `true` + `deploymentId` set, drops the inherited git
  SHA and uses the latest commit instead).
- **Query params**: `teamId`, `slug` (scoping, same as cancel), `forceNew` (`0`/`1`, bypass
  dedup), `skipAutoDetectionConfirmation` (`0`/`1`, suppress framework-mismatch 400).
- **Minimal redeploy body** (design sketch, not implemented):
  ```json
  {
    "name": "<project-name>",
    "deploymentId": "<source-deployment-id>",
    "target": "production"
  }
  ```
- **Response**: new deployment object; lifecycle transitions `QUEUED` → `INITIALIZING` →
  `BUILDING` → `READY`/`ERROR`, same shape family as the cancel response's deployment object
  (`id`, `url`, `readyState`, etc.).
- **Design note for a future plan**: redeploy needs the *source* deployment id (from
  `DeploymentSnapshot.id`, already in hand) plus the project's display `name` (currently not
  stored on `WatchedProject` — would need adding, or a lookup against `availableProjects`/`Project`
  by id). Confirmation UX should warn this creates a **new** deployment rather than resuming the
  old one — different mental model than cancel.

Source: `https://vercel.com/docs/rest-api/reference/endpoints/deployments/create-a-new-deployment`
(fetched fresh this session; canonical URL `/docs/rest-api/deployments/create-a-new-deployment`).

## 2. Error semantics

- Cancel-on-already-finished (READY/ERROR/CANCELED) → HTTP 400, same shape as any other 400 from
  this endpoint (invalid request). `VercelAPIClient.send`'s `default:` branch maps any
  non-200/401/403/429 status to `DeployBarError.networking("Vercel API error \(status): \(body)")`,
  so this surfaces as a networking-style error with the status code and raw body embedded in the
  message. No special-cased `DeployBarError` was added for this because the doc doesn't
  distinguish "already finished" from other 400 causes at the schema level — a bespoke case would
  be guessing at a boundary the API itself doesn't expose. The store surfaces
  `error.localizedDescription` in `monitorError`, e.g. *"Vercel API error 400: {...}"* — readable
  enough for a spike; a real ship would want to parse the JSON `error.message` field for a cleaner
  string (see DTO comment for the deferred richer-decode work).
- 401 → `.unauthorized` (unchanged from every other endpoint) — the token itself is dead.
- 403 → `.forbiddenAction` on write endpoints only (see decision below) — the token is valid but
  can't do this specific write.
- 429 → `.rateLimited(resetAt:)` (unchanged, reuses existing mapping).

## 3. Permission failures — the key design decision

**Problem**: `send`'s existing `case 401, 403: throw DeployBarError.unauthorized` conflated "token
is dead" with "token can't do this." `DeployBarAppStore.shouldClearStoredToken(for:)` treats
`.unauthorized` as a hard failure and clears the Keychain-stored token
(`DeployBarAppStore+Lifecycle.swift`, `handleHardAuthFailure`). A fine-grained/scoped Vercel token
that's valid for reads but lacks deployment-write scope would 403 on cancel — clearing the user's
token over a *scope* problem, not a *validity* problem, would be a bad experience (silent logout
on a click of "Cancel Build").

**Decision taken** (matches the plan's recommended shape): added a single additive case,
`DeployBarError.forbiddenAction`, and a `mapForbiddenAsWriteFailure: Bool = false` parameter on
`VercelAPIClient.send`. Only `cancelDeployment` passes `true`; every existing GET call site is
unchanged (`send(request, as: T.self)` still defaults to `false`, so 401 and 403 both still map to
`.unauthorized` for reads — unchanged behavior, zero blast radius on the five original read
endpoints).

**Blast radius audit** (`grep -rn "DeployBarError" Packages DeployBarApp DeployBarTests`, full
output reviewed): three exhaustive `switch` statements over `DeployBarError` needed a mechanical
one-line fix to add `.forbiddenAction` to their non-clearing branch:
- `AuthBootstrapService.shouldRequireTokenReconnect` → `.forbiddenAction` joins
  `.rateLimited, .networking, .persistence, .unsupportedArchitecture` → `return false` (does not
  require reconnect).
- `DeployBarAppStore+Lifecycle.reconnectMessageForHardAuthFailure` → `.forbiddenAction` joins the
  `return nil` branch (no hard-auth reconnect message).
- `DeployBarAppStore+Lifecycle.shouldClearStoredToken` → `.forbiddenAction` joins
  `.missingToken, .rateLimited, .networking, .persistence, .unsupportedArchitecture` →
  `return false`. **This is the load-bearing line**: it's what keeps a 403-on-cancel from wiping
  the Keychain token.
All other `DeployBarError` consumers (`userFacingAuthError`, `performRefreshCycle`'s catch,
`startupRetryReason`, `monitoringRetryReason`) already use `default:`/non-exhaustive matches, so
`.forbiddenAction` silently falls through to their existing generic-error handling — verified by
reading each site, not just grep. `swift build` after the case addition confirms nothing else
failed to compile.

**Evidence 403 doesn't clear the token**: `DeployBarTests/AppStoreTests.swift` —
`testCancelDeploymentForbiddenActionDoesNotClearStoredTokenOrAuthSession`. Uses a new
`ForbiddenCancelMockVercelClient` whose `cancelDeployment` always throws `.forbiddenAction`;
asserts after calling `store.cancelDeployment(for:)` that `tokenStore.readToken()` still returns
the saved token, `store.authUser` is still non-nil, and `store.authConnectionState == .connected`.
Also unit-level coverage in `DeployBarTests/VercelAPIClientCancelTests.swift`:
`testCancelDeploymentMapsForbiddenToForbiddenActionNotUnauthorized` (403 → `.forbiddenAction`, not
`.unauthorized`) and `testCancelDeploymentStillMapsUnauthorizedFor401` (401 still →
`.unauthorized`, proving the write-flag only changes 403 behavior).

## 4. UX implemented

- **Confirmation dialog**: `MenuBarContentView` gained `.confirmationDialog("Cancel Build?", ...)`
  bound to a new `@State private var pendingCancelStatus: ProjectStatus?`, following the same
  destructive-role-button convention as `SettingsView`'s disconnect flow. Message: *"This stops
  the in-progress deployment for {project}. This action is irreversible."*
- **Which stages show the action**: `queued` and `building`. Extended `shouldShowInlineActions`,
  `handleProjectTap`, and `ProjectStatusRow.canSelect` (all previously `ready`/`failed` only) to
  also include `.queued`/`.building`, so in-flight rows now expand into the actions tray on tap —
  this was explicitly called out as in-scope in the plan ("adding cancel for in-flight stages
  means extending those to `.building`/`.queued`").
- **Tray contents differ by stage**: `DeploymentActionsRow` now takes a `stage` and shows "Logs" +
  "Cancel Build" (destructive-role button) for in-flight stages, vs. "Logs" + "Online" +
  "Dashboard" for terminal stages — Online/Dashboard aren't meaningful mid-build.
- **Spinner-in-tray**: `DeployBarAppStore.cancelingDeploymentID: String?` is set to the
  deployment's id for the duration of the `cancelDeployment` call (`defer` clears it). The row's
  Cancel Build button shows a `ProgressView` in place of the label and disables itself while
  `isCanceling` is true (`store.cancelingDeploymentID == status.snapshot?.id`).
- **Force refresh after action**: `DeployBarAppStore.cancelDeployment(for:)` always calls
  `manualRefresh()` after the do/catch (success or failure), so the popover re-polls immediately
  and reflects the new server-side state (e.g. `readyState: CANCELED` → `.canceled` stage, which
  already existed in `DeploymentStage`/`DeploymentStageMapper` before this spike).

## 5. Safety guards recorded for later (not implemented — spike scope)

- **Debounce/idempotency**: nothing stops a rapid double-tap of "Cancel Build" from firing two
  `PATCH` calls before the first's `manualRefresh()` lands. `cancelingDeploymentID` disables the
  *button* while in flight, which covers the common case, but a fast enough double-click before
  the first render could still race. A `Task` de-dupe guard (`if cancelingDeploymentID == snapshot.id
  { return }` at the top of `cancelDeployment(for:)`) would close this — cheap to add later.
- **Optimistic UI**: currently the row doesn't locally mark the deployment `.canceled` until the
  next poll returns; on a slow/rate-limited network this could look like nothing happened for a
  few seconds after a successful cancel. Worth an optimistic local stage flip in a follow-up.
- **Team-scope correctness**: `cancelDeployment` uses `status.project.teamId` (per-project team,
  from `WatchedProject`) rather than `store.selectedScope`. This is more correct — cancel always
  targets the deployment's actual owning team regardless of which scope tab the user currently has
  selected in the UI — but it means a project believed to belong to personal scope
  (`teamId == nil`) sends no `teamId` query param at all, which is correct per the docs (`teamId`
  is optional and defaults to the token's personal account).
- **Rate limiting on repeated cancels**: no client-side backoff/guard against a user
  spam-clicking cancel across many projects in a short window; relies entirely on Vercel's
  429 handling, which is already wired through `DeployBarError.rateLimited`.
- **Redeploy's blast radius**: unlike cancel (idempotent-ish, bounded to stopping something),
  redeploy *creates* a new deployment and consumes build minutes — deserves its own confirmation
  copy that says "this starts a new build," not reuse of the cancel dialog's copy.

## 6. Deviations / judgment calls from the plan text

- Added `CancelDeploymentResponse` (`Packages/VercelAPI/Sources/VercelAPI/VercelDTOs.swift`) as a
  minimal 2-field (`id`, `readyState`) optional-everything DTO. The plan's in-scope file list names
  `VercelAPIClient.swift` but not `VercelDTOs.swift`; adding the DTO there (rather than inlining an
  anonymous decode in the client) matches this package's existing convention (every other endpoint
  has its response DTO in `VercelDTOs.swift`) and is a small, mechanically necessary addition — not
  treated as an out-of-scope file for the purposes of this report, but flagged here explicitly
  since it's not in the plan's literal in-scope list.
- Added `cancelingDeploymentID` state to `DeployBarAppStore.swift` itself (not just the `+LogsAndAccount`
  extension) because `@Observable` stored properties must live on the class, not an extension.
  Same reasoning as above: mechanically required, minimal (1 line), flagged for visibility.
- The plan's "Error semantics" question asked what a per-action user-facing message should say for
  cancel-on-finished; I chose not to add a bespoke `DeployBarError` case for that specific 400
  because Vercel's own docs don't carve out a distinct signal for it (same 400 response definition
  covers "invalid query value" generally) — inventing a case around an undocumented boundary
  seemed likely to be wrong. Recorded as a decision, not silently skipped.
- Did not add "Cancel Build" to the row's `.contextMenu` (right-click) — the plan's UX ask was
  specifically about the actions tray; the context menu was already restricted to
  `ready`/`failed` stages before this spike and was left alone to keep the diff minimal.
- Live-cancel manual verification against a real Vercel account/build (the plan's "Done criteria"
  wants a real cancel exercised) was explicitly out of reach per this task's operating
  constraints (no real network calls to api.vercel.com). This is recorded as **pending operator
  verification** — someone with a real Vercel token and an in-flight build needs to: connect
  DeployBar, trigger a build, tap the project row while it's `queued`/`building`, confirm "Cancel
  Build," and verify (a) the deployment actually cancels on vercel.com, (b) the popover reflects
  `.canceled` after the forced refresh, (c) a scoped/fine-grained token (if available) produces the
  "doesn't have permission" message rather than logging the user out.

## 7. Verification commands run

| Command | Result |
|---|---|
| `swift build` | `Build complete!` |
| `swift test --parallel` | 49/49 tests passed, exit 0 (includes 6 new `VercelAPIClientCancelTests`, 1 new `AppStoreTests.testCancelDeploymentForbiddenActionDoesNotClearStoredTokenOrAuthSession`) |
| `./scripts/lint.sh` | `Lint checks passed`, exit 0 |
| `git status --porcelain` | Only in-scope files + this findings file + the new test file changed |
