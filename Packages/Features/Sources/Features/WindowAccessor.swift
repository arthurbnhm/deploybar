import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context _: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else {
                return
            }

            window.toolbarStyle = .unified
            window.titleVisibility = .hidden
            window.titlebarSeparatorStyle = .none
        }
    }
}
