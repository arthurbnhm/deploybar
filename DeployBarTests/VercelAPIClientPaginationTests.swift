import Core
@testable import VercelAPI
import XCTest

final class VercelAPIClientPaginationTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testListTeamsFollowsTimestampPagination() async throws {
        let recorder = RequestRecorder()
        StubURLProtocol.handler = { request in
            recorder.record(request)

            let query = request.queryItems
            if query["until"] == nil {
                return (
                    200,
                    #"{"teams":[{"id":"team_1","slug":"one","name":"One"}],"pagination":{"count":1,"next":111,"prev":null}}"#,
                    [:]
                )
            }

            XCTAssertEqual(query["until"], "111")
            return (
                200,
                #"{"teams":[{"id":"team_2","slug":"two","name":"Two"}],"pagination":{"count":1,"next":null,"prev":222}}"#,
                [:]
            )
        }

        let client = makeClient()
        let teams = try await client.listTeams(limit: 1, until: nil)

        XCTAssertEqual(teams.map(\.id), ["team_1", "team_2"])
        XCTAssertEqual(recorder.requests.count, 2)
        XCTAssertEqual(recorder.requests.first?.value(forHTTPHeaderField: "User-Agent"), "DeployBar/0.1.0")
    }

    func testListProjectsFollowsContinuationPagination() async throws {
        let recorder = RequestRecorder()
        StubURLProtocol.handler = { request in
            recorder.record(request)

            let query = request.queryItems
            XCTAssertEqual(query["teamId"], "team_1")

            if query["until"] == nil {
                return (
                    200,
                    #"{"projects":[{"id":"project_1","name":"One","accountId":"team_1","updatedAt":1739000000000}],"pagination":{"count":1,"next":1739000000500}}"#,
                    [:]
                )
            }

            XCTAssertEqual(query["until"], "1739000000500")
            return (
                200,
                #"{"projects":[{"id":"project_2","name":"Two","accountId":"team_1","updatedAt":1739000001000}],"pagination":{"count":1,"next":null}}"#,
                [:]
            )
        }

        let client = makeClient()
        let projects = try await client.listProjects(teamId: "team_1", limit: 1, until: nil)

        XCTAssertEqual(projects.map(\.id), ["project_1", "project_2"])
        XCTAssertEqual(recorder.requests.count, 2)
        XCTAssertTrue(recorder.requests.allSatisfy { $0.url?.path == "/v10/projects" })
    }

    func testListProjectsAcceptsStringCursor() async throws {
        let recorder = RequestRecorder()
        StubURLProtocol.handler = { request in
            recorder.record(request)

            let query = request.queryItems
            XCTAssertEqual(query["teamId"], "team_1")

            if query["until"] == nil {
                return (
                    200,
                    #"{"projects":[{"id":"project_1","name":"One","accountId":"team_1","updatedAt":1739000000000}],"pagination":{"count":1,"next":"cursor_2"}}"#,
                    [:]
                )
            }

            XCTAssertEqual(query["until"], "cursor_2")
            return (
                200,
                #"{"projects":[{"id":"project_2","name":"Two","accountId":"team_1","updatedAt":1739000001000}],"pagination":{"count":1,"next":null}}"#,
                [:]
            )
        }

        let client = makeClient()
        let projects = try await client.listProjects(teamId: "team_1", limit: 1, until: nil)

        XCTAssertEqual(projects.map(\.id), ["project_1", "project_2"])
        XCTAssertEqual(recorder.requests.count, 2)
        XCTAssertTrue(recorder.requests.allSatisfy { $0.url?.path == "/v10/projects" })
    }

    func testListProjectsStopsOnNullCursor() async throws {
        let recorder = RequestRecorder()
        StubURLProtocol.handler = { request in
            recorder.record(request)

            return (
                200,
                #"{"projects":[{"id":"project_1","name":"One","accountId":"team_1","updatedAt":1739000000000}],"pagination":{"count":1,"next":null}}"#,
                [:]
            )
        }

        let client = makeClient()
        let projects = try await client.listProjects(teamId: "team_1", limit: 1, until: nil)

        XCTAssertEqual(projects.map(\.id), ["project_1"])
        XCTAssertEqual(recorder.requests.count, 1)
    }

    private func makeClient() -> VercelAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)

        return VercelAPIClient(session: session) {
            "token"
        }
    }
}
