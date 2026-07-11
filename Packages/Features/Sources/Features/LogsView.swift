import AppKit
import Core
import SwiftUI

public struct LogsView: View {
    let store: DeployBarAppStore

    public init(store: DeployBarAppStore) {
        self.store = store
    }

    public var body: some View {
        content
            .frame(minWidth: 640, minHeight: 400)
            .navigationTitle(store.selectedLogsProject?.name ?? "Deployment Logs")
            .navigationSubtitle(subtitle)
            .toolbar {
                toolbarContent
            }
            .onDisappear {
                store.closeLogs()
            }
    }

    private var subtitle: String {
        if let deployment = store.selectedLogsDeployment {
            return "Deployment \(deployment.id)"
        }
        return "Recent deployment events"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if let snapshot = store.selectedLogsDeployment {
            ToolbarItem {
                StatusPill(stage: snapshot.stage)
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarSpacer(.fixed)
        }

        ToolbarItemGroup {
            Button {
                openOnline()
            } label: {
                Label("Open Online", systemImage: "globe")
            }
            .disabled(store.selectedLogsDeployment?.url == nil)
            .help("Open the deployment in your browser")

            Button {
                openDashboard()
            } label: {
                Label("Open Dashboard", systemImage: "rectangle.grid.2x2")
            }
            .disabled(projectDashboardURL == nil)
            .help("Open the project on the Vercel dashboard")
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoadingLogs {
            VStack(spacing: 12) {
                ProgressView()

                Text("Loading logs…")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.logEvents.isEmpty {
            ContentUnavailableView(
                "No Logs",
                systemImage: "doc.text.magnifyingglass",
                description: Text("No log entries found for this deployment.")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(store.logEvents.enumerated()), id: \.element.id) { index, event in
                        LogRow(event: event, isAlternate: !index.isMultiple(of: 2))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack {
                    Text("\(store.logEvents.count) events")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.bar)
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
}

private struct LogRow: View {
    let event: DeploymentEvent
    let isAlternate: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(event.createdAt, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)

            Text(event.level.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .foregroundStyle(levelColor)
                .background(levelColor.opacity(0.14), in: .capsule)
                .frame(width: 62, alignment: .leading)

            Text(event.message)
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            isAlternate ? AnyShapeStyle(.quinary) : AnyShapeStyle(.clear),
            in: .rect(cornerRadius: 4)
        )
    }

    private var levelColor: Color {
        switch event.level.lowercased() {
        case "error", "fatal", "stderr":
            .red
        case "warning", "warn":
            .orange
        case "info", "stdout":
            .blue
        case "debug", "verbose":
            .purple
        default:
            .secondary
        }
    }
}
