import Core
import SwiftUI

public struct DeployBarSettingsView: View {
    @ObservedObject var store: DeployBarAppStore

    public init(store: DeployBarAppStore) {
        self.store = store
    }

    public var body: some View {
        TabView {
            ProjectsSettingsPane(store: store)
                .tabItem { Label("Projects", systemImage: "shippingbox.fill") }

            MonitoringSettingsPane(store: store)
                .tabItem { Label("Monitoring", systemImage: "waveform.path.ecg") }
        }
        .frame(width: 520, height: 420)
        .background(WindowAccessor())
    }
}

// MARK: - Projects

private struct ProjectsSettingsPane: View {
    @ObservedObject var store: DeployBarAppStore

    var body: some View {
        Form {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("DeployBar")
                        .font(.system(size: 20, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }

            Section {
                ProjectsSelectionSection(
                    store: store,
                    persistSelectionChanges: true
                )
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Monitoring

private struct MonitoringSettingsPane: View {
    @ObservedObject var store: DeployBarAppStore

    private var currentProfile: PollingProfile {
        store.settings.pollingProfile
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 8) {
                    PollingProfileCard(
                        icon: "leaf.fill",
                        title: "Eco",
                        subtitle: "Save power",
                        tint: .green,
                        isSelected: currentProfile == .eco
                    ) { store.updatePollingProfile(.eco) }

                    PollingProfileCard(
                        icon: "speedometer",
                        title: "Balanced",
                        subtitle: "Recommended",
                        tint: .blue,
                        isSelected: currentProfile == .balanced
                    ) { store.updatePollingProfile(.balanced) }

                    PollingProfileCard(
                        icon: "bolt.fill",
                        title: "Aggressive",
                        subtitle: "Real-time",
                        tint: .orange,
                        isSelected: currentProfile == .aggressive
                    ) { store.updatePollingProfile(.aggressive) }
                }
                .padding(.vertical, 2)
            } header: {
                Text("Polling Profile")
            } footer: {
                Text(pollingFooter)
            }

            Section {
                Toggle("Notifications", isOn: Binding(
                    get: { store.settings.notificationsEnabled },
                    set: { store.updateNotificationsEnabled($0) }
                ))

                Toggle("Sound Effects", isOn: Binding(
                    get: { store.settings.soundsEnabled },
                    set: { store.updateSoundsEnabled($0) }
                ))
            } header: {
                Text("Alerts")
            } footer: {
                Text("Get notified when deployments succeed or fail.")
            }

            Section {
                Toggle("Launch at Login", isOn: Binding(
                    get: { store.settings.launchAtLogin },
                    set: { store.updateLaunchAtLogin($0) }
                ))
            } footer: {
                Text("Automatically start DeployBar when you sign in to your Mac.")
            }
        }
        .formStyle(.grouped)
    }

    private var pollingFooter: String {
        switch currentProfile {
        case .eco: "Power-saving mode with slower idle cadence. Best for battery life."
        case .balanced: "Adaptive updates with balanced API usage. Recommended for most users."
        case .aggressive: "Near real-time updates with the highest API usage."
        }
    }
}

// MARK: - Polling Profile Card

private struct PollingProfileCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? tint : .secondary)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.08) : isHovered ? Color.primary.opacity(0.03) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? tint.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(title) polling profile")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Window Accessor

private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.titlebarSeparatorStyle = .none
        }
    }
}
