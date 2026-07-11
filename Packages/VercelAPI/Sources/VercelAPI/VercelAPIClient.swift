import Core
import Foundation

public final class VercelAPIClient: VercelClient {
    private static let appVersion = "0.1.0"

    private let baseURL = URL(string: "https://api.vercel.com")!
    private let decoder: JSONDecoder
    private let session: URLSession
    private let tokenProvider: @Sendable () throws -> String?

    public init(
        session: URLSession = .shared,
        tokenProvider: @escaping @Sendable () throws -> String?
    ) {
        self.session = session
        self.tokenProvider = tokenProvider
        self.decoder = JSONDecoder()
    }

    public func validateToken() async throws -> AuthUser {
        let request = try makeRequest(path: "/v2/user")
        let payload: UserResponse = try await send(request, as: UserResponse.self)
        return AuthUser(id: payload.user.id, username: payload.user.username, email: payload.user.email)
    }

    public func listTeams(limit: Int, until: Int?) async throws -> [Team] {
        var allTeams: [Team] = []
        var nextCursor = until
        var seenCursors = Set<Int>()
        if let until {
            seenCursors.insert(until)
        }

        repeat {
            let page = try await listTeamsPage(limit: limit, until: nextCursor)
            allTeams.append(contentsOf: page.teams)
            nextCursor = page.nextCursor

            if let nextCursor {
                guard seenCursors.insert(nextCursor).inserted else {
                    throw DeployBarError.networking("Vercel teams pagination returned a repeated cursor.")
                }
            }
        } while nextCursor != nil

        return allTeams
    }

    public func listProjects(teamId: String?, limit: Int, until: String?) async throws -> [Project] {
        var allProjects: [Project] = []
        var nextCursor = until
        var seenCursors = Set<String>()
        if let until {
            seenCursors.insert(until)
        }

        repeat {
            let page = try await listProjectsPage(teamId: teamId, limit: limit, until: nextCursor)
            allProjects.append(contentsOf: page.projects)
            nextCursor = page.nextCursor

            if let nextCursor {
                guard seenCursors.insert(nextCursor).inserted else {
                    throw DeployBarError.networking("Vercel projects pagination returned a repeated cursor.")
                }
            }
        } while nextCursor != nil

        return allProjects
    }

    private func listTeamsPage(limit: Int, until: Int?) async throws -> (teams: [Team], nextCursor: Int?) {
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let until {
            queryItems.append(URLQueryItem(name: "until", value: "\(until)"))
        }

        let request = try makeRequest(path: "/v2/teams", queryItems: queryItems)
        let payload: TeamListResponse = try await send(request, as: TeamListResponse.self)
        return (
            payload.teams.map { Team(id: $0.id, slug: $0.slug, name: $0.name) },
            payload.pagination?.next
        )
    }

    private func listProjectsPage(teamId: String?, limit: Int, until: String?) async throws -> (projects: [Project], nextCursor: String?) {
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let teamId {
            queryItems.append(URLQueryItem(name: "teamId", value: teamId))
        }
        if let until {
            queryItems.append(URLQueryItem(name: "until", value: "\(until)"))
        }

        let request = try makeRequest(path: "/v10/projects", queryItems: queryItems)
        let payload: ProjectListResponse = try await send(request, as: ProjectListResponse.self)

        return (
            payload.projects.map {
                Project(
                    id: $0.id,
                    name: $0.name,
                    teamId: $0.accountId,
                    updatedAt: Date(timeIntervalSince1970: TimeInterval($0.updatedAt) / 1000)
                )
            },
            payload.pagination?.next
        )
    }

    public func latestProductionDeployment(projectId: String, teamId: String?) async throws -> DeploymentSnapshot? {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "projectId", value: projectId),
            URLQueryItem(name: "target", value: "production"),
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "_ts", value: "\(Int(Date().timeIntervalSince1970))")
        ]

        if let teamId {
            queryItems.append(URLQueryItem(name: "teamId", value: teamId))
        }

        let request = try makeRequest(path: "/v6/deployments", queryItems: queryItems)
        let payload: DeploymentListResponse = try await send(request, as: DeploymentListResponse.self)

        guard let deployment = payload.deployments.first else {
            return nil
        }

        return DeploymentSnapshot(
            id: deployment.uid,
            projectId: deployment.projectId,
            stage: DeploymentStageMapper.map(state: deployment.state, readyState: deployment.readyState),
            createdAt: Date(timeIntervalSince1970: TimeInterval(deployment.created) / 1000),
            url: URL(string: "https://\(deployment.url)"),
            commitMessage: deployment.meta?.githubCommitMessage
        )
    }

    public func deploymentEvents(deploymentId: String, limit: Int, since: Int?) async throws -> [DeploymentEvent] {
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let since {
            queryItems.append(URLQueryItem(name: "since", value: "\(since)"))
        }

        let request = try makeRequest(path: "/v2/deployments/\(deploymentId)/events", queryItems: queryItems)
        let payload: DeploymentEventListResponse = try await send(request, as: DeploymentEventListResponse.self)

        return payload.events.map { event in
            DeploymentEvent(
                id: "\(deploymentId)-\(event.id)",
                deploymentId: deploymentId,
                createdAt: Date(timeIntervalSince1970: TimeInterval(event.created) / 1000),
                level: event.type,
                message: event.text
            )
        }
    }

    private func makeRequest(path: String, queryItems: [URLQueryItem] = []) throws -> URLRequest {
        guard let token = try tokenProvider()?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            throw DeployBarError.missingToken
        }

        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw DeployBarError.networking("Invalid URL for Vercel API request.")
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("DeployBar/\(Self.appVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                throw CancellationError()
            }
            throw DeployBarError.networking("Network error: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw DeployBarError.networking("Unexpected response type from Vercel API.")
        }

        switch http.statusCode {
        case 200 ... 299:
            do {
                return try decoder.decode(type, from: data)
            } catch {
                throw DeployBarError.networking("Decoding error: \(error.localizedDescription)")
            }

        case 401, 403:
            throw DeployBarError.unauthorized

        case 429:
            let resetTimestamp = http.value(forHTTPHeaderField: "X-RateLimit-Reset")
                .flatMap(Int.init)
                .map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? Date().addingTimeInterval(30)
            throw DeployBarError.rateLimited(resetAt: resetTimestamp)

        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw DeployBarError.networking("Vercel API error \(http.statusCode): \(body)")
        }
    }
}
