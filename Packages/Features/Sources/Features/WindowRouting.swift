import AppKit
import SwiftUI

public enum DeployBarWindow: String {
    case logs = "deploybar-logs"
}

@MainActor
public func presentWindow(_ window: DeployBarWindow, openWindow: OpenWindowAction) {
    NSApp.activate()
    openWindow(id: window.rawValue)
}
