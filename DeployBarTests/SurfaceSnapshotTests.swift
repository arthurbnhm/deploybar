import AppKit
import Core
@testable import Features
import SwiftUI
import XCTest

/// Renders the main app surfaces into offscreen windows and writes PNGs,
/// verifying every surface lays out and draws at real sizes in both appearances.
/// Set SNAPSHOT_DIR to control where the images land (for visual inspection).
@MainActor
final class SurfaceSnapshotTests: XCTestCase {
    static let outputDir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"]
        ?? NSTemporaryDirectory() + "deploybar-snapshots"

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(atPath: Self.outputDir, withIntermediateDirectories: true)
    }

    private func populatedStore() -> DeployBarAppStore {
        let store = DeployBarAppStore(environment: .preview())
        let now = Date()
        // .loading keeps setMenuOpen from starting the mock monitoring loop,
        // which would overwrite the fixture statuses mid-render.
        store.phase = .loading
        store.authConnectionState = .connected
        store.authUser = AuthUser(id: "u1", username: "arthur", email: "arthur@example.com")
        store.lastRefreshAt = now.addingTimeInterval(-30)
        store.hasCompletedInitialRefresh = true
        store.aggregateStatus = .building

        var settings = store.settings
        settings.watchedProjects = [
            WatchedProject(id: "p1", name: "deploybar-website", teamId: nil, teamSlug: nil),
            WatchedProject(id: "p2", name: "api-gateway", teamId: nil, teamSlug: nil),
            WatchedProject(id: "p3", name: "marketing-site", teamId: nil, teamSlug: nil),
            WatchedProject(id: "p4", name: "docs", teamId: nil, teamSlug: nil),
        ]
        store.settings = settings
        store.selectedProjectIDs = Set(settings.watchedProjects.map(\.id))
        store.availableProjects = settings.watchedProjects.map {
            Project(id: $0.id, name: $0.name, teamId: nil, updatedAt: now)
        } + [
            Project(id: "p5", name: "internal-tools", teamId: nil, updatedAt: now),
        ]

        store.projectStatuses = [
            ProjectStatus(
                project: settings.watchedProjects[0],
                snapshot: DeploymentSnapshot(
                    id: "dpl_9f3k2m1x",
                    projectId: "p1",
                    stage: .ready,
                    createdAt: now.addingTimeInterval(-2_700),
                    url: URL(string: "https://deploybar.app"),
                    commitMessage: "Fix hero spacing on landing page"
                ),
                lastUpdatedAt: now
            ),
            ProjectStatus(
                project: settings.watchedProjects[1],
                snapshot: DeploymentSnapshot(
                    id: "dpl_7h2j9d4q",
                    projectId: "p2",
                    stage: .building,
                    createdAt: now.addingTimeInterval(-95),
                    url: URL(string: "https://api.deploybar.app"),
                    commitMessage: "Add pagination to deployments endpoint"
                ),
                lastUpdatedAt: now
            ),
            ProjectStatus(
                project: settings.watchedProjects[2],
                snapshot: DeploymentSnapshot(
                    id: "dpl_3c8n5v7z",
                    projectId: "p3",
                    stage: .failed,
                    createdAt: now.addingTimeInterval(-9_000),
                    url: nil,
                    commitMessage: "Bump Next.js to 15.4"
                ),
                lastUpdatedAt: now
            ),
            ProjectStatus(
                project: settings.watchedProjects[3],
                snapshot: DeploymentSnapshot(
                    id: "dpl_5t1r8w2y",
                    projectId: "p4",
                    stage: .queued,
                    createdAt: now.addingTimeInterval(-12),
                    url: nil,
                    commitMessage: "Rewrite quickstart guide"
                ),
                lastUpdatedAt: now
            ),
        ]
        return store
    }

    func testSnapshotPopover() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["SKIP_SNAPSHOT_TESTS"] == "1",
            "Snapshot rendering skipped via SKIP_SNAPSHOT_TESTS"
        )
        let store = populatedStore()
        try snapshotFittingHeight(
            MenuBarContentView(store: store),
            width: 380,
            name: "popover"
        )
        try snapshotFittingHeight(
            MenuBarContentView(store: store, initiallyExpandedProjectID: "p1"),
            width: 380,
            name: "popover-expanded"
        )
        try snapshotFittingHeight(
            MenuBarContentView(store: store, initiallyExpandedProjectID: "p3"),
            width: 380,
            name: "popover-expanded-failed"
        )

        let setupStore = DeployBarAppStore(environment: .preview())
        setupStore.phase = .setupRequired
        setupStore.authConnectionState = .setupRequired(reason: "Paste a Vercel access token to continue.")
        try snapshotFittingHeight(
            MenuBarContentView(store: setupStore),
            width: 380,
            name: "popover-setup"
        )
    }

    func testSnapshotSettings() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["SKIP_SNAPSHOT_TESTS"] == "1",
            "Snapshot rendering skipped via SKIP_SNAPSHOT_TESTS"
        )
        let store = populatedStore()
        try snapshotWindow(
            DeployBarSettingsView(store: store),
            size: CGSize(width: 560, height: 560),
            name: "settings-projects"
        )
        try snapshotWindow(
            DeployBarSettingsView(store: store, initialTab: .monitoring),
            size: CGSize(width: 560, height: 560),
            name: "settings-monitoring"
        )
    }

    func testSnapshotLogs() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["SKIP_SNAPSHOT_TESTS"] == "1",
            "Snapshot rendering skipped via SKIP_SNAPSHOT_TESTS"
        )
        let store = populatedStore()
        let now = Date()
        store.selectedLogsProject = store.settings.watchedProjects[0]
        store.selectedLogsDeployment = store.projectStatuses[0].snapshot
        store.logEvents = (0..<14).map { index in
            let levels = ["info", "stdout", "warning", "error", "debug"]
            return DeploymentEvent(
                id: "evt_\(index)",
                deploymentId: "dpl_9f3k2m1x",
                createdAt: now.addingTimeInterval(Double(index - 14) * 7),
                level: levels[index % levels.count],
                message: index == 3
                    ? "Compiled successfully in 12.4s — 214 modules transformed, output written to .next/"
                    : "Step \(index): running build pipeline task"
            )
        }
        try snapshotWindow(
            LogsView(store: store),
            size: CGSize(width: 860, height: 560),
            name: "logs"
        )
    }

    // MARK: - Rendering helpers

    private func snapshotFittingHeight(_ view: some View, width: CGFloat, name: String) throws {
        let framed = AnyView(view.frame(width: width).background(Color(nsColor: .windowBackgroundColor)))
        let hosting = NSHostingView(rootView: framed)
        hosting.frame.size = hosting.fittingSize
        let size = hosting.fittingSize
        for appearance in [NSAppearance.Name.darkAqua, .aqua] {
            let window = NSWindow(
                contentRect: CGRect(origin: .zero, size: size),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            defer { window.close() }
            window.appearance = NSAppearance(named: appearance)
            window.contentView = NSHostingView(rootView: framed)
            window.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))
            try capture(window.contentView!, name: "\(name)-\(appearance == .darkAqua ? "dark" : "light")")
        }
    }

    private func snapshotWindow(_ view: some View, size: CGSize, name: String) throws {
        for appearance in [NSAppearance.Name.darkAqua, .aqua] {
            let controller = NSHostingController(rootView: AnyView(view))
            let window = NSWindow(contentViewController: controller)
            window.isReleasedWhenClosed = false
            defer { window.close() }
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.appearance = NSAppearance(named: appearance)
            window.setContentSize(size)
            window.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.6))
            let frameView = window.contentView!.superview ?? window.contentView!
            try capture(frameView, name: "\(name)-\(appearance == .darkAqua ? "dark" : "light")")
        }
    }

    private func capture(_ view: NSView, name: String) throws {
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            XCTFail("No bitmap rep for \(name)")
            return
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            XCTFail("No PNG data for \(name)")
            return
        }
        try data.write(to: URL(fileURLWithPath: "\(Self.outputDir)/\(name).png"))
    }
}
