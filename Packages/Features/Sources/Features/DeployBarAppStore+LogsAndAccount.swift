import Core
import Foundation

@MainActor
extension DeployBarAppStore {
    public func openLogs(for status: ProjectStatus) async {
        guard let snapshot = status.snapshot else {
            monitorError = "No deployment available yet for this project."
            return
        }

        stopLogsTail()

        selectedLogsProject = status.project
        selectedLogsDeployment = snapshot
        isLoadingLogs = true

        defer {
            isLoadingLogs = false
        }

        var initialSinceMs: Int?

        do {
            let freshEvents = try await env.vercelClient.deploymentEvents(
                deploymentId: snapshot.id,
                limit: 250,
                since: nil
            )

            if !freshEvents.isEmpty {
                try await env.eventStore.persist(events: freshEvents)
                initialSinceMs = freshEvents.map { epochMs($0.createdAt) }.max()
            }

            logEvents = try await env.eventStore.load(deploymentId: snapshot.id, limit: 300)
        } catch {
            monitorError = error.localizedDescription
            if let cached = try? await env.eventStore.load(deploymentId: snapshot.id, limit: 300) {
                logEvents = cached
            } else {
                logEvents = []
            }
        }

        if snapshot.stage.isInFlight {
            startLogsTail(deploymentId: snapshot.id, projectId: status.project.id, sinceMs: initialSinceMs)
        }
    }

    public func closeLogs() {
        stopLogsTail()
        selectedLogsProject = nil
        selectedLogsDeployment = nil
        logEvents = []
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

        logsTailTask = Task { [weak self] in
            await self?.runLogsTailLoop(
                deploymentId: deploymentId,
                projectId: projectId,
                initialSinceMs: sinceMs,
                generation: generation
            )
        }
    }

    func stopLogsTail() {
        logsTailTask?.cancel()
        logsTailTask = nil
        isTailingLogs = false
    }

    private func runLogsTailLoop(deploymentId: String, projectId: String, initialSinceMs: Int?, generation: Int) async {
        var sinceMs = initialSinceMs
        var interval = logsTailInterval

        while !Task.isCancelled {
            await sleep(seconds: interval)

            if Task.isCancelled {
                break
            }

            do {
                let freshEvents = try await env.vercelClient.deploymentEvents(
                    deploymentId: deploymentId,
                    limit: 100,
                    since: sinceMs
                )

                if !freshEvents.isEmpty {
                    try await env.eventStore.persist(events: freshEvents)
                    logEvents = try await env.eventStore.load(deploymentId: deploymentId, limit: 300)
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
                    await performFinalCatchUpFetch(deploymentId: deploymentId, sinceMs: sinceMs)

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
                if case let .rateLimited(resetAt) = error {
                    await sleep(seconds: max(0, resetAt.timeIntervalSinceNow))
                } else {
                    // Transient failure: back off and keep tailing rather than giving up.
                    interval = 5.0
                }
            } catch {
                interval = 5.0
            }
        }

        // Only clear shared state if a newer tail session hasn't already superseded this one.
        if logsTailGeneration == generation {
            isTailingLogs = false
            logsTailTask = nil
        }
    }

    private func performFinalCatchUpFetch(deploymentId: String, sinceMs: Int?) async {
        guard let finalEvents = try? await env.vercelClient.deploymentEvents(
            deploymentId: deploymentId,
            limit: 100,
            since: sinceMs
        ), !finalEvents.isEmpty else {
            return
        }

        try? await env.eventStore.persist(events: finalEvents)
        if let reloaded = try? await env.eventStore.load(deploymentId: deploymentId, limit: 300) {
            logEvents = reloaded
        }
    }

    private func epochMs(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970 * 1000)
    }

    private func sleep(seconds: TimeInterval) async {
        guard seconds > 0 else {
            return
        }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    public func disconnectAccount() async {
        monitorTask?.cancel()
        monitorTask = nil

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
