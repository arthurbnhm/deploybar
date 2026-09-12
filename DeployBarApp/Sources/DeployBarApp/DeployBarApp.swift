import AppKit
import Features
import SwiftUI

@MainActor
final class SettingsPresenter {
    static let shared = SettingsPresenter()

    private var openAction: (() -> Void)?

    private init() {}

    func register(_ action: @escaping () -> Void) {
        openAction = action
    }

    func present() {
        NSApp.activate()
        openAction?()
    }
}

/// Bridges a clicked deploy notification (routed via `NotificationActivationRouter`,
/// which has no SwiftUI environment) to the `openWindow` action, which is only
/// reachable from inside the view hierarchy. Mirrors `SettingsPresenter`.
@MainActor
final class LogsPresenter {
    static let shared = LogsPresenter()

    private var openAction: ((String) -> Void)?

    private init() {}

    func register(_ action: @escaping (String) -> Void) {
        openAction = action
    }

    func present(projectId: String) {
        NSApp.activate()
        openAction?(projectId)
    }
}

final class DeployBarAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        if let iconImage = DeployBarBrand.appIconImage() {
            NSApp.applicationIconImage = iconImage
        }

        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else {
            return true
        }

        Task { @MainActor in
            SettingsPresenter.shared.present()
        }
        return true
    }
}

@main
struct DeployBarMainApp: App {
    @NSApplicationDelegateAdaptor(DeployBarAppDelegate.self) private var appDelegate
    @State private var startup = DeployBarStartup()

    var body: some Scene {
        MenuBarExtra {
            if let store = startup.store {
                MenuBarContentView(store: store)
            } else {
                StartupFailureView(startup: startup)
            }
        } label: {
            if let store = startup.store {
                MenuBarLabelView(aggregateStatus: store.aggregateStatus)
                    .background(SettingsBridgeView(store: store))
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .accessibilityLabel("DeployBar: Unable to start")
                    .background(StartupFailureSettingsBridge())
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            if let store = startup.store {
                DeployBarSettingsView(store: store)
            } else {
                StartupFailureView(startup: startup)
            }
        }

        Window("Deployment Logs", id: DeployBarWindow.logs.rawValue) {
            if let store = startup.store {
                LogsView(store: store)
            } else {
                StartupFailureView(startup: startup)
            }
        }
        .defaultSize(width: 860, height: 560)
        .defaultPosition(.center)
        .windowResizability(.contentMinSize)
        .restorationBehavior(.disabled)
    }
}

/// Bridges the app delegate and setup flow to the SwiftUI `openSettings` action,
/// which is only reachable from inside the view hierarchy.
private struct SettingsBridgeView: View {
    let store: DeployBarAppStore
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @State private var didPresentForCurrentNeed = false

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                SettingsPresenter.shared.register { openSettings() }
                LogsPresenter.shared.register { projectId in
                    Task { @MainActor in
                        let opened = await store.openLogsForProject(id: projectId)
                        if opened {
                            presentWindow(.logs, openWindow: openWindow)
                        }
                    }
                }
                NotificationActivationRouter.shared.register { projectId in
                    LogsPresenter.shared.present(projectId: projectId)
                }
            }
            .task {
                presentSettingsIfNeeded()
            }
            .onChange(of: store.requiresSetup) { _, requiresSetup in
                if requiresSetup {
                    presentSettingsIfNeeded()
                } else {
                    didPresentForCurrentNeed = false
                }
            }
    }

    private func presentSettingsIfNeeded() {
        guard store.requiresSetup, !didPresentForCurrentNeed else {
            return
        }

        didPresentForCurrentNeed = true
        NSApp.activate()
        openSettings()
    }
}

private struct StartupFailureSettingsBridge: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear { SettingsPresenter.shared.register { openSettings() } }
            .task {
                NSApp.activate()
                openSettings()
            }
    }
}

private struct StartupFailureView: View {
    let startup: DeployBarStartup

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("DeployBar Couldn't Start", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text("Local storage could not be opened. Monitoring has not started. Check access to DeployBar's Application Support folder, then try again.")
                .foregroundStyle(.secondary)
            if let message = startup.errorMessage {
                Text(message)
                    .font(.caption)
                    .textSelection(.enabled)
            }
            HStack {
                Button("Try Again") { startup.retry() }
                    .buttonStyle(.borderedProminent)
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
