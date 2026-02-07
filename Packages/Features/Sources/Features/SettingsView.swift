import Core
import SwiftUI

private enum SettingsPane: String, CaseIterable, Identifiable {
    case projects = "Projects"
    case monitoring = "Monitoring"
    case account = "Account & Data"

    var id: String { rawValue }

    var title: String { rawValue }

    var subtitle: String {
        switch self {
        case .projects:
            return "Choose scope and watched repositories"
        case .monitoring:
            return "Control refresh behavior and alerts"
        case .account:
            return "Manage local data and sign-out"
        }
    }

    var symbolName: String {
        switch self {
        case .projects:
            return "shippingbox.fill"
        case .monitoring:
            return "waveform.path.ecg"
        case .account:
            return "person.crop.circle.fill"
        }
    }

    var tone: Color {
        switch self {
        case .projects:
            return Color(red: 0.29, green: 0.53, blue: 0.94)
        case .monitoring:
            return Color(red: 0.08, green: 0.66, blue: 0.47)
        case .account:
            return Color(red: 0.87, green: 0.45, blue: 0.24)
        }
    }
}

public struct DeployBarSettingsView: View {
    @ObservedObject var store: DeployBarAppStore
    @State private var selectedPane: SettingsPane? = .projects

    public init(store: DeployBarAppStore) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 760, minHeight: 560)
        .navigationSplitViewStyle(.balanced)
    }

    private var sidebar: some View {
        List(SettingsPane.allCases, selection: $selectedPane) { pane in
            SettingsSidebarRow(pane: pane, isSelected: selectedPane == pane)
                .tag(pane)
        }
        .listStyle(.sidebar)
        .navigationTitle("Settings")
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("DeployBar")
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 10)
            .background(.ultraThinMaterial)
        }
    }

    private var detail: some View {
        let pane = selectedPane ?? .projects

        return ZStack {
            LinearGradient(
                colors: [Color.white.opacity(0.04), Color.black.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsHeader(pane: pane)

                    switch pane {
                    case .projects:
                        projectsSection
                    case .monitoring:
                        monitoringSection
                    case .account:
                        accountAndDataSection
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var projectsSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Project Source")

                SettingsInfoRow(
                    icon: "person.2.fill",
                    iconTint: SettingsPane.projects.tone,
                    title: "Scope",
                    subtitle: "Choose which account/team projects come from"
                ) {
                    Picker("Scope", selection: $store.selectedScope) {
                        Text("Personal").tag(TeamScope.personal)
                        ForEach(store.teams) { team in
                            Text(team.name).tag(TeamScope.team(id: team.id, slug: team.slug))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                    .onChange(of: store.selectedScope) { _, _ in
                        Task { await store.refreshProjectsForScope() }
                    }
                }

                Divider()

                HStack {
                    Label("Watched Projects", systemImage: "shippingbox")
                        .font(.system(size: 13, weight: .semibold, design: .default))

                    Spacer()

                    Text("\(store.selectedProjectIDs.count)/20")
                        .font(.system(size: 11, weight: .semibold, design: .default).monospacedDigit())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(SettingsPane.projects.tone.opacity(0.14))
                        .foregroundStyle(SettingsPane.projects.tone)
                        .clipShape(Capsule(style: .continuous))
                }

                if store.availableProjects.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "tray.fill")
                            .foregroundStyle(.secondary)
                        Text("No projects found for this scope.")
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(store.availableProjects) { project in
                                ProjectSelectionRow(
                                    name: project.name,
                                    isSelected: store.selectedProjectIDs.contains(project.id)
                                ) {
                                    store.toggleProjectSelection(project.id)
                                    store.updateWatchedProjects()
                                }
                            }
                        }
                        .padding(4)
                    }
                    .frame(maxHeight: 330)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 0.5)
                    )
                }
            }
        }
    }

    private var monitoringSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Monitoring")

                SettingsInfoRow(
                    icon: "timer",
                    iconTint: SettingsPane.monitoring.tone,
                    title: "Polling Profile",
                    subtitle: pollingSubtitle
                ) {
                    Picker("Profile", selection: Binding(
                        get: { store.settings.pollingProfile },
                        set: { store.updatePollingProfile($0) }
                    )) {
                        Text("Balanced").tag(PollingProfile.balanced)
                        Text("Aggressive").tag(PollingProfile.aggressive)
                        Text("Eco").tag(PollingProfile.eco)
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }

                Divider()

                SettingsToggleRow(
                    title: "Notifications",
                    subtitle: "Show local notifications on success/failure",
                    icon: "bell.fill",
                    isOn: Binding(
                        get: { store.settings.notificationsEnabled },
                        set: { store.updateNotificationsEnabled($0) }
                    )
                )

                Divider()

                SettingsToggleRow(
                    title: "Sound effects",
                    subtitle: "Play feedback sounds on status transitions",
                    icon: "speaker.wave.2.fill",
                    isOn: Binding(
                        get: { store.settings.soundsEnabled },
                        set: { store.updateSoundsEnabled($0) }
                    )
                )

                Divider()

                SettingsToggleRow(
                    title: "Launch at login",
                    subtitle: "Start DeployBar when you sign in",
                    icon: "power",
                    isOn: Binding(
                        get: { store.settings.launchAtLogin },
                        set: { store.updateLaunchAtLogin($0) }
                    )
                )
            }
        }
    }

    private var accountAndDataSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Account & Data")

                SettingsActionRow(
                    icon: "trash.fill",
                    iconTint: Color(red: 0.90, green: 0.55, blue: 0.20),
                    title: "Clear local cache",
                    subtitle: "Remove stored deployment logs and reset local state",
                    buttonTitle: "Clear",
                    role: nil,
                    action: { store.clearLocalData() }
                )

                Divider()

                SettingsActionRow(
                    icon: "rectangle.portrait.and.arrow.right.fill",
                    iconTint: Color(red: 0.87, green: 0.34, blue: 0.29),
                    title: "Sign out",
                    subtitle: "Remove token and local data, then return to onboarding",
                    buttonTitle: "Sign Out",
                    role: .destructive,
                    action: { store.signOut() }
                )
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold, design: .default))
    }

    private var pollingSubtitle: String {
        switch store.settings.pollingProfile {
        case .balanced:
            "Fast adaptive updates with balanced API usage"
        case .aggressive:
            "Near real-time updates with highest API usage"
        case .eco:
            "Power-saving mode with slower idle cadence"
        }
    }
}

