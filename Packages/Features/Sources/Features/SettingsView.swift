import AppKit
import Core
import SwiftUI

public struct DeployBarSettingsView: View {
    enum SettingsTab: Hashable {
        case projects
        case monitoring
    }

    let store: DeployBarAppStore
    @State private var selectedTab: SettingsTab

    public init(store: DeployBarAppStore) {
        self.init(store: store, initialTab: .projects)
    }

    /// Used by previews and snapshot tests to render a specific pane.
    init(store: DeployBarAppStore, initialTab: SettingsTab) {
        self.store = store
        _selectedTab = State(initialValue: initialTab)
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Projects", systemImage: "shippingbox.fill", value: .projects) {
                ProjectsSettingsPane(store: store)
            }

            Tab("Monitoring", systemImage: "waveform.path.ecg", value: .monitoring) {
                MonitoringSettingsPane(store: store)
            }
        }
        .frame(width: 560, height: 520)
    }
}

// MARK: - Projects

private struct ProjectsSettingsPane: View {
    let store: DeployBarAppStore

    var body: some View {
        Form {
            Section("Vercel Account") {
                TokenConnectionSection(store: store)
            }

            ProjectsSelectionSection(
                store: store,
                persistSelectionChanges: true
            )
            .disabled(store.isValidatingToken)
        }
        .formStyle(.grouped)
    }
}

private struct TokenConnectionSection: View {
    let store: DeployBarAppStore
    @State private var tokenDraft = ""
    @State private var isEditingToken = false
    @State private var showDisconnectConfirmation = false
    @FocusState private var tokenFieldFocused: Bool

    private var isConnected: Bool {
        store.authUser != nil
    }

    private var requiresTokenInput: Bool {
        store.shouldPromptForTokenInput && !isConnected
    }

    private var isEditing: Bool {
        requiresTokenInput || isEditingToken
    }

