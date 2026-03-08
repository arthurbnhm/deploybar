import Core
import SwiftUI

public struct DeployBarSettingsView: View {
    let store: DeployBarAppStore

    public init(store: DeployBarAppStore) {
        self.store = store
    }

    public var body: some View {
        TabView {
            Tab("Projects", systemImage: "shippingbox.fill") {
                ProjectsSettingsPane(store: store)
            }

            Tab("Monitoring", systemImage: "waveform.path.ecg") {
                MonitoringSettingsPane(store: store)
            }
        }
        .frame(width: 520, height: 420)
        .background(WindowAccessor())
    }
}

// MARK: - Projects

private struct ProjectsSettingsPane: View {
    let store: DeployBarAppStore

    var body: some View {
        Form {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(red: 0.56, green: 0.56, blue: 0.58))

                    Text("DeployBar")
                        .font(.system(size: 20, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }

            Section {
                TokenConnectionSection(store: store)
            }

            Section {
                ProjectsSelectionSection(
                    store: store,
                    persistSelectionChanges: true
                )
                .disabled(store.isValidatingToken)
            }
        }
        .formStyle(.grouped)
    }
}

private struct TokenConnectionSection: View {
    let store: DeployBarAppStore
    @State private var tokenDraft = ""
    @State private var isEditingToken = false
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Vercel Connection")
                .font(.system(size: 13, weight: .semibold))

            if store.isAuthRetrying, !isConnected {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)

                    Text(store.authStatusMessage ?? "Reconnecting to your saved token...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if isEditing {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("Paste your Vercel token...", text: $tokenDraft)
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
                                Text(isConnected ? "Save Token" : "Connect Token")
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
                    }
                }
            } else if let user = store.authUser {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.green)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("@\(user.username)")
                            .font(.system(size: 13, weight: .semibold))

                        if let email = user.email {
                            Text(email)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        Text("Connected")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        Button("Change Token") {
                            tokenDraft = ""
                            isEditingToken = true
                            tokenFieldFocused = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            Link("Get your Vercel token", destination: DeployBarAppStore.tokenHelpURL)
                .font(.system(size: 12, weight: .medium))

            if let notice = store.tokenNotice {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)

                    Text(notice)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if let error = store.tokenError {
                ErrorInlineBanner(message: error)
            }
        }
        .onAppear {
            if requiresTokenInput {
                isEditingToken = true
                tokenFieldFocused = true
            }
        }
        .onChange(of: store.authUser?.id) { _, newID in
            if newID == nil, requiresTokenInput {
                isEditingToken = true
                tokenFieldFocused = true
            }
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
