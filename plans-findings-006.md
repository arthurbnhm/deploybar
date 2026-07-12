# Plan 006 (spike) — Findings: Live log tailing for in-progress deployments

Status: prototype implemented, tests green, lint clean. See report for STOP-condition status (none hit).

## 1. Cursor semantics: is `since` inclusive or exclusive?

The current Vercel REST API reference for deployment events
(`https://vercel.com/docs/rest-api/reference/endpoints/deployments/get-deployment-events`,
fetched 2026-07-12) documents the endpoint as `GET /v3/deployments/{idOrUrl}/events` (the app
uses `/v2/...`, which still appears to be a supported/aliased path — no deprecation notice was
found) and describes `since` only as: "Timestamp for when build logs should be pulled from." It
does **not** state whether the boundary timestamp itself is included or excluded, and no
authoritative statement was found via targeted web search either (community threads speculate
but don't cite an authoritative source). A live empirical check was not possible in this sandbox
(no real calls to api.vercel.com are permitted per task constraints) — **this is pending operator
verification** against a real deployment.

This is a non-issue for correctness either way: the design never assumes exclusivity.
`Packages/Persistence/Sources/Persistence/SQLiteDeploymentEventStore.swift:24` persists with
`INSERT OR REPLACE INTO deployment_events` keyed on the namespaced event id
(`"\(deploymentId)-\(event.id)"`, set in `VercelAPIClient.deploymentEvents`), and every tail
iteration reloads `logEvents` fresh from the store after persisting. If `since` turns out to be
inclusive and the boundary event is refetched, it's idempotently replaced, not duplicated, and
list order in the UI is unaffected. Recommendation for a follow-up plan: once live-verified,
consider whether `since` should be set to `newestMs + 1` if it's confirmed inclusive, purely as a
minor bandwidth optimization — not required for correctness today.

## 2. Terminal detection: how the tail loop learns the deployment finished

Decision: **re-resolve stage from `projectStatuses` by project id**, exactly as the plan
suggested, rather than issuing an extra direct fetch. Implementation in
`Packages/Features/Sources/Features/DeployBarAppStore+LogsAndAccount.swift`
(`runLogsTailLoop`):

```swift
let resolvedStage = projectStatuses.first(where: { $0.project.id == projectId })?.snapshot?.stage
if resolvedStage == nil || resolvedStage!.isTerminal {
    await performFinalCatchUpFetch(deploymentId: deploymentId, sinceMs: sinceMs)
    // ...update selectedLogsDeployment, break
}
```

Rationale: the monitoring loop (`DeployBarAppStore+Monitoring.swift`) already refreshes
`projectStatuses` on its own cadence for every watched project, so reusing it costs zero extra
API calls and keeps the tail loop's request budget limited to `deploymentEvents` polls only —
consistent with the "tail loop must stay independent of the monitor loop" maintenance note (it
reads shared state but does not drive or depend on the monitor loop's timing).

**Gap** (explicitly called out in code comment): if the project is unwatched while a tail is in
progress, it disappears from `projectStatuses` entirely, so `resolvedStage` becomes `nil`. The
implementation treats `nil` the same as "terminal" and stops tailing — there's no way to
distinguish "unwatched" from "the deployment reached a stage we can't see," and the loop can't
tell the user why it stopped (no error is surfaced; the Logs window just stops showing the "Live"
indicator). This is an acceptable degradation for a spike but is worth a UX note in a follow-up:
consider surfacing "stopped tailing — project no longer watched" if this proves confusing in
practice.

A second, related gap not asked about but discovered during implementation: if a **new**
deployment starts on the same project while an older one is being tailed, `projectStatuses` will
report the new deployment's stage (e.g. `building`) even though the tail loop is still polling
events for the old `deploymentId`. The loop has no way to notice the deployment identity changed
underneath it — it will keep tailing the old (now finished) deployment as if it were still in
flight until the new deployment also reaches a terminal-or-vanished state, or the user closes the
window. Out of scope to fix here (would need deployment-id-aware transition detection, likely
best paired with plan 007's deep-linking work), but flagged for the next iteration.

## 3. Cadence: is 2s reasonable?

Kept the plan's default of 2.0s (`logsTailInterval` on `DeployBarAppStore`, injectable for tests).
Reasoning:
- It's tighter than the monitor loop's `inProgressBoostInterval` (2–5s depending on
  `PollingProfile`, see `Packages/Core/Sources/Core/Models.swift`), which is appropriate — the
  Logs window is an explicit, foreground, single-deployment focus where a user is actively
  watching, versus the monitor loop's background multi-project sweep.
- On transient errors the loop backs off to 5.0s (hardcoded, not separately injectable — the plan
  only asked for the happy-path interval to be injectable) and continues rather than stopping,
  matching the "transient failures must not kill the tail" requirement.
- On `rateLimited(resetAt:)` the loop sleeps until `resetAt` exactly once, then resumes at the
  normal interval — same policy as `performRefreshCycle`'s rate-limit handling for consistency.
- **Live-API verification of whether 2s is too aggressive against Vercel's actual rate limits is
  pending operator verification** — this was covered with unit tests against `TailingMockVercelClient`
  only, per the task's constraint against real network calls. The mock proves the interval/backoff
  *mechanics* work as designed; it cannot prove Vercel's real rate-limit thresholds are respected
  at 2s cadence over a long build. Recommend the operator watch response headers
  (`X-RateLimit-*`) during a real long-running deployment before shipping this cadence as-is.

## 4. UI follow behavior

Chose **`ScrollViewReader` + a bottom sentinel view with `onAppear`/`onDisappear`**, not
`defaultScrollAnchor(.bottom)`. Implementation: `LogsScrollView` in
`Packages/Features/Sources/Features/LogsView.swift`. A zero-height `Color.clear` view tagged
`.id("logs-bottom-anchor")` sits after the last log row; its `onAppear`/`onDisappear` toggle a
private `@State var isAtBottom`. `.onChange(of: events.count)` only calls
`proxy.scrollTo(bottomAnchorID, anchor: .bottom)` when `isAtBottom` is true. When the user scrolls
up, the sentinel leaves the viewport, `isAtBottom` flips to `false`, and subsequent tailed events
no longer force-scroll — satisfying "must NOT yank the user back down." Scrolling back down past
the sentinel re-engages auto-follow automatically (no explicit "jump to bottom" button was added,
though that's a natural, cheap follow-up if manual testing shows it's needed).

Why not `defaultScrollAnchor(.bottom)`: researched via web search
(`nilcoalescing.com/blog/ModernSwiftUIAPIsForProgrammaticScrolling`, a Medium tutorial on
SwiftUI auto-scroll patterns) — one source explicitly states plain `defaultScrollAnchor(_:)` (no
`for:` role) is **not sufficient** to reliably keep a growing list pinned to the bottom as new
rows are appended, and recommends the `ScrollViewReader` + `scrollTo` pattern instead, which is
what this implementation uses. The role-scoped overload
(`defaultScrollAnchor(_:for: .sizeChanges)`) that might address this more declaratively appears to
be a newer addition (iOS 18/macOS 15-era API surface based on search results); since this project
targets macOS 14+ (per project memory) and the behavior couldn't be empirically verified without
launching the app (disallowed for this task), the more predictable, broadly-compatible
`ScrollViewReader`-based approach was chosen over a modifier whose exact macOS-14 behavior is
undocumented and unverifiable here. This could not be visually confirmed by running the app
(disallowed) — **pending operator verification** that the scroll behavior feels right in practice.

Also added a subtle "Live" toolbar indicator (`LiveIndicator`, a small pulsing red dot + "Live"
label, styled consistent with the existing `StatusPill`/`StatusDot` pulse pattern in
`StatusComponents.swift`) shown only while `store.isTailingLogs` is true, plus a "Tailing live
output…" caption in the existing bottom event-count bar.

## Other implementation notes / judgment calls

- **Generation guard against a task-handle race**: `startLogsTail` cancels-and-replaces
  `logsTailTask` synchronously, but the *old* task's own deferred cleanup
  (`logsTailTask = nil`) runs asynchronously and could, in a narrow window (rapid re-open of the
  Logs window before the old task notices cancellation), fire *after* the new task has already
  been assigned — clobbering the new task's handle and silently ending its "isTailingLogs"
  observability. Fixed by adding an internal `logsTailGeneration: Int` counter, bumped on every
  `startLogsTail`, and having the loop's cleanup only clear `logsTailTask`/`isTailingLogs` if its
  captured generation still matches the current one. This is a generic pattern for any
  cancel-and-replace `Task` on an `@Observable` store; not explicitly required by the plan but a
  low-cost correctness fix given the plan explicitly cares about "no leaked task" behavior.
- **`openLogs` cursor seeding**: the initial one-shot fetch (`since: nil, limit: 250`) computes
  `initialSinceMs` as the max `createdAt` (converted to epoch ms) among the events it fetched, and
  passes that into the tail loop as its starting cursor — so the tail's first poll only asks for
  events strictly after what was already shown, rather than refetching the same 250 events. If the
  initial fetch fails or has zero events, the cursor starts `nil` (full backfill on the tail's
  first poll), matching existing error-tolerant behavior in `openLogs`.
  Tail starts even if the initial fetch throws (falls to the `catch` block), as long as the
  snapshot's stage was in-flight when `openLogs` was called — a transient fetch failure shouldn't
  prevent tailing from starting.
- **`swift test --parallel` and `MainActor` determinism**: `DeployBarAppStore` and
  `AppStoreTests` are both `@MainActor`, so the store's tail `Task` and the test's assertions are
  cooperatively serialized on the same executor; tests only observe intermediate tail-loop state
  at their own `await Task.sleep` suspension points. This made it possible to write the "appended
  events reach `logEvents`" test (`testLogsTailDeliversAppendedEventsAndStopsOnTerminalStage`)
  without a real race: mutating `store.projectStatuses` between two `waitUntil` polls is guaranteed
  to be observed by the tail loop's *next* stage check, not raced against an in-progress one.
- **Mocks.swift was not touched** — a new call-count-driven `TailingMockVercelClient` was added
  directly in `DeployBarTests/AppStoreTests.swift`, matching the existing convention there (every
  other test-specific `VercelClient` mock — `TokenPruningMockVercelClient`,
  `MissingTokenRefreshMockVercelClient`, `FlakyStartupAuthMockVercelClient`,
  `TransitioningMockVercelClient` — is defined locally in that file, not in the shared
  `Mocks.swift`). The plan listed `Mocks.swift` as in-scope "only if needed"; it wasn't.

## Deviations from the plan's literal wording

- The plan's prototype-scope example loop pseudocode implies a single `deploymentEvents` call per
  iteration followed immediately by a stage check; the actual implementation matches this, but the
  "on terminal stage, do one final fetch and stop" step is implemented as a second,
  separate `deploymentEvents` call (`performFinalCatchUpFetch`) issued *after* detecting the
  terminal stage in the current iteration — i.e. up to two `deploymentEvents` calls happen in the
  terminal iteration (the one that revealed the transition, plus one explicit catch-up). This
  matches a literal reading of "on terminal stage, do one final fetch and stop" as an *extra*
  fetch beyond the loop's normal per-iteration fetch, to catch any trailing events emitted between
  the transition-revealing poll and the stop. If a tighter interpretation (skip the extra fetch,
  reuse the iteration's own fetch as "the final fetch") was intended, that's a one-line
  simplification to `runLogsTailLoop`.
