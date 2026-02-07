import AppKit
import SwiftUI

struct GlassBackgroundView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }

    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context _: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}

struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        ConfigView()
    }

    func updateNSView(_: NSView, context _: Context) {}

    private final class ConfigView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.titlebarSeparatorStyle = .none
            window.isMovableByWindowBackground = true
            window.styleMask.insert(.fullSizeContentView)
            window.toolbar?.isVisible = false
        }
    }
}
