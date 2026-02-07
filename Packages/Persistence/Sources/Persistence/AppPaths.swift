import Foundation

public enum AppPaths {
    public static func applicationSupportDirectory() throws -> URL {
        let fm = FileManager.default
        let base = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("DeployBar", isDirectory: true)
        if !fm.fileExists(atPath: directory.path) {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    public static func settingsFileURL() throws -> URL {
        try applicationSupportDirectory().appendingPathComponent("settings.json", isDirectory: false)
    }

    public static func databaseURL() throws -> URL {
        try applicationSupportDirectory().appendingPathComponent("deployments.sqlite", isDirectory: false)
    }
}
