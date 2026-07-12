import Core
@testable import VercelAPI
import XCTest

final class VercelAPIClientErrorMappingTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testUnauthorizedMapsFor401() async throws {
        try await assertValidateTokenThrowsUnauthorized(statusCode: 401)
    }

    func testUnauthorizedMapsFor403() async throws {
        try await assertValidateTokenThrowsUnauthorized(statusCode: 403)
    }

    private func assertValidateTokenThrowsUnauthorized(statusCode: Int) async throws {
        StubURLProtocol.handler = { _ in
            (statusCode, "{}", [:])
        }

        let client = makeClient()

        do {
            _ = try await client.validateToken()
            XCTFail("Expected DeployBarError.unauthorized to be thrown for status \(statusCode).")
        } catch DeployBarError.unauthorized {
            // expected
        } catch {
            XCTFail("Expected DeployBarError.unauthorized, got \(error) for status \(statusCode).")
        }
    }

    func testRateLimitedUsesResetHeader() async throws {
        let epochSeconds = 1_800_000_000
        StubURLProtocol.handler = { _ in
            (429, "{}", ["X-RateLimit-Reset": "\(epochSeconds)"])
        }

        let client = makeClient()

        do {
            _ = try await client.validateToken()
            XCTFail("Expected DeployBarError.rateLimited to be thrown.")
        } catch DeployBarError.rateLimited(let resetAt) {
            XCTAssertEqual(resetAt, Date(timeIntervalSince1970: TimeInterval(epochSeconds)))
        } catch {
            XCTFail("Expected DeployBarError.rateLimited, got \(error).")
        }
    }

    func testRateLimitedWithoutHeaderFallsBackToThirtySeconds() async throws {
        StubURLProtocol.handler = { _ in
            (429, "{}", [:])
        }

        let client = makeClient()
        let before = Date()

        do {
            _ = try await client.validateToken()
            XCTFail("Expected DeployBarError.rateLimited to be thrown.")
        } catch DeployBarError.rateLimited(let resetAt) {
            let delta = resetAt.timeIntervalSince(before)
            XCTAssertTrue((25 ... 35).contains(delta), "Expected fallback reset ~30s from now, got \(delta)s.")
        } catch {
            XCTFail("Expected DeployBarError.rateLimited, got \(error).")
        }
    }

    func testServerErrorMapsToNetworkingWithStatusCode() async throws {
        StubURLProtocol.handler = { _ in
            (500, "boom", [:])
        }

        let client = makeClient()

        do {
            _ = try await client.validateToken()
            XCTFail("Expected DeployBarError.networking to be thrown.")
        } catch DeployBarError.networking(let message) {
            XCTAssertTrue(message.contains("500"), "Expected message to contain status code 500, got: \(message)")
        } catch {
            XCTFail("Expected DeployBarError.networking, got \(error).")
        }
    }

    func testMissingTokenThrowsWithoutMakingARequest() async throws {
        let recorder = RequestRecorder()
        StubURLProtocol.handler = { request in
            recorder.record(request)
            return (200, "{}", [:])
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = VercelAPIClient(session: session) {
            nil
        }

        do {
            _ = try await client.validateToken()
            XCTFail("Expected DeployBarError.missingToken to be thrown.")
        } catch DeployBarError.missingToken {
            // expected
        } catch {
            XCTFail("Expected DeployBarError.missingToken, got \(error).")
        }

        XCTAssertEqual(recorder.requests.count, 0)
    }

    func testValidateTokenDecodesUser() async throws {
        StubURLProtocol.handler = { _ in
            (200, #"{"user":{"id":"u1","username":"tester","email":"t@example.com"}}"#, [:])
        }

        let client = makeClient()
        let user = try await client.validateToken()

        XCTAssertEqual(user.id, "u1")
        XCTAssertEqual(user.username, "tester")
        XCTAssertEqual(user.email, "t@example.com")
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