    private var submitDisabled: Bool {
        store.isValidatingToken || tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        if store.isAuthRetrying, !isConnected {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)

                Text(store.authStatusMessage ?? "Reconnecting to your saved token…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }

        if isEditing {
            VStack(alignment: .leading, spacing: 10) {
                SecureField("Access Token", text: $tokenDraft, prompt: Text("Paste your Vercel token…"))
                    .textFieldStyle(.roundedBorder)
                    .focused($tokenFieldFocused)

                HStack(spacing: 8) {
                    Button {
                        Task {
                            let success = await store.updateToken(tokenDraft)
                            if success {
                                tokenDraft = ""
                                isEditingToken = false
                            } else {
                                tokenFieldFocused = true
                            }
                        }
                    } label: {
                        if store.isValidatingToken {
                            ProgressView()
                                .controlSize(.small)
                                .frame(minWidth: 20)
                        } else {
                            Text(isConnected ? "Save Token" : "Connect")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(submitDisabled)

                    if isConnected {
                        Button("Cancel") {
                            tokenDraft = ""
                            isEditingToken = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(store.isValidatingToken)
                    }

                    Spacer()

                    Link("Get your Vercel token", destination: DeployBarAppStore.tokenHelpURL)
                        .font(.subheadline.weight(.medium))
                }
            }
            .padding(.vertical, 2)
            .onAppear {
                tokenFieldFocused = true
            }
        } else if let user = store.authUser {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill.badge.checkmark")
                    .font(.system(size: 26))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(user.username)")
                        .font(.body.weight(.semibold))

                    if let email = user.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button("Change Token…") {
                    tokenDraft = ""
                    isEditingToken = true
                    tokenFieldFocused = true
                }
                .controlSize(.small)

                Button("Disconnect…", role: .destructive) {
                    showDisconnectConfirmation = true
                }
                .controlSize(.small)
                .disabled(store.isValidatingToken)
            }
            .padding(.vertical, 2)
            .confirmationDialog(
                "Disconnect Vercel?",
                isPresented: $showDisconnectConfirmation
            ) {
                Button("Disconnect and Clear Local Data", role: .destructive) {
                    Task {
                        await store.disconnectAccount()
                        tokenDraft = ""
                        isEditingToken = true
                        tokenFieldFocused = true
                    }
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears the saved token, selected projects, cached statuses, and local deployment logs.")
            }
        }

        if let notice = store.tokenNotice {
            Label {
                Text(notice)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }

        if let error = store.tokenError {
            ErrorInlineBanner(message: error)
        }
    }
}

// MARK: - Monitoring

private struct MonitoringSettingsPane: View {
    let store: DeployBarAppStore

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
            } header: {
                Text("Alerts")
            } footer: {
                Text("Get notified when deployments succeed or fail.")
            }

            Section {
                Toggle("Sound Effects", isOn: Binding(
                    get: { store.settings.soundsEnabled },
                    set: { store.updateSoundsEnabled($0) }
                ))

                Picker("Theme", selection: Binding(
                    get: { store.settings.soundTheme },
                    set: { store.updateSoundTheme($0) }
                )) {
                    ForEach(SoundTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.menu)

                SoundPreviewRow(
                    title: "Deploy succeeded",
                    systemImage: "checkmark.circle.fill",
                    tint: .green
                ) { store.previewSound(.success) }

                SoundPreviewRow(
                    title: "Deploy failed",
                    systemImage: "xmark.circle.fill",
                    tint: .red
                ) { store.previewSound(.failure) }
            } header: {
                Text("Sounds")
            } footer: {
                Text("Aurora and Pulse are DeployBar's designed chimes; Classic keeps the original system sounds. Previews play even while Sound Effects is off.")
            }

            Section {
                Toggle("Launch at Login", isOn: Binding(
                    get: { store.settings.launchAtLogin },
                    set: { store.updateLaunchAtLogin($0) }
                ))
            } footer: {
                Text("Automatically start DeployBar when you sign in to your Mac.")
            }

            Section {
                UpdateCheckRow()
            } header: {
                Text("About")
            } footer: {
                Text("Checks GitHub Releases when you ask. DeployBar never downloads or installs updates automatically.")
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

private struct SoundPreviewRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void
    @State private var playCount = 0

    var body: some View {
        HStack {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
            }

            Spacer()

            Button {
                playCount += 1
                action()
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.bounce, value: playCount)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Play the \(title) sound")
        }
    }
}

private struct UpdateCheckRow: View {
    @State private var isChecking = false
    @State private var availability: UpdateAvailability?

    private var runningVersion: String { UpdateChecker.runningVersion }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Version \(runningVersion)")
                    .font(.subheadline)

                if let availability {
                    statusLabel(for: availability)
                }
            }

            Spacer()

            Button {
                Task { await checkForUpdate() }
            } label: {
                if isChecking {
                    ProgressView()
                        .controlSize(.small)
                        .frame(minWidth: 20)
                } else {
                    Text("Check for Updates…")
                }
            }
            .controlSize(.small)
            .disabled(isChecking)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func statusLabel(for availability: UpdateAvailability) -> some View {
        switch availability {
        case .upToDate:
            Text("You're up to date.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .updateAvailable(latestVersion, _):
            Text("Update available: \(latestVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .checkFailed(message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func checkForUpdate() async {
        isChecking = true
        let result = await UpdateChecker.checkForUpdate(currentVersion: runningVersion)
        availability = result
        isChecking = false

        if case let .updateAvailable(_, releaseURL) = result {
            NSWorkspace.shared.open(releaseURL)
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
                    .foregroundStyle(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(.secondary))
                    .frame(height: 22)

                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected
                    ? AnyShapeStyle(tint.opacity(0.12))
                    : isHovered ? AnyShapeStyle(.quinary) : AnyShapeStyle(.clear),
                in: .rect(cornerRadius: DesignSystem.cornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                    .strokeBorder(tint.opacity(isSelected ? 0.5 : 0), lineWidth: 1.5)
            )
            .contentShape(.rect(cornerRadius: DesignSystem.cornerRadius))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(title) polling profile")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
