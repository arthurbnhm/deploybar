import Core
import SwiftUI

public struct OnboardingView: View {
    @ObservedObject var store: DeployBarAppStore

    public init(store: DeployBarAppStore) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                tokenSection

                if store.authUser != nil {
                    connectedBadge
                    scopeAndProjectsSection
                    preferencesSection

                    Button {
                        Task { await store.completeOnboarding() }
                    } label: {
                        Text("Start Monitoring")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!store.canFinishOnboarding)
                }

                if let error = store.tokenError {
                    ErrorInlineBanner(message: error)
                }
            }
            .padding(28)
            .frame(width: 560)
        }
        .animation(.easeInOut(duration: 0.2), value: store.authUser != nil)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "triangle.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.tint)

            Text("DeployBar")
                .font(.system(size: 30, weight: .bold))

            Text("Live Vercel production status in your menu bar.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var tokenSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Vercel Access Token")
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 8) {
                    SecureField("Paste your token", text: $store.tokenInput)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        Task { await store.connectToken() }
                    } label: {
                        if store.isValidatingToken {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(store.authUser == nil ? "Connect" : "Connected")
                                .frame(minWidth: 78)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isValidatingToken || store.authUser != nil)
                }
            }
        }
    }

    private var connectedBadge: some View {
        AppCard {
            Label("Connected as @\(store.authUser?.username ?? "")", systemImage: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.green)
        }
    }

    private var scopeAndProjectsSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Scope")
                        .font(.system(size: 13, weight: .semibold))

                    Picker("Scope", selection: $store.selectedScope) {
                        Text("Personal").tag(TeamScope.personal)
                        ForEach(store.teams) { team in
                            Text(team.name).tag(TeamScope.team(id: team.id, slug: team.slug))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: store.selectedScope) { _, _ in
                        Task { await store.refreshProjectsForScope() }
                    }
                }

                HStack {
                    Text("Projects")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(store.selectedProjectIDs.count)/20")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if store.availableProjects.isEmpty {
                    Text("No projects found for this scope.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(store.availableProjects) { project in
                                ProjectSelectionRow(
                                    name: project.name,
                                    isSelected: store.selectedProjectIDs.contains(project.id)
                                ) {
                                    store.toggleProjectSelection(project.id)
                                }
                            }
                        }
                        .padding(4)
                    }
                    .frame(height: 240)
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

    private var preferencesSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Preferences")
                    .font(.system(size: 13, weight: .semibold))

                SettingsToggleRow(
                    title: "Notifications",
                    subtitle: "Notify on deployment success/failure",
                    icon: "bell.fill",
                    isOn: $store.onboardingNotificationsEnabled
                )

                Divider()

                SettingsToggleRow(
                    title: "Sound effects",
                    subtitle: "Play system sound on terminal status changes",
                    icon: "speaker.wave.2.fill",
                    isOn: $store.onboardingSoundsEnabled
                )

                Divider()

                SettingsToggleRow(
                    title: "Launch at login",
                    subtitle: "Start DeployBar automatically",
                    icon: "power",
                    isOn: $store.onboardingLaunchAtLogin
                )
            }
        }
    }
}
