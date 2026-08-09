import Foundation

public enum DeployBarError: Error, LocalizedError, Sendable {
    case missingToken
    case invalidToken
    case unauthorized
    case forbiddenAction
    case projectNotFound(projectID: String)
    case rateLimited(resetAt: Date)
    case networking(String)
    case persistence(String)
    case unsupportedArchitecture

    public var errorDescription: String? {
        switch self {
        case .missingToken:
            return "No Vercel token is stored."
        case .invalidToken:
            return "The Vercel token is invalid."
        case .unauthorized:
            return "The Vercel token is no longer authorized."
        case .forbiddenAction:
            return "Your Vercel token doesn't have permission to perform this action."
        case .projectNotFound:
            return "A watched Vercel project no longer exists or is no longer accessible."
        case let .rateLimited(resetAt):
            return "Rate limited by Vercel API until \(resetAt.formatted(date: .omitted, time: .shortened))."
        case let .networking(message):
            return message
        case let .persistence(message):
            return message
        case .unsupportedArchitecture:
            return "DeployBar currently supports Apple Silicon only."
        }
    }
}
