import Core
import Foundation

enum AuthBootstrapService {
    struct StartupContext {
        let settings: AppSettings
        let storedToken: String
    }

    static func loadStartupContext(
        settingsStore: SettingsStore,
        tokenStore: SecureTokenStore
    ) throws -> StartupContext {
        let settings = try settingsStore.load()
        let storedToken = try tokenStore.readToken()?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return StartupContext(settings: settings, storedToken: storedToken)
    }

    static func shouldRequireTokenReconnect(for error: Error) -> Bool {
        guard let deployError = error as? DeployBarError else {
            return false
        }

        switch deployError {
        case .unauthorized, .invalidToken, .missingToken:
            return true
        case .forbiddenAction, .projectNotFound, .rateLimited, .networking, .persistence, .unsupportedArchitecture:
            return false
        }
    }
}
