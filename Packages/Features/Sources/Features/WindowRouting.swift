import AppKit
import Foundation
import SwiftUI

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
