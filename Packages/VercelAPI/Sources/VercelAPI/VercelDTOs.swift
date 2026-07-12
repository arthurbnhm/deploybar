import Foundation

struct UserResponse: Decodable {
    let user: UserDTO
}

struct UserDTO: Decodable {
    let id: String
    let username: String
    let email: String?
}

struct TeamListResponse: Decodable {
    let teams: [TeamDTO]
    let pagination: TimestampPaginationDTO?
}

struct TeamDTO: Decodable {
    let id: String
    let slug: String
    let name: String
}

struct ProjectListResponse: Decodable {
    let projects: [ProjectDTO]
    let pagination: ContinuationPaginationDTO?

    private enum CodingKeys: String, CodingKey {
        case projects = "projects"
        case pagination
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([ProjectDTO].self) {
            self.projects = array
            self.pagination = nil
            return
        }

        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        self.projects = try keyed.decode([ProjectDTO].self, forKey: .projects)
        self.pagination = try keyed.decodeIfPresent(ContinuationPaginationDTO.self, forKey: .pagination)
    }
}

struct TimestampPaginationDTO: Decodable {
    let next: Int?
}

struct ContinuationPaginationDTO: Decodable {
    let next: String?

    private enum CodingKeys: String, CodingKey {
        case next
    }

    init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        if let numeric = try? keyed.decodeIfPresent(Int64.self, forKey: .next) {
            self.next = String(numeric)
        } else {
            self.next = try keyed.decodeIfPresent(String.self, forKey: .next)
        }
    }
}

struct ProjectDTO: Decodable {
    let id: String
    let name: String
    let accountId: String?
    let updatedAt: Int64
}

struct DeploymentListResponse: Decodable {
    let deployments: [DeploymentDTO]

    private enum CodingKeys: String, CodingKey {
        case deployments
    }

    init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        self.deployments = try keyed.decodeIfPresent([DeploymentDTO].self, forKey: .deployments) ?? []
    }
}

struct DeploymentDTO: Decodable {
    let uid: String
    let projectId: String
    let state: String?
    let readyState: String?
    let url: String
    let created: Int64
    let meta: DeploymentMeta?
}

struct DeploymentMeta: Decodable {
    let githubCommitMessage: String?

    private enum CodingKeys: String, CodingKey {
        case githubCommitMessage = "githubCommitMessage"
    }
}

/// Minimal decode of the "Cancel a deployment" response. We only need to confirm the body
/// parses as JSON; the store re-fetches fresh state via `manualRefresh()` after a cancel call
/// rather than relying on this payload, so unrecognized fields are ignored by design.
struct CancelDeploymentResponse: Decodable {
    let id: String?
    let readyState: String?
}

struct DeploymentEventListResponse: Decodable {
    let events: [DeploymentEventDTO]

    private enum CodingKeys: String, CodingKey {
        case events
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([DeploymentEventDTO].self) {
            self.events = array
            return
        }
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        self.events = try keyed.decodeIfPresent([DeploymentEventDTO].self, forKey: .events) ?? []
    }
}

struct DeploymentEventDTO: Decodable {
    let id: String
    let created: Int64
    let type: String
    let text: String

    private enum CodingKeys: String, CodingKey {
        case id
        case created
        case type
        case text
        case payload
        case message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let payload = try? container.decode(LooseJSON.self, forKey: .payload)

        if let createdInt = try? container.decode(Int64.self, forKey: .created) {
            created = createdInt
        } else if let createdDouble = try? container.decode(Double.self, forKey: .created) {
            created = Int64(createdDouble)
        } else if let createdString = try? container.decode(String.self, forKey: .created), let createdInt = Int64(createdString) {
            created = createdInt
        } else if
            let payloadDate = payload?["date"]?.int64Value
        {
            created = payloadDate
        } else {
            created = Int64(Date().timeIntervalSince1970 * 1000)
        }

