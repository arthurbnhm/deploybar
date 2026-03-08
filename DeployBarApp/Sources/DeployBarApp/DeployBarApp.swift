import AppKit
import Features
import SwiftUI

@MainActor
final class SettingsWindowOpener {
    static let shared = SettingsWindowOpener()

    private var openAction: (() -> Void)?

    private init() {}

    func register(_ action: @escaping () -> Void) {
        openAction = action
    }

    func openSettingsWindow() {
        if let existing = NSApp.windows.first(where: { $0.title.localizedCaseInsensitiveContains(DeployBarWindow.settings.titleHint) }) {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        openAction?()
    }
}

final class DeployBarAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        if let iconImage = DeployBarBrand.appIconImage() {
            NSApp.applicationIconImage = iconImage
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else {
            return true
        }

        Task { @MainActor in
            SettingsWindowOpener.shared.openSettingsWindow()
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
                .background(SettingsWindowBridgeView())
                .background(SetupRequiredBridgeView(store: store))
        }
        .menuBarExtraStyle(.window)

        Window("DeployBar Settings", id: DeployBarWindow.settings.rawValue) {
            DeployBarSettingsView(store: store)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 520, height: 490)
        .deployBarWindowChrome()

        Window("Deployment Logs", id: DeployBarWindow.logs.rawValue) {
            LogsView(store: store)
        }
        .defaultSize(width: 860, height: 560)
        .defaultPosition(.center)
        .deployBarWindowChrome()
        .commands {
            SettingsCommands()
        }
    }
}

private struct SettingsCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                presentWindow(.settings, openWindow: openWindow)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

private struct SettingsWindowBridgeView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                SettingsWindowOpener.shared.register {
                    presentWindow(.settings, openWindow: openWindow)
                }
            }
    }
}

private struct SetupRequiredBridgeView: View {
    let store: DeployBarAppStore
    @Environment(\.openWindow) private var openWindow
    @State private var didPresentForCurrentNeed = false

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
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
        presentWindow(.settings, openWindow: openWindow)
    }
}

private extension Scene {
    func deployBarWindowChrome() -> some Scene {
        windowToolbarStyle(.unified(showsTitle: false))
    }
}
