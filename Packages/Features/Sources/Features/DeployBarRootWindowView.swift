import Core
import SwiftUI

public struct DeployBarRootWindowView: View {
    @ObservedObject var store: DeployBarAppStore
    @Environment(\.dismissWindow) private var dismissWindow
    private let windowID: String

    public init(store: DeployBarAppStore, windowID: String = "deploybar-main") {
        self.store = store
        self.windowID = windowID
    }

    public var body: some View {
        ZStack {
            backgroundLayer

            content
        }
        .frame(minWidth: 680, minHeight: 580)
        .background(WindowChromeConfigurator())
        .onChange(of: store.phase) { _, phase in
            if case .running = phase { dismissWindow(id: windowID) }
        }
        .task {
            if case .running = store.phase { dismissWindow(id: windowID) }
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch store.phase {
        case .onboarding:
            ZStack {
                LinearGradient(
                    colors: [DesignSystem.windowBackgroundTop, DesignSystem.windowBackgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [DesignSystem.windowGlow, Color.clear],
                    center: .topLeading,
                    startRadius: 30,
                    endRadius: 420
                )
                .ignoresSafeArea()
            }
        case .loading, .unsupported, .running:
            GlassBackgroundView(material: .hudWindow)
                .ignoresSafeArea()

            LinearGradient(
                colors: [DesignSystem.windowOverlayTop, DesignSystem.windowOverlayBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .loading:
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text("Starting DeployBar\u{2026}")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

        case let .unsupported(message):
            FrostedPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Unsupported Environment", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 500, alignment: .leading)
            }
            .padding(32)

        case .onboarding:
            OnboardingView(store: store)

        case .running:
            EmptyView()
        }
    }
}
