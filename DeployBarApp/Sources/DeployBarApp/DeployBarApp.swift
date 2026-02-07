import AppKit
import Features
import SwiftUI

final class DeployBarAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct DeployBarMainApp: App {
    @NSApplicationDelegateAdaptor(DeployBarAppDelegate.self) private var appDelegate
    @StateObject private var store: DeployBarAppStore

    init() {
        let appStore: DeployBarAppStore
        if let live = try? DeployBarEnvironment.live() {
            appStore = DeployBarAppStore(environment: live)
        } else {
            appStore = DeployBarAppStore(environment: .preview())
        }
        appStore.start()
        _store = StateObject(wrappedValue: appStore)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(store: store)
        } label: {
            MenuBarLabelView(aggregateStatus: store.aggregateStatus)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("DeployBar", id: "deploybar-main") {
            DeployBarRootWindowView(store: store)
        }
        .defaultSize(width: 920, height: 720)

        Window("DeployBar Settings", id: "deploybar-settings") {
            DeployBarSettingsView(store: store)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 760, height: 560)
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
                presentWindow(id: "deploybar-settings", titleHint: "DeployBar Settings", openWindow: openWindow)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
