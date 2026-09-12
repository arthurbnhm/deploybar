import Core
import Foundation

@MainActor
extension DeployBarAppStore {
    public func openLogs(for status: ProjectStatus) async {
        guard !isDisconnecting, !isValidatingToken else { return }
        guard let snapshot = status.snapshot else {
            monitorError = "No deployment available yet for this project."
            return
        }

        stopLogsTail()
        let generation = logsTailGeneration
        let session = sessionGeneration

        selectedLogsProject = status.project
        selectedLogsDeployment = snapshot
        isLoadingLogs = true

        defer {
            if generation == logsTailGeneration { isLoadingLogs = false }
        }

        var initialSinceMs: Int?

        do {
            let freshEvents = try await env.vercelClient.deploymentEvents(
                deploymentId: snapshot.id,
                limit: 250,
                since: nil
            )

            guard logsAreCurrent(generation, session: session) else { return }
            if !freshEvents.isEmpty {
                try await persistLogEvents(freshEvents)
                initialSinceMs = freshEvents.map { epochMs($0.createdAt) }.max()
            }

            let loaded = try await env.eventStore.load(deploymentId: snapshot.id, limit: 300)
            guard logsAreCurrent(generation, session: session) else { return }
            logEvents = loaded
        } catch {
            guard logsAreCurrent(generation, session: session) else { return }
            monitorError = error.localizedDescription
            if let cached = try? await env.eventStore.load(deploymentId: snapshot.id, limit: 300) {
                guard logsAreCurrent(generation, session: session) else { return }
                logEvents = cached
            } else {
                guard logsAreCurrent(generation, session: session) else { return }
                logEvents = []
            }
        }

        guard logsAreCurrent(generation, session: session) else { return }
        isLoadingLogs = false
        if snapshot.stage.isInFlight {
            startLogsTail(deploymentId: snapshot.id, projectId: status.project.id, sinceMs: initialSinceMs)
        }
    }

    /// Resolves a project by id against the live `projectStatuses` (not the
    /// notified deployment id) and opens its current logs. A notification's
    /// deployment may no longer be the project's latest by the time it's
    /// clicked, so this intentionally shows the current state rather than
    /// pinning to the stale notified deployment.
    @discardableResult
    public func openLogsForProject(id: String) async -> Bool {
        guard let status = projectStatuses.first(where: { $0.project.id == id }) else {
            return false
        }

        let session = sessionGeneration
        await openLogs(for: status)
        return isCurrentSession(session) && selectedLogsProject?.id == id
    }

    /// Cancels an in-flight (`queued`/`building`) deployment, then forces a refresh so the
    /// popover reflects the new state. A 403 (token lacks write scope) is surfaced as a
    /// user-facing message without clearing the stored token or dropping the auth session —
    /// only `.unauthorized`/`.invalidToken` do that (see `shouldClearStoredToken`).
    public func cancelDeployment(for status: ProjectStatus) async {
        guard !isDisconnecting, !isValidatingToken else { return }
        let session = sessionGeneration
        guard let snapshot = status.snapshot, snapshot.stage == .queued || snapshot.stage == .building else {
            return
        }

        cancelingDeploymentID = snapshot.id
        defer { if session == sessionGeneration { cancelingDeploymentID = nil } }

        do {
            try await env.vercelClient.cancelDeployment(deploymentId: snapshot.id, teamId: status.project.teamId)
            guard isCurrentSession(session) else { return }
            monitorError = nil
        } catch {
            guard isCurrentSession(session) else { return }
            monitorError = error.localizedDescription
        }

        manualRefresh()
    }

    public func closeLogs() {
        stopLogsTail()
        selectedLogsProject = nil
        selectedLogsDeployment = nil
        logEvents = []
        isLoadingLogs = false
    }

    /// Starts a background loop that polls `deploymentEvents(since:)` for the tailed deployment
    /// while it remains in flight, appending newly observed events to `logEvents`.
    ///
    /// The loop is intentionally independent of `monitorTask`: it runs on its own cadence
    /// (`logsTailInterval`, default 2s) and only exists while the Logs window is open on an
    /// in-flight deployment.
    func startLogsTail(deploymentId: String, projectId: String, sinceMs: Int?) {
        logsTailTask?.cancel()
        isTailingLogs = true

        // Bump the generation so a not-yet-cancelled prior loop's deferred cleanup (which runs
        // asynchronously, possibly after this new task is already assigned) can recognize it has
        // been superseded and avoid clobbering `logsTailTask`/`isTailingLogs`.
        logsTailGeneration += 1
        let generation = logsTailGeneration
        let session = sessionGeneration

        logsTailTask = Task { [weak self] in
            await self?.runLogsTailLoop(
                deploymentId: deploymentId,
                projectId: projectId,
                initialSinceMs: sinceMs,
                generation: generation,
                session: session
            )
        }
    }

    func stopLogsTail() {
        logsTailGeneration += 1
        logsTailTask?.cancel()
        logsTailTask = nil
        isTailingLogs = false
    }

    private func logsAreCurrent(_ generation: Int, session: Int) -> Bool {
        generation == logsTailGeneration && isCurrentSession(session)
    }

