import AppKit
import Foundation
import SwiftUI

public enum DeployBarWindow: String {
    case main = "deploybar-main"
    case settings = "deploybar-settings"

    public var titleHint: String {
        switch self {
        case .main:
            "DeployBar"
        case .settings:
            "DeployBar Settings"
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
