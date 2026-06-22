import XCTest
import TypedAPI
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class APIClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: Success

    func testSuccessDecodesValue() async throws {
        let pet = Pet(id: 1, name: "Fido")
        MockURLProtocol.responder = { _ in .success(.init(statusCode: 200, data: jsonData(pet))) }

        let client = MockURLProtocol.makeClient()
        let request = Request<Pet, PetError>(path: "/pets/1")
        let response = try await client.send(request)

        XCTAssertEqual(response.value, pet)
        XCTAssertEqual(response.statusCode, 200)
    }

    func testVoidResponseSucceeds() async throws {
        MockURLProtocol.responder = { _ in .success(.init(statusCode: 204)) }

        let client = MockURLProtocol.makeClient()
        let request = Request<Void, PetError>(path: "/ping", method: .post)
        let response = try await client.send(request)

        XCTAssertEqual(response.statusCode, 204)
    }

    // MARK: Typed errors

    func testDocumentedStatusDecodesTypedCaseWithBody() async throws {
        let body = APIErrorBody(message: "already exists")
        MockURLProtocol.responder = { _ in .success(.init(statusCode: 409, data: jsonData(body))) }

        let client = MockURLProtocol.makeClient()
        let request = Request<Pet, PetError>(path: "/pets", method: .post)

        do {
            _ = try await client.send(request)
            XCTFail("Expected a typed error to be thrown")
        } catch let error as PetError {
            guard case .conflict(let decoded) = error else {
                return XCTFail("Expected .conflict, got \(error)")
            }
            XCTAssertEqual(decoded, body)
            XCTAssertEqual(error.statusCode, 409)
        }
    }

    func testDocumentedStatusWithoutBody() async throws {
        MockURLProtocol.responder = { _ in .success(.init(statusCode: 404)) }

        let client = MockURLProtocol.makeClient()
        let request = Request<Pet, PetError>(path: "/pets/99")

        do {
            _ = try await client.send(request)
            XCTFail("Expected a typed error to be thrown")
        } catch let error as PetError {
            guard case .notFound = error else {
                return XCTFail("Expected .notFound, got \(error)")
            }
        }
    }

    func testUndocumentedStatusBecomesUnhandled() async throws {
        MockURLProtocol.responder = { _ in .success(.init(statusCode: 500)) }

        let client = MockURLProtocol.makeClient()
        let request = Request<Pet, PetError>(path: "/pets")

        do {
            _ = try await client.send(request)
            XCTFail("Expected a typed error to be thrown")
        } catch let error as PetError {
            guard let underlying = error.underlyingError as? APIError,
                  case .unacceptableStatusCode(let code) = underlying else {
                return XCTFail("Expected .unhandled(APIError), got \(error)")
            }
            XCTAssertEqual(code, 500)
        }
    }

    func testDecodingFailureBecomesUnhandled() async throws {
        MockURLProtocol.responder = { _ in
            .success(.init(statusCode: 200, data: Data(#"{"unexpected":true}"#.utf8)))
        }

        let client = MockURLProtocol.makeClient()
        let request = Request<Pet, PetError>(path: "/pets/1")

        do {
            _ = try await client.send(request)
            XCTFail("Expected a decoding error to be thrown")
        } catch let error as PetError {
            XCTAssertTrue(error.underlyingError is DecodingError, "Expected a DecodingError, got \(String(describing: error.underlyingError))")
        }
    }

    func testTransportErrorBecomesUnhandled() async throws {
        MockURLProtocol.responder = { _ in .failure(URLError(.notConnectedToInternet)) }

        let client = MockURLProtocol.makeClient()
        let request = Request<Pet, PetError>(path: "/pets")

        do {
            _ = try await client.send(request)
            XCTFail("Expected a transport error to be thrown")
        } catch let error as PetError {
            XCTAssertEqual((error.underlyingError as? URLError)?.code, .notConnectedToInternet)
        }
    }

    func testDefaultRequestErrorWrapsUnacceptableStatus() async throws {
        MockURLProtocol.responder = { _ in .success(.init(statusCode: 503)) }

        let client = MockURLProtocol.makeClient()
        let request = Request<Pet, DefaultRequestError>(path: "/pets")

        do {
            _ = try await client.send(request)
            XCTFail("Expected an error to be thrown")
        } catch let error as DefaultRequestError {
            guard let underlying = error.underlyingError as? APIError,
                  case .unacceptableStatusCode(let code) = underlying else {
                return XCTFail("Expected .unhandled(APIError), got \(error)")
            }
            XCTAssertEqual(code, 503)
        }
    }

    // MARK: Retry

    func testDelegateCanRetry() async throws {
        let attempts = Counter()
        MockURLProtocol.responder = { _ in
            let n = attempts.increment()
            if n == 1 {
                return .success(.init(statusCode: 401))
            }
            return .success(.init(statusCode: 200, data: jsonData(Pet(id: 7, name: "Rex"))))
        }

        let client = MockURLProtocol.makeClient(delegate: RetryOn401Delegate())
        let request = Request<Pet, PetError>(path: "/pets/7")
        let response = try await client.send(request)

        XCTAssertEqual(response.value, Pet(id: 7, name: "Rex"))
        XCTAssertEqual(attempts.value, 2, "Expected exactly one retry")
    }

    // MARK: Request building

    func testRequestIsBuiltFromBaseURLPathQueryAndHeaders() async throws {
        MockURLProtocol.responder = { _ in .success(.init(statusCode: 200, data: jsonData(Pet(id: 1, name: "Fido")))) }

        let client = MockURLProtocol.makeClient(baseURL: URL(string: "https://api.example.com"))
        let request = Request<Pet, PetError>(
            path: "/pets",
            method: .get,
            query: [("limit", "10")],
            headers: ["X-Test": "abc"]
        )
        _ = try await client.send(request)

        let sent = try XCTUnwrap(MockURLProtocol.lastRequest)
        XCTAssertEqual(sent.httpMethod, "GET")
        XCTAssertEqual(sent.url?.absoluteString, "https://api.example.com/pets?limit=10")
        XCTAssertEqual(sent.value(forHTTPHeaderField: "X-Test"), "abc")
        XCTAssertEqual(sent.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testPOSTBodyIsEncodedAsJSON() async throws {
        MockURLProtocol.responder = { _ in .success(.init(statusCode: 201, data: jsonData(Pet(id: 2, name: "Milo")))) }

        let client = MockURLProtocol.makeClient()
        let newPet = Pet(id: 2, name: "Milo")
        let request = Request<Pet, PetError>(path: "/pets", method: .post, body: newPet)
        _ = try await client.send(request)

        let sent = try XCTUnwrap(MockURLProtocol.lastRequest)
        XCTAssertEqual(sent.httpMethod, "POST")
        XCTAssertEqual(sent.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let bodyData = try XCTUnwrap(sent.resolvedBody)
        XCTAssertEqual(try JSONDecoder().decode(Pet.self, from: bodyData), newPet)
    }

    func testDelegateCanModifyOutgoingRequest() async throws {
        MockURLProtocol.responder = { _ in .success(.init(statusCode: 200, data: jsonData(Pet(id: 1, name: "Fido")))) }

        let client = MockURLProtocol.makeClient(delegate: AuthHeaderDelegate())
        let request = Request<Pet, PetError>(path: "/pets/1")
        _ = try await client.send(request)

        let sent = try XCTUnwrap(MockURLProtocol.lastRequest)
        XCTAssertEqual(sent.value(forHTTPHeaderField: "Authorization"), "Bearer token")
    }
}

// MARK: - Test helpers

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    @discardableResult
    func increment() -> Int {
        lock.lock(); defer { lock.unlock() }
        count += 1
        return count
    }

    var value: Int {
        lock.lock(); defer { lock.unlock() }
        return count
    }
}

final class RetryOn401Delegate: APIClientDelegate {
    func client(_ client: APIClient, shouldRetry task: URLSessionTask, response: HTTPURLResponse?, error: Error, attempts: Int) async throws -> Bool {
        response?.statusCode == 401 && attempts == 1
    }
}

final class AuthHeaderDelegate: APIClientDelegate {
    func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
        request.setValue("Bearer token", forHTTPHeaderField: "Authorization")
    }
}
