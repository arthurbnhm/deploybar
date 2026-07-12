import Core
@testable import VercelAPI
import XCTest

final class VercelAPIClientCancelTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testCancelDeploymentSendsPatchWithTeamIdAndSucceeds() async throws {
        let recorder = RequestRecorder()
        StubURLProtocol.handler = { request in
            recorder.record(request)
            return (200, #"{"id":"dep_1","readyState":"CANCELED"}"#, [:])
        }

        let client = makeClient()
        try await client.cancelDeployment(deploymentId: "dep_1", teamId: "team_1")

        XCTAssertEqual(recorder.requests.count, 1)
        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.url?.path, "/v12/deployments/dep_1/cancel")
        XCTAssertEqual(request.queryItems["teamId"], "team_1")
    }

    func testCancelDeploymentOmitsTeamIdQueryItemWhenNil() async throws {
        let recorder = RequestRecorder()
        StubURLProtocol.handler = { request in
            recorder.record(request)
            return (200, #"{"id":"dep_1","readyState":"CANCELED"}"#, [:])
        }

        let client = makeClient()
        try await client.cancelDeployment(deploymentId: "dep_1", teamId: nil)

        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertNil(request.queryItems["teamId"])
    }

    func testCancelDeploymentMapsForbiddenToForbiddenActionNotUnauthorized() async throws {
        StubURLProtocol.handler = { _ in
            (403, #"{"error":{"code":"forbidden","message":"not allowed"}}"#, [:])
        }

        let client = makeClient()

        do {
            try await client.cancelDeployment(deploymentId: "dep_1", teamId: nil)
            XCTFail("Expected DeployBarError.forbiddenAction to be thrown.")
        } catch DeployBarError.forbiddenAction {
            // expected: a 403 on a write endpoint must NOT surface as .unauthorized,
            // because the store treats .unauthorized as a hard, token-clearing auth failure.
        } catch {
            XCTFail("Expected DeployBarError.forbiddenAction, got \(error).")
        }
    }

    func testCancelDeploymentStillMapsUnauthorizedFor401() async throws {
        StubURLProtocol.handler = { _ in
            (401, "{}", [:])
        }

        let client = makeClient()

        do {
            try await client.cancelDeployment(deploymentId: "dep_1", teamId: nil)
            XCTFail("Expected DeployBarError.unauthorized to be thrown.")
        } catch DeployBarError.unauthorized {
            // expected: 401 always means the token itself is dead, even on write endpoints.
        } catch {
            XCTFail("Expected DeployBarError.unauthorized, got \(error).")
        }
    }

    func testCancelDeploymentOnAlreadyFinishedDeploymentMapsToNetworkingError() async throws {
        StubURLProtocol.handler = { _ in
            (400, #"{"error":{"code":"bad_request","message":"Deployment is not in a cancelable state"}}"#, [:])
        }

        let client = makeClient()

        do {
            try await client.cancelDeployment(deploymentId: "dep_1", teamId: nil)
            XCTFail("Expected DeployBarError.networking to be thrown.")
        } catch DeployBarError.networking(let message) {
            XCTAssertTrue(message.contains("400"), "Expected message to contain status code 400, got: \(message)")
        } catch {
            XCTFail("Expected DeployBarError.networking, got \(error).")
        }
    }

    func testCancelDeploymentThrowsMissingTokenWithoutMakingARequest() async throws {
        let recorder = RequestRecorder()
        StubURLProtocol.handler = { request in
            recorder.record(request)
            return (200, #"{"id":"dep_1","readyState":"CANCELED"}"#, [:])
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = VercelAPIClient(session: session) {
            nil
        }

        do {
            try await client.cancelDeployment(deploymentId: "dep_1", teamId: nil)
            XCTFail("Expected DeployBarError.missingToken to be thrown.")
        } catch DeployBarError.missingToken {
            // expected
        } catch {
            XCTFail("Expected DeployBarError.missingToken, got \(error).")
        }

        XCTAssertEqual(recorder.requests.count, 0)
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
