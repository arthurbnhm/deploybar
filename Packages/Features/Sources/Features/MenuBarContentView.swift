import AppKit
import Core
import SwiftUI

public struct MenuBarContentView: View {
    @ObservedObject var store: DeployBarAppStore
    @Environment(\.openWindow) private var openWindow
    @State private var expandedReadyActionsProjectID: String?

    public init(store: DeployBarAppStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

            SubtleDivider()

            if store.phase != .running {
                onboardingPrompt
                    .padding(14)
            } else {
                projectList
            }

            if let error = store.monitorError {
                ErrorInlineBanner(message: error)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            SubtleDivider()

            footer
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .frame(width: 420)
        .onAppear { store.setMenuOpen(true) }
        .onDisappear { store.setMenuOpen(false) }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DeployBar")
                    .font(.system(size: 13, weight: .semibold))

                Text(headerSubtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Text(store.aggregateStatus.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Image(systemName: store.aggregateStatus.symbolName)
                    .font(.system(size: 16))
                    .foregroundStyle(store.aggregateStatus.tint)
                    .symbolEffect(.pulse, isActive: store.aggregateStatus == .building)
            }
        }
    }

    private var onboardingPrompt: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Set up DeployBar to start monitoring your Vercel production deploys.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Button("Open Setup") {
                    presentWindow(.main, openWindow: openWindow)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var projectList: some View {
        if store.projectStatuses.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
                Text("No projects configured")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(store.projectStatuses) { status in
                        VStack(spacing: 6) {
                            ProjectStatusRow(status: status) {
                                handleProjectTap(status)
                            }

                            if shouldShowInlineActions(for: status) {
                                ReadyDeploymentActionsRow(
                                    onViewLogs: { openLogs(for: status) },
                                    onOpenOnline: { openOnline(for: status) },
                                    onOpenDashboard: { openDashboard(for: status) },
                                    canOpenDashboard: projectDashboardURL(for: status) != nil
                                )
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .animation(.snappy(duration: 0.2), value: expandedReadyActionsProjectID)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 340)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                store.manualRefresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .controlSize(.small)

            Spacer()

            Button {
                presentWindow(.settings, openWindow: openWindow)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .controlSize(.small)

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "xmark.circle")
            }
            .controlSize(.small)
        }
        .buttonStyle(.borderless)
        .font(.system(size: 12))
    }

    private var headerSubtitle: String {
        guard let user = store.authUser else {
            return "Waiting for auth"
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

    private func handleProjectTap(_ status: ProjectStatus) {
        guard let snapshot = status.snapshot else {
            openLogs(for: status)
            return
        }

        switch snapshot.stage {
        case .ready:
            withAnimation(.snappy(duration: 0.2)) {
                if expandedReadyActionsProjectID == status.id {
                    expandedReadyActionsProjectID = nil
                } else {
                    expandedReadyActionsProjectID = status.id
                }
            }
        case .failed:
            expandedReadyActionsProjectID = nil
            openLogs(for: status)
        default:
            expandedReadyActionsProjectID = nil
            break
        }
    }

    private func shouldShowInlineActions(for status: ProjectStatus) -> Bool {
        guard status.snapshot?.stage == .ready else {
            return false
        }
        return expandedReadyActionsProjectID == status.id
    }

    private func openLogs(for status: ProjectStatus) {
        expandedReadyActionsProjectID = nil
        Task { await store.openLogs(for: status) }
        presentWindow(.logs, openWindow: openWindow)
    }

    private func openOnline(for status: ProjectStatus) {
        expandedReadyActionsProjectID = nil
        guard let url = status.snapshot?.url else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func openDashboard(for status: ProjectStatus) {
        expandedReadyActionsProjectID = nil
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

private struct ReadyDeploymentActionsRow: View {
    let onViewLogs: () -> Void
    let onOpenOnline: () -> Void
    let onOpenDashboard: () -> Void
    let canOpenDashboard: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button {
                onViewLogs()
            } label: {
                Label("View Logs", systemImage: "doc.text.magnifyingglass")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                onOpenOnline()
            } label: {
                Label("Open Online", systemImage: "globe")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                onOpenDashboard()
            } label: {
                Label("Dashboard", systemImage: "rectangle.grid.2x2")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!canOpenDashboard)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
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
        stage == .failed || stage == .ready
    }

    var body: some View {
        let row = HStack(spacing: 10) {
            StatusDot(stage: stage)

            VStack(alignment: .leading, spacing: 2) {
                Text(status.project.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                if let message = status.snapshot?.commitMessage, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                StatusPill(stage: stage)

                if let snapshot = status.snapshot {
                    Text(snapshot.createdAt, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? DesignSystem.rowHoverFill : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

        if canSelect {
            Button(action: onSelect) { row }
                .buttonStyle(.plain)
                .onHover { isHovered = $0 }
        } else {
            row
                .onHover { isHovered = $0 }
        }
    }
}
