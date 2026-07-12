# Plan 007 (spike) — Findings

Clicking a deploy notification now carries `projectId`/`deploymentId` and, on click,
routes to opening that project's current logs window. Manual click-through in a
real running `.app` is **pending operator verification** (this run never launched
the app, per the task's override).

## Spike questions

### 1. Protocol shape

Extended `NotificationRouting` with a defaulted-looking parameter via a protocol
extension overload, as the plan recommended:

```swift
public protocol NotificationRouting: Sendable {
    func requestAuthorization() async -> Bool
    func notify(title: String, body: String, userInfo: [String: String]) async
}

public extension NotificationRouting {
    func notify(title: String, body: String) async {
        await notify(title: title, body: body, userInfo: [:])
    }
}
```

Rationale: protocol requirements can't declare default argument values directly.
Making `userInfo` part of the required signature and providing the 2-arg
convenience via an extension keeps existing no-payload call sites
(`DeployBarAppStore+Lifecycle.swift:209`, the settings "test notification" send)
unchanged and untouched — they still compile and resolve to the extension
overload, which forwards an empty dictionary. This was verified: that call site
was left as-is and the build/tests confirm it still resolves correctly.

Conformers requiring mechanical updates (as anticipated, no ripple beyond the
plan's named files):
- `Packages/Features/Sources/Features/NotificationManager.swift` — `MacNotificationRouter.notify` implements the 3-arg requirement and now sets `content.userInfo`.
- `Packages/Features/Sources/Features/Mocks.swift` — `InMemoryNotificationRouter.notify` updated to the 3-arg signature (still a no-op).
- `DeployBarTests/AppStoreTests.swift` — `NotificationSpyRouter.notify` updated to capture `userInfo` per delivery and expose it via a new `lastUserInfo()` accessor.

### 2. Activation routing

`didReceive` is implemented on `NotificationCenterDelegate` (in
`NotificationManager.swift`). It reads `response.notification.request.content.userInfo["projectId"]`
and hops to `Task { @MainActor in NotificationActivationRouter.shared.handleActivation(projectId:) }`
— `didReceive` can fire on an arbitrary queue, so the MainActor hop happens
inside the delegate before touching any app state. `completionHandler()` is
called unconditionally and synchronously (not deferred to the Task), matching
Apple's guidance that the completion handler just needs to be called, not
block on further work.

`NotificationActivationRouter` (new, `@MainActor`, in `NotificationManager.swift`,
public) is a thin registrable-closure singleton, deliberately mirroring the
existing `SettingsPresenter` pattern in `DeployBarApp.swift` — this is the same
bridging problem (SwiftUI environment action needed outside the view tree)
the codebase already solved once.

`LogsPresenter` (new, `@MainActor`, in `DeployBarApp.swift`, mirrors
`SettingsPresenter` exactly) holds a `(String) -> Void` closure registered from
`SettingsBridgeView.onAppear`, where `@Environment(\.openWindow)` is available.
That closure resolves the project via `store.openLogsForProject(id:)` then
calls the existing `presentWindow(.logs, openWindow:)` helper. Two closures
chain: `NotificationActivationRouter` (owns click activation) calls into
`LogsPresenter.present(projectId:)` (owns window presentation + `NSApp.activate()`),
keeping the two concerns cleanly separated the same way `SettingsPresenter`
is separate from the app-delegate reopen handler.

Retain/concurrency check: both singletons hold their closures as `private var`
on a `@MainActor final class`, exactly like the existing `SettingsPresenter` —
no actor-hopping hazards beyond the single `Task { @MainActor in ... }` hop in
the delegate, which is unavoidable because `UNUserNotificationCenterDelegate`
methods are not actor-isolated. This compiled cleanly with Swift 6 strict
concurrency (`swift build` succeeded with zero warnings/errors related to
Sendability on these types).

Real click-through (does the banner actually launch/foreground the app and
open the logs window) is **pending operator verification** — this task's
override explicitly forbids posting real `UNUserNotificationCenter`
notifications or launching the app, so this path is compiled and unit-tested
but not exercised end-to-end.

### 3. Stale-target behavior

Chose: open logs for the project's **current** status, not the specifically
notified deployment. `openLogsForProject(id:)` (new helper in
`DeployBarAppStore+LogsAndAccount.swift`) resolves `projectStatuses.first(where: { $0.project.id == id })`
and delegates to the existing `openLogs(for:)` — it ignores the `deploymentId`
userInfo entirely for now. `deploymentId` is still attached to the
notification's userInfo per the plan ("for future use") in case a later
iteration wants to pin to the exact notified deployment (e.g. to diff against
a newer one, or warn "a newer deploy has since started").

Gap: if the user clicks an old "Failed" notification after a newer deployment
has already gone `ready`, they'll land on the current (successful) logs, not
the failed one that prompted the notification. This is the documented,
accepted tradeoff — simpler and avoids a confusing "logs for a deployment that
no longer exists in cache" case. A follow-up could thread `deploymentId`
through if the log-fetch flow is changed to support fetching a specific
deployment's logs regardless of whether it's still "current" (it already can,
technically — `openLogs(for:)` takes a `ProjectStatus` with any `snapshot` —
but there's no store method today to open logs for an arbitrary deployment id
that isn't the project's latest cached snapshot).

### 4. Default action vs action buttons

Out of scope per the plan; only the default click (tapping the notification
body) is wired via `didReceive`. No `UNNotificationCategory` /
`UNNotificationAction` was added — `willPresent` and authorization flow are
untouched. Worth a follow-up: a "View Logs" explicit action button would let
users act without dismissing/expanding the banner, but requires registering
categories via `setNotificationCategories` at startup and giving the content
a `categoryIdentifier`, which is a larger surface than this spike's budget.

## Non-bundle guard

`notificationCenterIfAvailable()` in `MacNotificationRouter` is unchanged —
still returns `nil` (no-op) when `Bundle.main.bundleURL.pathExtension != "app"`,
which is what makes `swift test --parallel` safe to run without a real
`.app` bundle. All new code (userInfo attachment, `didReceive`) sits behind
that same guard: `notify` still returns early before constructing content if
the center isn't available, and `didReceive` only exists on
`NotificationCenterDelegate`, which is only ever assigned as
`UNUserNotificationCenter.current().delegate` inside that same guarded path.
Verified: `swift test --parallel` completed with exit code 0, 37 tests run
(including the new `testDeploymentTransitionNotificationCarriesProjectAndDeploymentUserInfo`),
no UNUserNotificationCenter-related exceptions.

## Manual click-through — pending operator

Per this run's constraints (never launch the app, never post real
notifications), the following must be verified manually by an operator with
a running `.app` bundle:

1. Trigger a real deploy failure (or success) notification.
2. Click the notification banner.
3. Confirm the app activates, the Deployment Logs window opens
   (`DeployBarWindow.logs`), and it shows the clicked project's current logs.
4. Confirm clicking a notification for a project that's no longer selected/
   watched is a silent no-op (per `openLogsForProject` returning `false` and
   the window not opening) rather than a crash or blank window.
