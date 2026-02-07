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

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            throw DeployBarError.persistence("Failed to load settings: \(error.localizedDescription)")
        }
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
