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
        private let screenMargin: CGFloat = 14
        private weak var observedWindow: NSWindow?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else {
                stopObservingWindow()
                return
            }

            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.titlebarSeparatorStyle = .none
            window.isMovableByWindowBackground = true
            window.styleMask.insert(.fullSizeContentView)
            window.toolbar?.isVisible = false

            startObservingWindowIfNeeded(window)
            clampWindowIfNeeded(window)
        }

        private func startObservingWindowIfNeeded(_ window: NSWindow) {
            guard observedWindow !== window else {
                return
            }

            stopObservingWindow()
            observedWindow = window
            let center = NotificationCenter.default
            center.addObserver(
                self,
                selector: #selector(handleObservedWindowChange),
                name: NSWindow.didMoveNotification,
                object: window
            )
            center.addObserver(
                self,
                selector: #selector(handleObservedWindowChange),
                name: NSWindow.didResizeNotification,
                object: window
            )
            center.addObserver(
                self,
                selector: #selector(handleObservedWindowChange),
                name: NSWindow.didChangeScreenNotification,
                object: window
            )
            center.addObserver(
                self,
                selector: #selector(handleObservedWindowChange),
                name: NSApplication.didChangeScreenParametersNotification,
                object: nil
            )
        }

        private func stopObservingWindow() {
            NotificationCenter.default.removeObserver(self)
            observedWindow = nil
        }

        @objc
        private func handleObservedWindowChange() {
            guard let observedWindow else {
                return
            }
            clampWindowIfNeeded(observedWindow)
        }

        private func clampWindowIfNeeded(_ window: NSWindow) {
            let clamped = clampedFrame(for: window)
            guard !framesAreEqual(window.frame, clamped) else {
                return
            }
            window.setFrame(clamped, display: true, animate: false)
        }

        private func clampedFrame(for window: NSWindow) -> CGRect {
            guard let screen = window.screen ?? NSScreen.main else {
                return window.frame
            }

            var frame = window.frame
            let safeFrame = screen.visibleFrame.insetBy(dx: screenMargin, dy: screenMargin)

            frame.size.width = min(frame.size.width, safeFrame.width)
            frame.size.height = min(frame.size.height, safeFrame.height)

            if frame.minX < safeFrame.minX {
                frame.origin.x = safeFrame.minX
            }
            if frame.maxX > safeFrame.maxX {
                frame.origin.x = safeFrame.maxX - frame.width
            }
            if frame.minY < safeFrame.minY {
                frame.origin.y = safeFrame.minY
            }
            if frame.maxY > safeFrame.maxY {
                frame.origin.y = safeFrame.maxY - frame.height
            }

            return frame
        }

        private func framesAreEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
            abs(lhs.origin.x - rhs.origin.x) < 0.5 &&
                abs(lhs.origin.y - rhs.origin.y) < 0.5 &&
                abs(lhs.size.width - rhs.size.width) < 0.5 &&
                abs(lhs.size.height - rhs.size.height) < 0.5
        }
    }
}
