// The MIT License (MIT)
//
// Copyright (c) 2021-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Allows you to modify ``APIClient`` behavior.
public protocol APIClientDelegate {
    /// Allows you to modify the request right before it is sent.
    ///
    /// Gets called right before sending the request. If the retries are enabled,
    /// is called before every attempt.
    func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws

    /// Called when a request fails — either from a transport error (network
    /// failure, timeout) or a non-2xx HTTP response.
    ///
    /// Use this to handle global concerns like token refresh on 401:
    ///
    ///     func client(_ client: APIClient, shouldRetry task: URLSessionTask,
    ///                 response: HTTPURLResponse?, error: Error, attempts: Int) async throws -> Bool {
    ///         if response?.statusCode == 401, attempts == 1 {
    ///             await refreshToken()
    ///             return true
    ///         }
    ///         return false
    ///     }
    ///
    /// - returns: Return `true` to retry the request.
    func client(_ client: APIClient, shouldRetry task: URLSessionTask, response: HTTPURLResponse?, error: Error, attempts: Int) async throws -> Bool

    /// Called once a non-2xx HTTP response is final — after any retry has been
    /// declined or exhausted — with the raw response body, right before it is
    /// decoded into the typed error and thrown.
    ///
    /// Unlike ``client(_:shouldRetry:response:error:attempts:)``, this receives
    /// the response `data`, so it can inspect an error payload (e.g. a
    /// discriminator `code`) to drive cross-cutting reactions. It is purely
    /// observational: the request still fails and the typed error is still
    /// thrown to the caller. Not called for transport-level failures (which have
    /// no HTTP response) or for 2xx responses.
    func client(_ client: APIClient, didReceiveErrorResponse response: HTTPURLResponse?, data: Data, for request: URLRequest?) async

    /// Constructs URL for the given request.
    ///
    /// - returns: The URL for the request. Return `nil` to use the default
    /// logic used by client.
    func client<T, E: RequestError>(_ client: APIClient, makeURLForRequest request: Request<T, E>) throws -> URL?

    /// Allows you to override the client's encoder for a specific request.
    func client<T, E: RequestError>(_ client: APIClient, encoderForRequest request: Request<T, E>) -> JSONEncoder?

    /// Allows you to override the client's decoder for a specific request.
    func client<T, E: RequestError>(_ client: APIClient, decoderForRequest request: Request<T, E>) -> JSONDecoder?
}

public extension APIClientDelegate {
    func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
        // Do nothing
    }

    func client(_ client: APIClient, shouldRetry task: URLSessionTask, response: HTTPURLResponse?, error: Error, attempts: Int) async throws -> Bool {
        false
    }

    func client(_ client: APIClient, didReceiveErrorResponse response: HTTPURLResponse?, data: Data, for request: URLRequest?) async {
        // Do nothing
    }

    func client<T, E: RequestError>(_ client: APIClient, makeURLForRequest request: Request<T, E>) throws -> URL? {
        nil
    }

    func client<T, E: RequestError>(_ client: APIClient, encoderForRequest request: Request<T, E>) -> JSONEncoder? {
        nil
    }

    func client<T, E: RequestError>(_ client: APIClient, decoderForRequest request: Request<T, E>) -> JSONDecoder? {
        nil
    }
}

struct DefaultAPIClientDelegate: APIClientDelegate {}
