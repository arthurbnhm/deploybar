import AppKit
import Core
import SwiftUI

public struct LogsView: View {
    @ObservedObject var store: DeployBarAppStore
    @Environment(\.dismissWindow) private var dismissWindow

    public init(store: DeployBarAppStore) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [DesignSystem.windowLightTop, DesignSystem.windowLightBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.white.opacity(0.65), Color.clear],
                center: .topLeading,
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                headerCard

                AppCard {
                    Group {
                        if store.isLoadingLogs {
                            VStack(spacing: 12) {
                                ProgressView().controlSize(.large)
                                Text("Loading logs…")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if store.logEvents.isEmpty {
                            ContentUnavailableView(
                                "No Logs",
                                systemImage: "doc.text.magnifyingglass",
                                description: Text("No log entries found for this deployment.")
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            logList
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(16)
        }
        .frame(minWidth: 760, minHeight: 520)
        .background(WindowChromeConfigurator())
    }

    private var headerCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.selectedLogsProject?.name ?? "Deployment Logs")
                            .font(.system(size: 19, weight: .bold))

                        if let deployment = store.selectedLogsDeployment {
                            Text("Deployment \(deployment.id)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        } else {
                            Text("Recent deployment events")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if let snapshot = store.selectedLogsDeployment {
                        StatusPill(stage: snapshot.stage)
                    }

                    Button("Close") {
                        store.closeLogs()
                        dismissWindow(id: DeployBarWindow.logs.rawValue)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                HStack(spacing: 8) {
                    Button {
                        openOnline()
                    } label: {
                        Label("Open Online", systemImage: "globe")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.selectedLogsDeployment?.url == nil)

                    Button {
                        openDashboard()
                    } label: {
                        Label("Open Dashboard", systemImage: "rectangle.grid.2x2")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .disabled(projectDashboardURL == nil)

                    Text("\(store.logEvents.count) events")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    private var projectDashboardURL: URL? {
        guard let project = store.selectedLogsProject else {
            return nil
        }
        return VercelLinks.projectDashboardURL(
            project: project,
            teams: store.teams,
            username: store.authUser?.username
        )
    }

    private func openOnline() {
        guard let url = store.selectedLogsDeployment?.url else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func openDashboard() {
        guard let url = projectDashboardURL else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private var logList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(store.logEvents.enumerated()), id: \.element.id) { index, event in
                    LogRow(event: event)

                    if index < store.logEvents.count - 1 {
                        SubtleDivider()
                            .padding(.vertical, 2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LogRow: View {
    let event: DeploymentEvent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(event.createdAt, style: .time)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)

            Text(event.level.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(levelColor(event.level).opacity(0.16))
                .foregroundStyle(levelColor(event.level))
                .clipShape(Capsule(style: .continuous))
                .frame(width: 62, alignment: .leading)

            Text(event.message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
    }

    private func levelColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "error", "fatal", "stderr":
            return .red
        case "warning", "warn":
            return .orange
        case "info", "stdout":
            return .blue
        case "debug", "verbose":
            return .purple
        default:
            return .secondary
        }
    }
}
