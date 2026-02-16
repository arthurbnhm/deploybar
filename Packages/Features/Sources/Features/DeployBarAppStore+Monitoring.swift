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
            return
        }

        monitorTask = Task { [weak self] in
            guard let self else { return }

            var nextDelay: TimeInterval = immediate ? 0 : self.settings.pollingProfile.activeInterval

            while !Task.isCancelled {
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

            projectStatuses = update.statuses.sorted { lhs, rhs in
                switch (lhs.snapshot?.createdAt, rhs.snapshot?.createdAt) {
                case let (leftDate?, rightDate?):
                    if leftDate != rightDate {
                        return leftDate > rightDate
                    }
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    break
                }

                return lhs.project.name.localizedCaseInsensitiveCompare(rhs.project.name) == .orderedAscending
            }
            aggregateStatus = update.aggregateStatus
            monitorCadence = update.cadence
            monitorError = nil
            lastRefreshAt = Date()

            try await env.eventStore.purge(olderThan: Date().addingTimeInterval(-7 * 24 * 60 * 60))
            await handleTransitions(update.transitions)

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
                monitorError = "Token revoked or unauthorized. Reconnect your Vercel token."
                monitorCadence = .idle
                try? env.tokenStore.clearToken()
                await env.monitoringEngine.resetState()
                authUser = nil
                tokenNotice = nil
                enterSetupRequiredState()
                return settings.pollingProfile.idleInterval
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
}
