// The MIT License (MIT)
//
// Copyright (c) 2021-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Performs network requests constructed using ``Request``.
public actor APIClient {
    /// The configuration with which the client was initialized with.
    public nonisolated let configuration: Configuration
    /// The underlying `URLSession` instance.
    public nonisolated let session: URLSession

    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let delegate: APIClientDelegate
    private let dataLoader = DataLoader()

    /// The configuration for ``APIClient``.
    public struct Configuration: @unchecked Sendable {
        /// A base URL. For example, `"https://api.github.com"`.
        public var baseURL: URL?
        /// The client delegate. The client holds a strong reference to it.
        public var delegate: APIClientDelegate?
        /// By default, `URLSessionConfiguration.default`.
        public var sessionConfiguration: URLSessionConfiguration = .default
        /// The (optional) URLSession delegate that allows you to monitor the underlying URLSession.
        public var sessionDelegate: URLSessionDelegate?
        /// Overrides the default delegate queue.
        public var sessionDelegateQueue: OperationQueue?
        /// By default, uses `.iso8601` date decoding strategy.
        public var decoder: JSONDecoder
        /// By default, uses `.iso8601` date encoding strategy.
        public var encoder: JSONEncoder

        /// Initializes the configuration.
        public init(
            baseURL: URL?,
            sessionConfiguration: URLSessionConfiguration = .default,
            delegate: APIClientDelegate? = nil
        ) {
            self.baseURL = baseURL
            self.sessionConfiguration = sessionConfiguration
            self.delegate = delegate
            self.decoder = JSONDecoder()
            self.decoder.dateDecodingStrategy = .iso8601
            self.encoder = JSONEncoder()
            self.encoder.dateEncodingStrategy = .iso8601
        }
    }

    // MARK: Initializers

    /// Initializes the client with the given parameters.
    public init(baseURL: URL?, _ configure: @Sendable (inout APIClient.Configuration) -> Void = { _ in }) {
        var configuration = Configuration(baseURL: baseURL)
        configure(&configuration)
        self.init(configuration: configuration)
    }

    /// Initializes the client with the given configuration.
    public init(configuration: Configuration) {
        self.configuration = configuration
        let delegateQueue = configuration.sessionDelegateQueue ?? .serial()
        self.session = URLSession(configuration: configuration.sessionConfiguration, delegate: dataLoader, delegateQueue: delegateQueue)
        self.dataLoader.userSessionDelegate = configuration.sessionDelegate
        self.delegate = configuration.delegate ?? DefaultAPIClientDelegate()
        self.decoder = configuration.decoder
        self.encoder = configuration.encoder
    }

    // MARK: Sending Requests

    /// Sends the given request and returns a decoded response.
    ///
    /// On non-2xx responses, decodes the error body using the request's
    /// ``RequestError`` conformance and throws the typed error. Network
    /// and decoding failures are wrapped via ``RequestError/unhandled(_:)``.
    @discardableResult public func send<T: Decodable, E: RequestError>(
        _ request: Request<T, E>,
        delegate: URLSessionDataDelegate? = nil,
        configure: ((inout URLRequest) throws -> Void)? = nil
    ) async throws(E) -> Response<T> {
        do {
            let response = try await sendData(for: request, delegate: delegate, configure: configure)
            let decoder = self.delegate.client(self, decoderForRequest: request) ?? self.decoder
            let value: T = try await decode(response.data, using: decoder)
            return response.map { _ in value }
        } catch let error as E {
            throw error
        } catch {
            throw E.unhandled(error)
        }
    }

    /// Sends the given request (Void response).
    @discardableResult public func send<E: RequestError>(
        _ request: Request<Void, E>,
        delegate: URLSessionDataDelegate? = nil,
        configure: ((inout URLRequest) throws -> Void)? = nil
    ) async throws(E) -> Response<Void> {
        do {
            let response = try await sendData(for: request, delegate: delegate, configure: configure)
            return response.map { _ in () }
        } catch let error as E {
            throw error
        } catch {
            throw E.unhandled(error)
        }
    }

    /// Fetches raw data, handles non-2xx with error decoding and retry.
    private func sendData<T, E: RequestError>(
        for request: Request<T, E>,
        attempts: Int = 1,
        delegate: URLSessionDataDelegate? = nil,
        configure: ((inout URLRequest) throws -> Void)? = nil
    ) async throws -> Response<Data> {
        let response = try await rawData(for: request, delegate: delegate, configure: configure)
        let httpResponse = response.response as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode ?? 0

        if (200..<300).contains(statusCode) {
            return response
        }

        // Give the delegate a chance to retry (e.g. refresh token on 401)
        let error = APIError.unacceptableStatusCode(statusCode)
        if try await self.delegate.client(self, shouldRetry: response.task, response: httpResponse, error: error, attempts: attempts) {
            return try await sendData(for: request, attempts: attempts + 1, delegate: delegate, configure: configure)
        }

        // No retry — decode into the typed error
        let decoder = self.delegate.client(self, decoderForRequest: request) ?? self.decoder
        throw try E.decode(statusCode: statusCode, data: response.data, decoder: decoder)
    }

    // MARK: Fetching Raw Data

    /// Fetches raw response data without status code validation.
    private func rawData<T, E: RequestError>(
        for request: Request<T, E>,
        delegate: URLSessionDataDelegate? = nil,
        configure: ((inout URLRequest) throws -> Void)? = nil
    ) async throws -> Response<Data> {
        let urlRequest = try await makeURLRequest(for: request, configure)
        return try await performRequest {
            var urlRequest = urlRequest
            try await self.delegate.client(self, willSendRequest: &urlRequest)
            let task = session.dataTask(with: urlRequest)
            do {
                return try await dataLoader.startDataTask(task, session: session, delegate: delegate)
            } catch {
                throw DataLoaderError(task: task, error: error)
            }
        }
    }

#if !os(Linux)

    // MARK: Downloads

    /// Downloads the requested data to a file.
    public func download<T, E: RequestError>(
        for request: Request<T, E>,
        delegate: URLSessionDownloadDelegate? = nil,
        configure: ((inout URLRequest) throws -> Void)? = nil
    ) async throws -> Response<URL> {
        var urlRequest = try await makeURLRequest(for: request, configure)
        try await self.delegate.client(self, willSendRequest: &urlRequest)
        let task = session.downloadTask(with: urlRequest)
        return try await _startDownloadTask(task, delegate: delegate)
    }

    /// Resumes the download from the given resume data.
    public func download(
        resumeFrom resumeData: Data,
        delegate: URLSessionDownloadDelegate? = nil
    ) async throws -> Response<URL> {
        let task = session.downloadTask(withResumeData: resumeData)
        return try await _startDownloadTask(task, delegate: delegate)
    }

    private func _startDownloadTask(
        _ task: URLSessionDownloadTask,
        delegate: URLSessionDownloadDelegate?
    ) async throws -> Response<URL> {
        let response = try await dataLoader.startDownloadTask(task, session: session, delegate: delegate)
        return response
    }

#endif

    // MARK: Upload

    @discardableResult public func upload<T: Decodable, E: RequestError>(
        for request: Request<T, E>,
        fromFile fileURL: URL,
        delegate: URLSessionTaskDelegate? = nil,
        configure: ((inout URLRequest) throws -> Void)? = nil
    ) async throws -> Response<T> {
        let response = try await _upload(for: request, fromFile: fileURL, delegate: delegate, configure: configure)
        let decoder = self.delegate.client(self, decoderForRequest: request) ?? self.decoder
        let value: T = try await decode(response.data, using: decoder)
        return response.map { _ in value }
    }

    @discardableResult public func upload<E: RequestError>(
        for request: Request<Void, E>,
        fromFile fileURL: URL,
        delegate: URLSessionTaskDelegate? = nil,
        configure: ((inout URLRequest) throws -> Void)? = nil
    ) async throws -> Response<Void> {
        try await _upload(for: request, fromFile: fileURL, delegate: delegate, configure: configure).map { _ in () }
    }

    private func _upload<T, E: RequestError>(
        for request: Request<T, E>,
        fromFile fileURL: URL,
        delegate: URLSessionTaskDelegate?,
        configure: ((inout URLRequest) throws -> Void)?
    ) async throws -> Response<Data> {
        let urlRequest = try await makeURLRequest(for: request, configure)
        return try await performRequest {
            var urlRequest = urlRequest
            try await self.delegate.client(self, willSendRequest: &urlRequest)
            let task = session.uploadTask(with: urlRequest, fromFile: fileURL)
            do {
                let response = try await dataLoader.startUploadTask(task, session: session, delegate: delegate)
                return response
            } catch {
                throw DataLoaderError(task: task, error: error)
            }
        }
    }

    // MARK: Upload Data

    @discardableResult public func upload<T: Decodable, E: RequestError>(
        for request: Request<T, E>,
        from data: Data,
        delegate: URLSessionTaskDelegate? = nil,
        configure: ((inout URLRequest) throws -> Void)? = nil
    ) async throws -> Response<T> {
        let response = try await _upload(for: request, from: data, delegate: delegate, configure: configure)
        let decoder = self.delegate.client(self, decoderForRequest: request) ?? self.decoder
        let value: T = try await decode(response.data, using: decoder)
        return response.map { _ in value }
    }

    @discardableResult public func upload<E: RequestError>(
        for request: Request<Void, E>,
        from data: Data,
        delegate: URLSessionTaskDelegate? = nil,
        configure: ((inout URLRequest) throws -> Void)? = nil
    ) async throws -> Response<Void> {
        try await _upload(for: request, from: data, delegate: delegate, configure: configure).map { _ in () }
    }

    private func _upload<T, E: RequestError>(
        for request: Request<T, E>,
        from data: Data,
        delegate: URLSessionTaskDelegate?,
        configure: ((inout URLRequest) throws -> Void)?
    ) async throws -> Response<Data> {
        let urlRequest = try await makeURLRequest(for: request, configure)
        return try await performRequest {
            var urlRequest = urlRequest
            try await self.delegate.client(self, willSendRequest: &urlRequest)
            let task = session.uploadTask(with: urlRequest, from: data)
            do {
                let response = try await dataLoader.startUploadTask(task, session: session, delegate: delegate)
                return response
            } catch {
                throw DataLoaderError(task: task, error: error)
            }
        }
    }

    // MARK: Making Requests

    /// Creates `URLRequest` for the given request.
    public func makeURLRequest<T, E: RequestError>(for request: Request<T, E>) async throws -> URLRequest {
        try await makeURLRequest(for: request, { _ in })
    }

    private func makeURLRequest<T, E: RequestError>(
        for request: Request<T, E>,
        _ configure: ((inout URLRequest) throws -> Void)?
    ) async throws -> URLRequest {
        let url = try makeURL(for: request)
        var urlRequest = URLRequest(url: url)
        urlRequest.allHTTPHeaderFields = request.headers
        urlRequest.httpMethod = request.method.rawValue
        if let body = request.body {
            let encoder = delegate.client(self, encoderForRequest: request) ?? self.encoder
            urlRequest.httpBody = try await encode(body, using: encoder)
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil &&
                session.configuration.httpAdditionalHeaders?["Content-Type"] == nil {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        if urlRequest.value(forHTTPHeaderField: "Accept") == nil &&
            session.configuration.httpAdditionalHeaders?["Accept"] == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        if let configure = configure {
            try configure(&urlRequest)
        }
        return urlRequest
    }

    private func makeURL<T, E: RequestError>(for request: Request<T, E>) throws -> URL {
        if let url = try delegate.client(self, makeURLForRequest: request) {
            return url
        }
        func makeURL() -> URL? {
            guard let url = request.url else {
                return nil
            }
            return url.scheme == nil ? configuration.baseURL?.appendingPathComponent(url.absoluteString) : url
        }
        guard let url = makeURL(), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        if let query = request.query, !query.isEmpty {
            components.queryItems = query.map(URLQueryItem.init)
        }
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    // MARK: Helpers

    private func performRequest<T>(attempts: Int = 1, send: () async throws -> T) async throws -> T {
        do {
            return try await send()
        } catch {
            guard let error = error as? DataLoaderError else {
                throw error
            }
            guard try await delegate.client(self, shouldRetry: error.task, response: nil, error: error.error, attempts: attempts) else {
                throw error.error
            }
            return try await performRequest(attempts: attempts + 1, send: send)
        }
    }
}

/// Represents an error encountered by the client.
public enum APIError: Error, LocalizedError {
    case unacceptableStatusCode(Int)

    /// Returns the debug description.
    public var errorDescription: String? {
        switch self {
        case .unacceptableStatusCode(let statusCode):
            return "Response status code was unacceptable: \(statusCode)."
        }
    }
}
