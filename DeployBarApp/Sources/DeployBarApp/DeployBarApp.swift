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
    @State private var store: DeployBarAppStore

    init() {
        let appStore: DeployBarAppStore
        if let live = try? DeployBarEnvironment.live() {
            appStore = DeployBarAppStore(environment: live)
        } else {
            appStore = DeployBarAppStore(environment: .preview())
        }
        appStore.start()
        _store = State(wrappedValue: appStore)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(store: store)
        } label: {
            MenuBarLabelView(aggregateStatus: store.aggregateStatus)
                .background(SettingsBridgeView(store: store))
        }
        .menuBarExtraStyle(.window)

        Settings {
            DeployBarSettingsView(store: store)
        }

        Window("Deployment Logs", id: DeployBarWindow.logs.rawValue) {
            LogsView(store: store)
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