        type = (try? container.decode(String.self, forKey: .type)) ?? "event"

        let resolvedText: String
        if let directText = try? container.decode(String.self, forKey: .text), !directText.isEmpty {
            resolvedText = directText
        } else if let directMessage = try? container.decode(String.self, forKey: .message), !directMessage.isEmpty {
            resolvedText = directMessage
        } else if let payload {
            if let message = payload.preferredLogMessage, !message.isEmpty {
                resolvedText = message
            } else {
                resolvedText = type
            }
        } else {
            resolvedText = type
        }
        text = resolvedText

        if let directID = try? container.decode(String.self, forKey: .id), !directID.isEmpty {
            id = directID
        } else if let payloadID = payload?["id"]?.stringValue, !payloadID.isEmpty {
            id = payloadID
        } else {
            id = Self.fallbackID(created: created, type: type, text: resolvedText)
        }
    }

    private static func fallbackID(created: Int64, type: String, text: String) -> String {
        let compactText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let fragment = String(compactText.prefix(64))
        return "event-\(created)-\(type)-\(fragment)"
    }
}

private struct LooseJSON: Decodable {
    let value: JSONNode

    init(from decoder: Decoder) throws {
        value = try JSONNode(from: decoder)
    }

    subscript(key: String) -> JSONNode? {
        guard case let .object(object) = value else {
            return nil
        }
        return object[key]
    }

    var preferredLogMessage: String? {
        value.preferredLogMessage
    }
}

private indirect enum JSONNode: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONNode])
    case object([String: JSONNode])

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer() {
            if container.decodeNil() {
                self = .null
                return
            }
            if let value = try? container.decode(String.self) {
                self = .string(value)
                return
            }
            if let value = try? container.decode(Double.self) {
                self = .number(value)
                return
            }
            if let value = try? container.decode(Bool.self) {
                self = .bool(value)
                return
            }
            if let value = try? container.decode([String: JSONNode].self) {
                self = .object(value)
                return
            }
            if let value = try? container.decode([JSONNode].self) {
                self = .array(value)
                return
            }
        }

        self = .null
    }

    var int64Value: Int64? {
        switch self {
        case let .number(number):
            return Int64(number)
        case let .string(string):
            return Int64(string)
        default:
            return nil
        }
    }

    var stringValue: String? {
        switch self {
        case let .string(string):
            return string
        case let .number(number):
            return String(number)
        case let .bool(value):
            return String(value)
        default:
            return nil
        }
    }

    var preferredLogMessage: String? {
        switch self {
        case let .string(string):
            return string

        case let .object(object):
            if
                let name = object["name"]?.stringValue,
                !name.isEmpty,
                let value = object["value"]?.stringValue,
                !value.isEmpty
            {
                return "\(name): \(value)"
            }

            let prioritizedKeys = ["text", "message", "error", "stderr", "stdout", "name", "id", "deploymentId"]
            for key in prioritizedKeys {
                if let string = object[key]?.stringValue, !string.isEmpty {
                    return string
                }
            }

            if let info = object["info"]?.preferredLogMessage, !info.isEmpty {
                return info
            }
            if let nestedPayload = object["payload"]?.preferredLogMessage, !nestedPayload.isEmpty {
                return nestedPayload
            }

            let compactPairs = object.compactMap { key, value -> String? in
                guard let string = value.stringValue, !string.isEmpty else { return nil }
                return "\(key): \(string)"
            }.sorted()

            if !compactPairs.isEmpty {
                return compactPairs.joined(separator: " | ")
            }
            return nil

        case let .array(values):
            let messages = values.compactMap(\.preferredLogMessage).filter { !$0.isEmpty }
            if messages.isEmpty {
                return nil
            }
            return messages.joined(separator: " | ")

        case let .number(number):
            return String(number)

        case let .bool(value):
            return String(value)

        case .null:
            return nil
        }
    }
}
