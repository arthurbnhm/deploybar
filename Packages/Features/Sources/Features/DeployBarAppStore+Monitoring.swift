import Core
import Foundation

@MainActor
extension DeployBarAppStore {
    public func setMenuOpen(_ open: Bool) {
        let wasOpen = menuIsOpen
        menuIsOpen = open

        guard phase == .running else {
            return
        }

        if open, !wasOpen {
            startMonitoringLoop(immediate: true)
        }
    }

    public func manualRefresh() {
        guard phase == .running else {
            return
        }
        startMonitoringLoop(immediate: true)
    }

    public func updatePollingProfile(_ profile: PollingProfile) {
        settings.pollingProfile = profile
        persistSettings()
        if phase == .running {
            startMonitoringLoop(immediate: true)
        }
    }

    public func updateNotificationsEnabled(_ enabled: Bool) {
        let wasEnabled = settings.notificationsEnabled
        settings.notificationsEnabled = enabled
        persistSettings()
        triggerNotificationTestIfJustEnabled(wasEnabled: wasEnabled, isEnabled: enabled)
    }

    public func updateSoundsEnabled(_ enabled: Bool) {
        settings.soundsEnabled = enabled
        persistSettings()
    }

    public func updateLaunchAtLogin(_ enabled: Bool) {
        let previousValue = settings.launchAtLogin
        do {
            try env.launchAtLogin.setEnabled(enabled)
            settings.launchAtLogin = env.launchAtLogin.status()
            persistSettings()
            monitorError = nil
        } catch {
            settings.launchAtLogin = previousValue
            monitorError = error.localizedDescription
        }
    }

    func startMonitoringLoop(immediate: Bool) {
        monitorTask?.cancel()

        guard !settings.watchedProjects.isEmpty else {
            monitorTask = nil
            projectStatuses = []
            aggregateStatus = .unknown
            monitorCadence = .idle
            lastRefreshAt = nil
            isInitialRefreshInFlight = false
            hasCompletedInitialRefresh = false
            isShowingCachedStatuses = false
            cachedStatusAge = nil
            return
        }

        monitorTask = Task { [weak self] in
            var nextDelay: TimeInterval = immediate ? 0 : self?.settings.pollingProfile.activeInterval ?? 0

            while !Task.isCancelled {
                guard let self else {
                    break
                }

                if nextDelay > 0 {
                    let nanos = UInt64(nextDelay * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: nanos)
                }

                if Task.isCancelled {
                    break
                }

                nextDelay = await self.performRefreshCycle()
            }
        }
    }

    func performRefreshCycle() async -> TimeInterval {
        guard phase == .running else {
            return settings.pollingProfile.idleInterval
        }

        do {
            let update = try await env.monitoringEngine.refresh(
                projects: settings.watchedProjects,
                profile: settings.pollingProfile,
                menuIsOpen: menuIsOpen
            )

            guard phase == .running else {
                return settings.pollingProfile.idleInterval
            }

            projectStatuses = sortedProjectStatuses(update.statuses)
            aggregateStatus = update.aggregateStatus
            monitorCadence = update.cadence
            monitorError = nil
            lastRefreshAt = Date()
            clearTransientAuthFailuresIfNeeded()
            isInitialRefreshInFlight = false
            hasCompletedInitialRefresh = true
            isShowingCachedStatuses = false
            cachedStatusAge = 0
            persistStatusCache(from: projectStatuses, refreshedAt: lastRefreshAt ?? Date())

            if authUser == nil,
               let recoveredUser = try? await env.vercelClient.validateToken()
            {
                authUser = recoveredUser
            }

            if authUser != nil {
                authConnectionState = .connected
                tokenError = nil
            }

            await handleTransitions(update.transitions)
            await env.monitoringEngine.markNotified(update.transitions)
            await purgeOldEventsIfDue()

            return update.nextDelay
        } catch let error as DeployBarError {
            guard phase == .running else {
                return settings.pollingProfile.idleInterval
            }

            switch error {
            case let .rateLimited(resetAt):
                monitorError = error.localizedDescription
                monitorCadence = .idle
                return max(3, resetAt.timeIntervalSinceNow)
            case .unauthorized:
                await handleHardAuthFailure(
                    message: "Token revoked or unauthorized. Reconnect your Vercel token.",
                    clearStoredToken: true
                )
                return settings.pollingProfile.idleInterval
            case .missingToken:
                return registerTransientAuthFailure(
                    reason: monitoringRetryReason(for: error),
                    escalateMessage: "Saved token is unavailable. Reconnect your Vercel token."
                )
            case .persistence:
                if isTransientKeychainAccessError(error) {
                    return registerTransientAuthFailure(
                        reason: monitoringRetryReason(for: error),
                        escalateMessage: "Saved token is unavailable. Reconnect your Vercel token."
                    )
                }
                monitorError = error.localizedDescription
                return settings.pollingProfile.activeInterval
            default:
                monitorError = error.localizedDescription
                return settings.pollingProfile.activeInterval
            }
        } catch is CancellationError {
            return settings.pollingProfile.activeInterval
        } catch {
            guard phase == .running else {
                return settings.pollingProfile.idleInterval
            }

            if isTransientKeychainAccessError(error) {
                return registerTransientAuthFailure(
                    reason: monitoringRetryReason(for: error),
                    escalateMessage: "Saved token is unavailable. Reconnect your Vercel token."
                )
            }

            monitorError = error.localizedDescription
            return settings.pollingProfile.activeInterval
        }
    }

    func handleTransitions(_ transitions: [DeploymentTransition]) async {
        await TransitionNotificationService.process(
            transitions: transitions,
            settings: settings,
            notificationRouter: env.notificationRouter,
            soundPlayer: env.soundPlayer
        )
    }

    private func purgeOldEventsIfDue() async {
        let purgeInterval: TimeInterval = 60 * 60
        if let lastEventPurgeAt, Date().timeIntervalSince(lastEventPurgeAt) < purgeInterval {
            return
        }
        lastEventPurgeAt = Date()
        try? await env.eventStore.purge(olderThan: Date().addingTimeInterval(-7 * 24 * 60 * 60))
    }

    func persistStatusCache(from statuses: [ProjectStatus], refreshedAt: Date) {
        let cachedStatuses = statuses.map { status in
            CachedProjectStatus(
                project: status.project,
                snapshot: status.snapshot,
                lastUpdatedAt: status.lastUpdatedAt
            )
        }

        let shouldWriteStatuses = cachedStatuses != settings.cachedProjectStatuses
        let shouldWriteTimestamp: Bool
        if let previous = settings.statusCacheUpdatedAt {
            shouldWriteTimestamp = refreshedAt.timeIntervalSince(previous) >= 60
        } else {
            shouldWriteTimestamp = true
        }

        guard shouldWriteStatuses || shouldWriteTimestamp else {
            return
        }

        settings.cachedProjectStatuses = cachedStatuses
        settings.statusCacheUpdatedAt = refreshedAt
        persistSettings()
    }
}
