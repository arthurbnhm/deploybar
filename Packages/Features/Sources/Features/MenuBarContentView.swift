import AppKit
import Core
import SwiftUI

public struct MenuBarContentView: View {
    @ObservedObject var store: DeployBarAppStore
    @Environment(\.openWindow) private var openWindow

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
        .sheet(isPresented: Binding(
            get: { store.showingLogs },
            set: { newValue in
                if !newValue { store.closeLogs() }
            }
        )) {
            LogsView(store: store)
        }
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
                        ProjectStatusRow(status: status) {
                            Task { await store.openLogs(for: status) }
                        }
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
}

private struct ProjectStatusRow: View {
    let status: ProjectStatus
    let onLogs: () -> Void
    @State private var isHovered = false

    private var stage: DeploymentStage {
        status.snapshot?.stage ?? .unknown
    }

    private var canOpenLogs: Bool {
        stage == .failed
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

        if canOpenLogs {
            Button(action: onLogs) { row }
                .buttonStyle(.plain)
                .onHover { isHovered = $0 }
        } else {
            row
                .onHover { isHovered = $0 }
        }
    }
}