private struct SettingsSidebarRow: View {
    let pane: SettingsPane
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(pane.tone.opacity(isSelected ? 0.24 : 0.14))
                    .frame(width: 24, height: 24)
                Image(systemName: pane.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(pane.tone)
            }

            Text(pane.title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .default))
        }
        .padding(.vertical, 3)
    }
}

private struct SettingsHeader: View {
    let pane: SettingsPane

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(pane.tone.opacity(0.16))
                    .frame(width: 40, height: 40)
                Image(systemName: pane.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(pane.tone)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(pane.title)
                    .font(.system(size: 24, weight: .bold, design: .default))
                Text(pane.subtitle)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
    }
}

private struct SettingsInfoRow<Trailing: View>: View {
    let icon: String
    let iconTint: Color
    let title: String
    let subtitle: String
    let trailing: Trailing

    init(icon: String, iconTint: Color, title: String, subtitle: String, @ViewBuilder trailing: () -> Trailing) {
        self.icon = icon
        self.iconTint = iconTint
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 10) {
            iconBadge

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .default))
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)
            trailing
        }
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(iconTint.opacity(0.15))
                .frame(width: 24, height: 24)
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(iconTint)
        }
    }
}

private struct SettingsActionRow: View {
    let icon: String
    let iconTint: Color
    let title: String
    let subtitle: String
    let buttonTitle: String
    let role: ButtonRole?
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(iconTint.opacity(0.15))
                    .frame(width: 24, height: 24)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconTint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .default))
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            Button(role: role, action: action) {
                Text(buttonTitle)
            }
            .controlSize(.small)
        }
    }
}
