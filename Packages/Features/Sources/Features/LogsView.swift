import AppKit
import Core
import SwiftUI

public struct LogsView: View {
    @ObservedObject var store: DeployBarAppStore

    public init(store: DeployBarAppStore) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            GlassBackgroundView(material: .hudWindow)
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.white.opacity(0.04), Color.black.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            NavigationStack {
                Group {
                    if store.isLoadingLogs {
                        VStack(spacing: 12) {
                            ProgressView().controlSize(.large)
                            Text("Loading logs…")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    } else if store.logEvents.isEmpty {
                        ContentUnavailableView(
                            "No Logs",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("No log entries found for this deployment.")
                        )
                    } else {
                        logList
                    }
                }
                .navigationTitle(store.selectedLogsProject?.name ?? "Logs")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { store.closeLogs() }
                    }

                    if let snapshot = store.selectedLogsDeployment {
                        ToolbarItem(placement: .automatic) {
                            StatusPill(stage: snapshot.stage)
                        }
                    }

                    if let url = store.selectedLogsDeployment?.url {
                        ToolbarItem(placement: .primaryAction) {
                            Link(destination: url) {
                                Label("Open in Vercel", systemImage: "arrow.up.right.square")
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .frame(minWidth: 760, minHeight: 520)
        .background(WindowChromeConfigurator())
    }

    private var logList: some View {
        List(store.logEvents) { event in
            HStack(alignment: .top, spacing: 10) {
                Text(event.createdAt, style: .time)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 72, alignment: .trailing)

                Text(event.level.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(levelColor(event.level).opacity(0.15))
                    .foregroundStyle(levelColor(event.level))
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .frame(width: 48)

                Text(event.message)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(nil)
            }
            .padding(.vertical, 2)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func levelColor(_ level: String) -> Color {
        switch level.lowercased() {
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