    private func runLogsTailLoop(deploymentId: String, projectId: String, initialSinceMs: Int?, generation: Int, session: Int) async {
        var sinceMs = initialSinceMs
        var interval = logsTailInterval

        while logsAreCurrent(generation, session: session) {
            await sleep(seconds: interval)

            if !logsAreCurrent(generation, session: session) {
                break
            }

            do {
                let freshEvents = try await env.vercelClient.deploymentEvents(
                    deploymentId: deploymentId,
                    limit: 100,
                    since: sinceMs
                )

                guard logsAreCurrent(generation, session: session) else { break }
                if !freshEvents.isEmpty {
                    try await persistLogEvents(freshEvents)
                    let loaded = try await env.eventStore.load(deploymentId: deploymentId, limit: 300)
                    guard logsAreCurrent(generation, session: session) else { break }
                    logEvents = loaded
                    if let newestMs = freshEvents.map({ epochMs($0.createdAt) }).max() {
                        sinceMs = max(sinceMs ?? 0, newestMs)
                    }
                }

                // Reset the backoff after any successful poll.
                interval = logsTailInterval

                // Re-resolve the tailed project's stage from the live monitoring snapshot rather
                // than trusting `selectedLogsDeployment`, which is only ever set once at open time.
                // Gap: if the project is unwatched mid-tail, it drops out of `projectStatuses`
                // entirely and `resolvedStage` becomes nil here, which we treat the same as
                // terminal (stop tailing) since there is no further signal to poll against.
                let resolvedStage = projectStatuses.first(where: { $0.project.id == projectId })?.snapshot?.stage

                if resolvedStage == nil || resolvedStage!.isTerminal {
                    await performFinalCatchUpFetch(deploymentId: deploymentId, sinceMs: sinceMs, generation: generation, session: session)
                    guard logsAreCurrent(generation, session: session) else { break }

                    if let resolvedStage, let existing = selectedLogsDeployment, existing.id == deploymentId {
                        selectedLogsDeployment = DeploymentSnapshot(
                            id: existing.id,
                            projectId: existing.projectId,
                            stage: resolvedStage,
                            createdAt: existing.createdAt,
                            url: existing.url,
                            commitMessage: existing.commitMessage
                        )
                    }
                    break
                }
            } catch is CancellationError {
                break
            } catch let error as DeployBarError {
                guard logsAreCurrent(generation, session: session) else { break }
                if case let .rateLimited(resetAt) = error {
                    await sleep(seconds: max(0, resetAt.timeIntervalSinceNow))
                } else {
                    // Transient failure: back off and keep tailing rather than giving up.
                    interval = 5.0
                }
            } catch {
                guard logsAreCurrent(generation, session: session) else { break }
                interval = 5.0
            }
        }

        // Only clear shared state if a newer tail session hasn't already superseded this one.
        if logsTailGeneration == generation {
            isTailingLogs = false
            logsTailTask = nil
        }
    }

    private func performFinalCatchUpFetch(deploymentId: String, sinceMs: Int?, generation: Int, session: Int) async {
        guard let finalEvents = try? await env.vercelClient.deploymentEvents(
            deploymentId: deploymentId,
            limit: 100,
            since: sinceMs
        ), !finalEvents.isEmpty else {
            return
        }

        guard logsAreCurrent(generation, session: session) else { return }
        try? await persistLogEvents(finalEvents)
        if let reloaded = try? await env.eventStore.load(deploymentId: deploymentId, limit: 300) {
            guard logsAreCurrent(generation, session: session) else { return }
            logEvents = reloaded
        }
    }

    private func epochMs(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970 * 1000)
    }

    private func persistLogEvents(_ events: [DeploymentEvent]) async throws {
        let id = UUID()
        let eventStore = env.eventStore
        let write = Task { try await eventStore.persist(events: events) }
        logWrites[id] = write
        defer { logWrites[id] = nil }
        try await write.value
    }

    func drainLogWrites() async {
        // Invalidation prevents new writes. Finish writes already admitted before clearing,
        // including stores that suspend internally or reorder actor work.
        let pending = Array(logWrites.values)
        for write in pending { _ = await write.result }
    }

    private func sleep(seconds: TimeInterval) async {
        guard seconds > 0 else {
            return
        }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    public func disconnectAccount() async {
        guard !isDisconnecting else { return }
        isDisconnecting = true
        invalidateSession()
        isValidatingToken = false
        authUser = nil
        enterSetupRequiredState(authReason: Self.defaultTokenPrompt)
        defer { isDisconnecting = false }

        var cleanupErrors: [String] = []
        do {
            try env.tokenStore.clearToken()
        } catch {
            cleanupErrors.append(error.localizedDescription)
        }

        do {
            try env.settingsStore.clear()
        } catch {
            cleanupErrors.append(error.localizedDescription)
        }

        await drainLogWrites()
        do {
            try await env.eventStore.clear()
        } catch {
            cleanupErrors.append(error.localizedDescription)
        }

        await env.monitoringEngine.resetState()

        authUser = nil
        teams = []
        availableProjects = []
        selectedProjectIDs = []
        selectedScope = .personal
        settings = AppSettings()
        tokenError = nil
        tokenNotice = cleanupErrors.isEmpty
            ? "Disconnected from Vercel and cleared local DeployBar data."
            : "Disconnected from Vercel, but some local data could not be cleared."
        monitorError = cleanupErrors.first
        closeLogs()
        enterSetupRequiredState(authReason: Self.defaultTokenPrompt)
    }
}
