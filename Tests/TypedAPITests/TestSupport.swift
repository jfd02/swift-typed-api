import Foundation
import TypedAPI
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Mock URLProtocol

/// A `URLProtocol` that intercepts every request and returns a canned response,
/// allowing the runtime to be tested without hitting the network.
final class MockURLProtocol: URLProtocol {
    struct Stub {
        var statusCode: Int
        var data: Data
        var headers: [String: String]

        init(statusCode: Int, data: Data = Data(), headers: [String: String] = [:]) {
            self.statusCode = statusCode
            self.data = data
            self.headers = headers
        }
    }

    /// Returns the response (or transport error) for a given request. The
    /// closure is invoked once per task, so it can vary its result by attempt.
    nonisolated(unsafe) static var responder: ((URLRequest) -> Result<Stub, Error>)?
    /// The most recent request seen by the protocol (for assertions).
    nonisolated(unsafe) static var lastRequest: URLRequest?

    static func reset() {
        responder = nil
        lastRequest = nil
    }

    /// Configures a client whose session routes through this mock protocol.
    static func makeClient(
        baseURL: URL? = URL(string: "https://example.com"),
        delegate: APIClientDelegate? = nil
    ) -> APIClient {
        APIClient(baseURL: baseURL) { configuration in
            let sessionConfiguration = URLSessionConfiguration.ephemeral
            sessionConfiguration.protocolClasses = [MockURLProtocol.self]
            configuration.sessionConfiguration = sessionConfiguration
            configuration.delegate = delegate
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.lastRequest = request

        guard let responder = MockURLProtocol.responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        switch responder(request) {
        case .success(let stub):
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: stub.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: stub.headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension URLRequest {
    /// Reads the request body, transparently draining `httpBodyStream` (which
    /// `URLSession` populates instead of `httpBody` for uploads).
    var resolvedBody: Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

// MARK: - Fixtures

struct Pet: Codable, Equatable {
    var id: Int
    var name: String
}

struct APIErrorBody: Codable, Equatable {
    var message: String
}

/// Mirrors the shape of a generated `RequestError` enum.
enum PetError: RequestError {
    case conflict(APIErrorBody)
    case notFound
    case unhandled(any Error)

    static func decode(statusCode: Int, data: Data, decoder: JSONDecoder) throws -> Self {
        switch statusCode {
        case 409: return .conflict(try decoder.decode(APIErrorBody.self, from: data))
        case 404: return .notFound
        default: return .unhandled(APIError.unacceptableStatusCode(statusCode))
        }
    }

    var statusCode: Int? {
        switch self {
        case .conflict: return 409
        case .notFound: return 404
        case .unhandled(let error): return (error as? APIError)?.statusCode
        }
    }

    var underlyingError: (any Error)? {
        switch self {
        case .unhandled(let error): return error
        default: return nil
        }
    }
}

func jsonData<T: Encodable>(_ value: T) -> Data {
    let encoder = JSONEncoder()
    return try! encoder.encode(value)
}
