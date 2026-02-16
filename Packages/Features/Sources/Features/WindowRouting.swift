import AppKit
import Foundation
import SwiftUI

public enum DeployBarWindow: String {
    case settings = "deploybar-settings"
    case logs = "deploybar-logs"

    public var titleHint: String {
        switch self {
        case .settings:
            "DeployBar Settings"
        case .logs:
            "Deployment Logs"
        }
    }
}

@MainActor
public func presentWindow(id: String, titleHint: String, openWindow: OpenWindowAction) {
    NSApp.activate(ignoringOtherApps: true)
    openWindow(id: id)

    DispatchQueue.main.async {
        if let existing = NSApp.windows.first(where: { $0.title.localizedCaseInsensitiveContains(titleHint) }) {
            existing.makeKeyAndOrderFront(nil)
        }
    }
}

@MainActor
public func presentWindow(_ window: DeployBarWindow, openWindow: OpenWindowAction) {
    presentWindow(id: window.rawValue, titleHint: window.titleHint, openWindow: openWindow)
}
