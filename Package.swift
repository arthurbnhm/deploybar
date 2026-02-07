// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeployBar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DeployBar", targets: ["DeployBarApp"])
    ],
    targets: [
        .executableTarget(
            name: "DeployBarApp",
            dependencies: ["Features"],
            path: "DeployBarApp/Sources/DeployBarApp"
        ),
        .target(
            name: "Core",
            path: "Packages/Core/Sources/Core"
        ),
        .target(
            name: "VercelAPI",
            dependencies: ["Core"],
            path: "Packages/VercelAPI/Sources/VercelAPI"
        ),
        .target(
            name: "Persistence",
            dependencies: ["Core"],
            path: "Packages/Persistence/Sources/Persistence",
            linkerSettings: [
                .linkedFramework("Security"),
                .linkedLibrary("sqlite3")
            ]
        ),
        .target(
            name: "Features",
            dependencies: ["Core", "VercelAPI", "Persistence"],
            path: "Packages/Features/Sources/Features",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("AVFoundation")
            ]
        ),
        .testTarget(
            name: "DeployBarTests",
            dependencies: ["Core", "VercelAPI", "Persistence", "Features"],
            path: "DeployBarTests"
        ),
        .testTarget(
            name: "DeployBarUITests",
            dependencies: ["Features"],
            path: "DeployBarUITests"
        )
    ]
)
