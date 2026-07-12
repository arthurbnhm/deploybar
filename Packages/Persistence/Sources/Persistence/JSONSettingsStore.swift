import Core
import Foundation

public final class JSONSettingsStore: SettingsStore {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileURL: URL

    public init(fileURL: URL? = nil) throws {
        self.fileURL = try fileURL ?? AppPaths.settingsFileURL()
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    public func load() throws -> AppSettings {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return AppSettings()
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            // An I/O error reading an existing file is not corruption — falling
            // back to defaults here would silently wipe good settings on a
            // transient read failure, so this still throws.
            throw DeployBarError.persistence("Failed to load settings: \(error.localizedDescription)")
        }

        do {
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            // A corrupt or schema-incompatible settings.json shouldn't block
            // the app from starting monitoring. Move the bad file aside for
            // forensics and recover to defaults instead of throwing.
            moveCorruptFileAside()
            return AppSettings()
        }
    }

    private func moveCorruptFileAside() {
        let fm = FileManager.default
        let corruptURL = URL(fileURLWithPath: fileURL.path + ".corrupt")

        if fm.fileExists(atPath: corruptURL.path) {
            try? fm.removeItem(at: corruptURL)
        }

        try? fm.moveItem(at: fileURL, to: corruptURL)
    }

    public func save(_ settings: AppSettings) throws {
        do {
            let data = try encoder.encode(settings)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw DeployBarError.persistence("Failed to save settings: \(error.localizedDescription)")
        }
    }

    public func clear() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                throw DeployBarError.persistence("Failed to clear settings: \(error.localizedDescription)")
            }
        }
    }
}
