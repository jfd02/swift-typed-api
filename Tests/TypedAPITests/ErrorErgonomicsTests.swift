import XCTest
import TypedAPI
import Foundation

final class ErrorErgonomicsTests: XCTestCase {
    func testTypedErrorReportsDocumentedStatusCode() {
        XCTAssertEqual(PetError.conflict(.init(message: "x")).statusCode, 409)
        XCTAssertEqual(PetError.notFound.statusCode, 404)
    }

    func testUnhandledErrorRecoversWrappedAPIErrorStatusCode() {
        XCTAssertEqual(PetError.unhandled(APIError.unacceptableStatusCode(500)).statusCode, 500)
        XCTAssertNil(PetError.unhandled(URLError(.timedOut)).statusCode)
    }

    func testDefaultRequestErrorStatusCodeViaProtocolDefault() {
        XCTAssertEqual(DefaultRequestError.unhandled(APIError.unacceptableStatusCode(503)).statusCode, 503)
    }

    func testAPIErrorExposesStatusCodeAndDescription() {
        let error = APIError.unacceptableStatusCode(503)
        XCTAssertEqual(error.statusCode, 503)
        XCTAssertEqual(error.errorDescription, "Response status code was unacceptable: 503.")
        XCTAssertEqual("\(error)", "Response status code was unacceptable: 503.")
    }

    func testDefaultRequestErrorExposesUnderlyingError() {
        let error = DefaultRequestError.unhandled(APIError.unacceptableStatusCode(404))
        XCTAssertEqual((error.underlyingError as? APIError)?.statusCode, 404)
    }

    func testDefaultRequestErrorDescriptionDelegatesToUnderlying() {
        let error = DefaultRequestError.unhandled(APIError.unacceptableStatusCode(404))
        // LocalizedError forwards to the wrapped error's message.
        XCTAssertEqual(error.errorDescription, "Response status code was unacceptable: 404.")
        XCTAssertTrue("\(error)".contains("unhandled"))
    }
}
