import AppKit
import Core
import SwiftUI

public struct MenuBarContentView: View {
    let store: DeployBarAppStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var expandedActionsProjectID: String?
    @State private var pendingCancelStatus: ProjectStatus?

    public init(store: DeployBarAppStore) {
        self.store = store
    }

    /// Used by previews and snapshot tests to render the expanded actions state.
    init(store: DeployBarAppStore, initiallyExpandedProjectID: String?) {
        self.store = store
        _expandedActionsProjectID = State(initialValue: initiallyExpandedProjectID)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            if store.requiresSetup {
                setupPrompt
                    .padding(.horizontal, 12)
            } else {
                projectList
            }

            if let error = store.monitorError {
                ErrorInlineBanner(message: error)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
            }

            footer
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(width: DesignSystem.popoverWidth)
        .onAppear { store.setMenuOpen(true) }
        .onDisappear { store.setMenuOpen(false) }
        .confirmationDialog(
            "Cancel Build?",
            isPresented: Binding(
                get: { pendingCancelStatus != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingCancelStatus = nil
                    }
                }
            ),
            presenting: pendingCancelStatus
        ) { status in
            Button("Cancel Build", role: .destructive) {
                let target = status
                Task { await store.cancelDeployment(for: target) }
            }
            Button("Keep Building", role: .cancel) {}
        } message: { status in
            Text("This stops the in-progress deployment for \(status.project.name). This action is irreversible.")
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DeployBar")
                    .font(.headline)

                Text(headerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Text(store.aggregateStatus.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Image(systemName: store.aggregateStatus.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(store.aggregateStatus.tint)
                    .symbolEffect(.pulse, isActive: store.aggregateStatus == .building)
            }
        }
    }

    private var setupPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.authStatusMessage ?? "Connect your Vercel account in Settings to start monitoring production deploys.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Open Settings") {
                openSettingsWindow()
            }
            .buttonStyle(.glassProminent)
            .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: .rect(cornerRadius: DesignSystem.cornerRadius))
    }

    @ViewBuilder
    private var projectList: some View {
        if !store.hasConfiguredProjects {
            emptyState(systemImage: "tray", message: "No projects configured")
        } else if !store.projectStatuses.isEmpty {
            VStack(spacing: 4) {
                if store.isAuthRetrying {
                    NoticeStrip(
                        systemImage: "arrow.triangle.2.circlepath",
                        message: store.authStatusMessage ?? "Reconnecting authentication…",
                        showsSpinner: true
                    )
                }

                if let cacheMessage {
                    NoticeStrip(systemImage: "clock.arrow.circlepath", message: cacheMessage)
                }

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(store.projectStatuses) { status in
                            let isExpanded = shouldShowInlineActions(for: status)

                            Group {
                                if isExpanded {
                                    DeploymentActionsRow(
                                        projectName: status.project.name,
                                        stage: status.snapshot?.stage ?? .unknown,
                                        onViewLogs: { openLogs(for: status) },
                                        onOpenOnline: { openOnline(for: status) },
                                        onOpenDashboard: { openDashboard(for: status) },
                                        onCancelBuild: { pendingCancelStatus = status },
                                        onCollapse: {
                                            withAnimation(.snappy(duration: 0.18)) {
                                                expandedActionsProjectID = nil
                                            }
                                        },
                                        canOpenOnline: status.snapshot?.url != nil,
                                        canOpenDashboard: projectDashboardURL(for: status) != nil,
                                        isCanceling: store.cancelingDeploymentID != nil
                                            && store.cancelingDeploymentID == status.snapshot?.id
                                    )
                                    .id("\(status.id)-actions")
                                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                } else {
                                    ProjectStatusRow(status: status) {
                                        handleProjectTap(status)
                                    }
                                    .id("\(status.id)-status")
                                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                }
                            }
                            .contextMenu {
                                if let stage = status.snapshot?.stage, stage == .ready || stage == .failed {
                                    Button("View Logs") { openLogs(for: status) }
                                    if status.snapshot?.url != nil {
                                        Button("Open Online") { openOnline(for: status) }
                                    }
                                    if projectDashboardURL(for: status) != nil {
                                        Button("Open Dashboard") { openDashboard(for: status) }
                                    }
                                }
                            }
                            .animation(.snappy(duration: 0.22), value: expandedActionsProjectID)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 360)
            }
        } else if store.isInitialRefreshInFlight {
            loadingState(message: "Syncing deployments…")
        } else if store.hasCompletedInitialRefresh {
            emptyState(systemImage: "clock.badge.questionmark", message: "No deployments yet")
        } else {
            loadingState(message: "Loading deployments…")
        }
    }

    private func emptyState(systemImage: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 20))
                .foregroundStyle(.tertiary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func loadingState(message: String) -> some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var footer: some View {
        HStack(spacing: 2) {
            Button {
                store.manualRefresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)

            Spacer()

            Button {
                openSettingsWindow()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .buttonStyle(.accessoryBar)
    }

    private var headerSubtitle: String {
        switch store.authConnectionState {
        case .loading:
            return "Checking saved token"
        case .setupRequired:
            return "Auth required"
        case let .retrying(reason):
            if store.isShowingCachedStatuses {
                return "\(reason) • cached"
            }
            return reason
        case .connected:
            break
        }

        guard let user = store.authUser else {
            return "Connected"
        }

        if store.isShowingCachedStatuses {
            let cacheLabel = store.isCachedStatusStale ? "cached (stale)" : "cached"
            return "@\(user.username) • \(cacheLabel)"
        }

        if store.isInitialRefreshInFlight, store.hasConfiguredProjects {
            return "@\(user.username) • syncing"
        }

        guard let lastRefreshAt = store.lastRefreshAt else {
            return "@\(user.username)"
        }

        return "@\(user.username) • \(smartRefreshLabel(for: lastRefreshAt))"
    }

    private func smartRefreshLabel(for date: Date) -> String {
        let age = Date().timeIntervalSince(date)
        if age < 8 {
            return "just now"
        }

        switch store.monitorCadence {
        case .inProgress:
            return "live monitoring"
        case .burst:
            return "high-frequency checks"
        case .menuOpen:
            return "menu-open refresh mode"
        case .active:
            return "recently updated"
        case .idle:
            return "idle checks"
        }
    }

    private var cacheMessage: String? {
        guard store.isShowingCachedStatuses else {
            return nil
        }

        if store.isCachedStatusStale {
            return "Showing stale cached statuses while refreshing live data."
        }

        return "Showing cached statuses while refreshing live data."
    }

    private func handleProjectTap(_ status: ProjectStatus) {
        guard let snapshot = status.snapshot else {
            openLogs(for: status)
            return
        }

        switch snapshot.stage {
        case .ready, .failed, .queued, .building:
            withAnimation(.snappy(duration: 0.2)) {
                if expandedActionsProjectID == status.id {
                    expandedActionsProjectID = nil
                } else {
                    expandedActionsProjectID = status.id
                }
            }
        default:
            expandedActionsProjectID = nil
        }
    }

    private func shouldShowInlineActions(for status: ProjectStatus) -> Bool {
        guard let stage = status.snapshot?.stage,
              stage == .ready || stage == .failed || stage == .queued || stage == .building
        else {
            return false
        }
        return expandedActionsProjectID == status.id
    }

    private func openSettingsWindow() {
        NSApp.activate()
        openSettings()
    }

    private func openLogs(for status: ProjectStatus) {
        expandedActionsProjectID = nil
        Task { await store.openLogs(for: status) }
        presentWindow(.logs, openWindow: openWindow)
    }

    private func openOnline(for status: ProjectStatus) {
        expandedActionsProjectID = nil
        guard let url = status.snapshot?.url else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func openDashboard(for status: ProjectStatus) {
        expandedActionsProjectID = nil
        guard let url = projectDashboardURL(for: status) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func projectDashboardURL(for status: ProjectStatus) -> URL? {
        VercelLinks.projectDashboardURL(
            project: status.project,
            teams: store.teams,
            username: store.authUser?.username
        )
    }
}

/// Compact relative timestamp ("45 min. ago") that refreshes once a minute.
///
/// The rendered string must depend on `TimelineView.Context.date`. Returning a
/// `Text` built only from the deployment date produces the same SwiftUI value on
/// every timeline tick, so the menu can keep showing the old relative time until
/// another interaction rebuilds the row.
private struct RelativeTimeText: View {
    let date: Date

    var body: some View {
        TimelineView(.everyMinute) { context in
            Text(relativeTimeLabel(for: date, relativeTo: context.date))
        }
    }
}

func relativeTimeLabel(
    for date: Date,
    relativeTo referenceDate: Date,
    locale: Locale = .current
) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = locale
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: referenceDate)
}

private struct NoticeStrip: View {
    let systemImage: String
    let message: String
    var showsSpinner: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if showsSpinner {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }
}

private struct DeploymentActionsRow: View {
    let projectName: String
    let stage: DeploymentStage
    let onViewLogs: () -> Void
    let onOpenOnline: () -> Void
    let onOpenDashboard: () -> Void
    let onCancelBuild: () -> Void
    let onCollapse: () -> Void
    let canOpenOnline: Bool
    let canOpenDashboard: Bool
    let isCanceling: Bool

    private var isInFlight: Bool {
        stage == .queued || stage == .building
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onCollapse) {
                HStack(spacing: 8) {
                    Text(projectName)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .background(.quaternary, in: .circle)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Collapse actions for \(projectName)")

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        onViewLogs()
                    } label: {
                        Label("Logs", systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)

                    if isInFlight {
                        Button(role: .destructive) {
                            onCancelBuild()
                        } label: {
                            Group {
                                if isCanceling {
                                    ProgressView()
                                        .controlSize(.mini)
                                } else {
                                    Label("Cancel Build", systemImage: "xmark.circle")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .disabled(isCanceling)
                    } else {
                        Button {
                            onOpenOnline()
                        } label: {
                            Label("Online", systemImage: "globe")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .disabled(!canOpenOnline)

                        Button {
                            onOpenDashboard()
                        } label: {
                            Label("Dashboard", systemImage: "rectangle.grid.2x2")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .disabled(!canOpenDashboard)
                    }
                }
            }
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: .rect(cornerRadius: DesignSystem.cornerRadius))
    }
}

private struct ProjectStatusRow: View {
    let status: ProjectStatus
    let onSelect: () -> Void
    @State private var isHovered = false

    private var stage: DeploymentStage {
        status.snapshot?.stage ?? .unknown
    }

    private var canSelect: Bool {
        stage == .failed || stage == .ready || stage == .queued || stage == .building
    }

    var body: some View {
        let row = HStack(spacing: 10) {
            StatusDot(stage: stage)

            VStack(alignment: .leading, spacing: 2) {
                Text(status.project.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                if let message = status.snapshot?.commitMessage, !message.isEmpty {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                StatusPill(stage: stage)

                if let snapshot = status.snapshot {
                    RelativeTimeText(date: snapshot.createdAt)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Fixed slot so status pills stay trailing-aligned across all rows.
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .opacity(canSelect ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
            in: .rect(cornerRadius: DesignSystem.rowCornerRadius)
        )
        .contentShape(.rect(cornerRadius: DesignSystem.rowCornerRadius))

        if canSelect {
            Button(action: onSelect) { row }
                .buttonStyle(.plain)
                .onHover { isHovered = $0 }
                .accessibilityHint("Shows deployment actions.")
        } else {
            row
                .onHover { isHovered = $0 }
        }
    }
}
