import Foundation

/// A protocol that typed API errors conform to, enabling automatic error
/// decoding from HTTP responses.
///
/// Generated error enums conform to this protocol. The ``APIClient`` uses
/// ``decode(statusCode:data:decoder:)`` to convert non-2xx HTTP responses
/// into the concrete error type, and ``unhandled(_:)`` to wrap any
/// transport-level failures (network errors, decoding errors, etc.).
public protocol RequestError: Error {
    /// Decodes an HTTP error response into this error type.
    ///
    /// Called by ``APIClient`` when the server returns a non-2xx status code.
    /// Implementations switch on the status code and decode the response body
    /// into the appropriate case.
    static func decode(statusCode: Int, data: Data, decoder: JSONDecoder) throws -> Self

    /// Wraps a non-API error (network failure, decoding error, etc.).
    static func unhandled(_ error: any Error) -> Self

    /// Returns the wrapped error if this is an ``unhandled`` case, otherwise `nil`.
    var underlyingError: (any Error)? { get }

    /// The HTTP status code associated with this error, when known.
    ///
    /// Generated conformances return the documented status code for each case.
    var statusCode: Int? { get }
}

extension RequestError {
    public var underlyingError: (any Error)? {
        let mirror = Mirror(reflecting: self)
        guard let child = mirror.children.first,
              child.label == "unhandled" else { return nil }
        return child.value as? any Error
    }

    /// Recovers the status code from an ``unhandled`` error that wraps
    /// ``APIError/unacceptableStatusCode(_:)``. Generated conformances override
    /// this to return the documented status code for each case.
    public var statusCode: Int? {
        (underlyingError as? APIError)?.statusCode
    }
}

/// Default error type for requests without documented error responses.
///
/// Used as the default `Failure` type on ``Request`` when no error enum
/// is generated. Non-2xx responses throw ``APIError/unacceptableStatusCode(_:)``
/// wrapped in ``unhandled(_:)``.
public enum DefaultRequestError: RequestError {
    case unhandled(any Error)

    public static func decode(statusCode: Int, data: Data, decoder: JSONDecoder) throws -> Self {
        .unhandled(APIError.unacceptableStatusCode(statusCode))
    }

    public var underlyingError: (any Error)? {
        switch self {
        case .unhandled(let error): return error
        }
    }
}

extension DefaultRequestError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unhandled(let error): return "unhandled(\(error))"
        }
    }
}

extension DefaultRequestError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unhandled(let error):
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
