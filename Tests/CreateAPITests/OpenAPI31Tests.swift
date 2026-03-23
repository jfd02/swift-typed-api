import XCTest
@testable import create_api
import CreateOptions
import OpenAPIKit
import Yams

// MARK: - End-to-End Generation Tests

final class OpenAPI31EndToEndTests: XCTestCase {

    // MARK: - Petstore 3.1

    /// Tests that a basic OpenAPI 3.1 petstore spec generates entities and paths successfully.
    func testPetstore31GeneratesEntities() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: SpecFixture.petstore31.path))
        let doc = try YAMLDecoder().decode(OpenAPI.Document.self, from: data)

        let options = GenerateOptions.default
        let arguments = GenerateArguments(isVerbose: false, isParallel: false, isStrict: false, isIgnoringErrors: false)
        let generator = Generator(spec: doc, options: options, arguments: arguments)

        let schemas = try generator.schemas()
        XCTAssertFalse(schemas.files.isEmpty, "Petstore 3.1 should generate entities")

        let entityNames = Set(schemas.files.map(\.name))
        XCTAssertTrue(entityNames.contains("Pet"), "Should generate Pet entity")
        XCTAssertTrue(entityNames.contains("Error"), "Should generate Error entity")
        XCTAssertTrue(entityNames.contains("Store"), "Should generate Store entity")

        let paths = try generator.paths()
        XCTAssertFalse(paths.files.isEmpty, "Petstore 3.1 should generate paths")
    }

    // MARK: - OpenAPI 3.1 Features

    /// Tests comprehensive generation from OpenAPI 3.1 features spec.
    func testOpenAPI31FeaturesGeneratesEntities() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: SpecFixture.openapi31Features.path))
        let doc = try YAMLDecoder().decode(OpenAPI.Document.self, from: data)

        let options = GenerateOptions.default
        let arguments = GenerateArguments(isVerbose: false, isParallel: false, isStrict: false, isIgnoringErrors: false)
        let generator = Generator(spec: doc, options: options, arguments: arguments)

        let schemas = try generator.schemas()
        XCTAssertFalse(schemas.files.isEmpty, "Features spec should generate entities")

        let entityNames = Set(schemas.files.map(\.name))
        XCTAssertTrue(entityNames.contains("User"), "Should generate User entity")
        XCTAssertTrue(entityNames.contains("UserRole"), "Should generate UserRole enum")
        XCTAssertTrue(entityNames.contains("AdminUser"), "Should generate AdminUser (allOf)")
        XCTAssertTrue(entityNames.contains("Document"), "Should generate Document (oneOf)")
        XCTAssertTrue(entityNames.contains("SearchResult"), "Should generate SearchResult (anyOf)")
        XCTAssertTrue(entityNames.contains("ErrorResponse"), "Should generate ErrorResponse")
        XCTAssertTrue(entityNames.contains("StringFormats"), "Should generate StringFormats")

        let paths = try generator.paths()
        XCTAssertFalse(paths.files.isEmpty, "Features spec should generate paths")
    }

}

// MARK: - Unit Tests for OpenAPI 3.1 Parsing

final class OpenAPI31ParsingTests: XCTestCase {

    // MARK: - Version Detection and Conversion

    /// Tests that an OpenAPI 3.1 spec is parsed as a valid document.
    func testParseOpenAPI31Spec() throws {
        let yaml = """
        openapi: "3.1.0"
        info:
          title: Test API
          version: "1.0.0"
        paths: {}
        """
        let data = yaml.data(using: .utf8)!
        let doc = try YAMLDecoder().decode(OpenAPI.Document.self, from: data)
        XCTAssertEqual(doc.openAPIVersion, .v3_1_0)
    }

    // MARK: - Nullable Type Arrays (3.1)

    /// Tests parsing of nullable string via type array: type: [string, null]
    func testNullableStringTypeArray() throws {
        let yaml = """
        openapi: "3.1.0"
        info:
          title: Test
          version: "1.0.0"
        paths: {}
        components:
          schemas:
            NullableString:
              type:
                - string
                - "null"
        """
        let data = yaml.data(using: .utf8)!
        let doc = try YAMLDecoder().decode(OpenAPI.Document.self, from: data)

        let schema = doc.components.schemas["NullableString"]!
        XCTAssertTrue(schema.nullable, "Schema with type: [string, null] should be nullable")
    }

    /// Tests parsing of nullable integer via type array
    func testNullableIntegerTypeArray() throws {
        let yaml = """
        openapi: "3.1.0"
        info:
          title: Test
          version: "1.0.0"
        paths: {}
        components:
          schemas:
            NullableInt:
              type:
                - integer
                - "null"
              format: int64
        """
        let data = yaml.data(using: .utf8)!
        let doc = try YAMLDecoder().decode(OpenAPI.Document.self, from: data)

        let schema = doc.components.schemas["NullableInt"]!
        XCTAssertTrue(schema.nullable, "Schema with type: [integer, null] should be nullable")
    }

    /// Tests that a non-nullable type array (single type) is not nullable.
    func testNonNullableSchema() throws {
        let yaml = """
        openapi: "3.1.0"
        info:
          title: Test
          version: "1.0.0"
        paths: {}
        components:
          schemas:
            RegularString:
              type: string
        """
        let data = yaml.data(using: .utf8)!
        let doc = try YAMLDecoder().decode(OpenAPI.Document.self, from: data)

        let schema = doc.components.schemas["RegularString"]!
        XCTAssertFalse(schema.nullable, "Single type string should not be nullable")
    }

    // MARK: - Exclusive Min/Max (3.1)

    /// Tests parsing of exclusiveMinimum/exclusiveMaximum as numeric values (3.1 style).
    func testExclusiveMinMaxNumericValues() throws {
        let yaml = """
        openapi: "3.1.0"
        info:
          title: Test
          version: "1.0.0"
        paths: {}
        components:
          schemas:
            BoundedNumber:
              type: number
              exclusiveMinimum: 0
              exclusiveMaximum: 100
        """
        let data = yaml.data(using: .utf8)!
        let doc = try YAMLDecoder().decode(OpenAPI.Document.self, from: data)

        let schema = doc.components.schemas["BoundedNumber"]!
        // The schema should parse without errors
        XCTAssertNotNil(schema)
    }

    // MARK: - String Formats (3.1)

    /// Tests that 3.1 string formats (email, hostname, etc.) are parsed correctly.
    func testStringFormats31() throws {
        let yaml = """
        openapi: "3.1.0"
        info:
          title: Test
          version: "1.0.0"
        paths: {}
        components:
          schemas:
            Formats:
              type: object
              properties:
                email:
                  type: string
                  format: email
                ipv4:
                  type: string
                  format: ipv4
                uri:
                  type: string
                  format: uri
                uuid:
                  type: string
                  format: uuid
                dateTime:
                  type: string
                  format: date-time
                duration:
                  type: string
                  format: duration
        """
        let data = yaml.data(using: .utf8)!
        let doc = try YAMLDecoder().decode(OpenAPI.Document.self, from: data)

        let schema = doc.components.schemas["Formats"]!
        XCTAssertNotNil(schema)
        // Verify schema parses as object with properties
        if case .object(_, let details) = schema.value {
            XCTAssertEqual(details.properties.count, 6)
        } else {
            XCTFail("Expected object schema")
        }
    }

    // MARK: - Examples Array (3.1)

    /// Tests that the `examples` array (replacing singular `example`) parses.
    func testExamplesArray() throws {
        let yaml = """
        openapi: "3.1.0"
        info:
          title: Test
          version: "1.0.0"
        paths: {}
        components:
          schemas:
            WithExamples:
              type: string
              examples:
                - "hello"
                - "world"
        """
        let data = yaml.data(using: .utf8)!
        let doc = try YAMLDecoder().decode(OpenAPI.Document.self, from: data)

        let schema = doc.components.schemas["WithExamples"]!
        XCTAssertEqual(schema.coreContext.examples.count, 2)
    }

    // MARK: - allOf Composition

    /// Tests that allOf with $ref works correctly in 3.1
    func testAllOfComposition() throws {
        let yaml = """
        openapi: "3.1.0"
        info:
          title: Test
          version: "1.0.0"
        paths: {}
        components:
          schemas:
            Base:
              type: object
              properties:
                id:
                  type: string
            Extended:
              allOf:
                - $ref: "#/components/schemas/Base"
                - type: object
                  properties:
                    extra:
                      type: string
        """
        let data = yaml.data(using: .utf8)!
        let doc = try YAMLDecoder().decode(OpenAPI.Document.self, from: data)

        let schema = doc.components.schemas["Extended"]!
        if case .all(let schemas, _) = schema.value {
            XCTAssertEqual(schemas.count, 2)
        } else {
            XCTFail("Expected allOf schema")
        }
    }

    // MARK: - oneOf with Discriminator

    /// Tests that oneOf with discriminator parses correctly in 3.1
    func testOneOfWithDiscriminator() throws {
        let yaml = """
        openapi: "3.1.0"
        info:
          title: Test
          version: "1.0.0"
        paths: {}
        components:
          schemas:
            Cat:
              type: object
              properties:
                type:
                  type: string
                name:
                  type: string
            Dog:
              type: object
              properties:
                type:
                  type: string
                breed:
                  type: string
            Pet:
              oneOf:
                - $ref: "#/components/schemas/Cat"
                - $ref: "#/components/schemas/Dog"
              discriminator:
                propertyName: type
        """
        let data = yaml.data(using: .utf8)!
        let doc = try YAMLDecoder().decode(OpenAPI.Document.self, from: data)

        let schema = doc.components.schemas["Pet"]!
        if case .one(let schemas, let info) = schema.value {
            XCTAssertEqual(schemas.count, 2)
            XCTAssertNotNil(info.discriminator)
            XCTAssertEqual(info.discriminator?.propertyName, "type")
        } else {
            XCTFail("Expected oneOf schema")
        }
    }

    // MARK: - Null Type (3.1)

    /// Tests parsing of the explicit null type schema.
    func testNullTypeSchema() throws {
        let yaml = """
        openapi: "3.1.0"
        info:
          title: Test
          version: "1.0.0"
        paths: {}
        components:
          schemas:
            NullOnly:
              type: "null"
        """
        let data = yaml.data(using: .utf8)!
        let doc = try YAMLDecoder().decode(OpenAPI.Document.self, from: data)

        let schema = doc.components.schemas["NullOnly"]!
        if case .null = schema.value {
            // expected
        } else {
            XCTFail("Expected null type schema, got: \(schema.value)")
        }
    }
}

// MARK: - Code Generation Tests for 3.1 Features

final class OpenAPI31GenerationTests: XCTestCase {

    /// Tests that a simple 3.1 spec generates code successfully.
    func testGenerateFromOpenAPI31Spec() throws {
        let yaml = """
        openapi: "3.1.0"
        info:
          title: TestAPI
          version: "1.0.0"
        paths: {}
        components:
          schemas:
            User:
              type: object
              required:
                - id
                - name
              properties:
                id:
                  type: integer
                  format: int64
                name:
                  type: string
                nickname:
                  type:
                    - string
                    - "null"
        """
        let data = yaml.data(using: .utf8)!
        let doc = try YAMLDecoder().decode(OpenAPI.Document.self, from: data)

        let options = GenerateOptions.default
        let arguments = GenerateArguments(isVerbose: false, isParallel: false, isStrict: false, isIgnoringErrors: false)
        let generator = Generator(spec: doc, options: options, arguments: arguments)

        let output = try generator.schemas()
        XCTAssertFalse(output.files.isEmpty, "Should generate at least one entity file")

        // Check that User entity was generated
        let userFile = output.files.first { $0.name == "User" }
        XCTAssertNotNil(userFile, "Should generate a User entity")
    }

    /// Tests generation of enums from 3.1 specs.
    func testGenerateEnumFrom31Spec() throws {
        let yaml = """
        openapi: "3.1.0"
        info:
          title: TestAPI
          version: "1.0.0"
        paths: {}
        components:
          schemas:
            Status:
              type: string
              enum:
                - active
                - inactive
                - pending
        """
        let data = yaml.data(using: .utf8)!
        let doc = try YAMLDecoder().decode(OpenAPI.Document.self, from: data)

        let options = GenerateOptions.default
        let arguments = GenerateArguments(isVerbose: false, isParallel: false, isStrict: false, isIgnoringErrors: false)
        let generator = Generator(spec: doc, options: options, arguments: arguments)

        let output = try generator.schemas()
        let statusFile = output.files.first { $0.name == "Status" }
        XCTAssertNotNil(statusFile, "Should generate a Status enum")

        if let contents = statusFile?.contents {
            XCTAssertTrue(contents.contains("active"), "Should contain 'active' case")
            XCTAssertTrue(contents.contains("inactive"), "Should contain 'inactive' case")
            XCTAssertTrue(contents.contains("pending"), "Should contain 'pending' case")
        }
    }

    /// Tests generation of allOf composition from 3.1 specs.
    func testGenerateAllOfFrom31Spec() throws {
        let yaml = """
        openapi: "3.1.0"
        info:
          title: TestAPI
          version: "1.0.0"
        paths: {}
        components:
          schemas:
            Base:
              type: object
              required:
                - id
              properties:
                id:
                  type: string
            Extended:
              allOf:
                - $ref: "#/components/schemas/Base"
                - type: object
                  properties:
                    extra:
                      type: string
        """
        let data = yaml.data(using: .utf8)!
        let doc = try YAMLDecoder().decode(OpenAPI.Document.self, from: data)

        let options = GenerateOptions.default
        let arguments = GenerateArguments(isVerbose: false, isParallel: false, isStrict: false, isIgnoringErrors: false)
        let generator = Generator(spec: doc, options: options, arguments: arguments)

        let output = try generator.schemas()
        let extendedFile = output.files.first { $0.name == "Extended" }
        XCTAssertNotNil(extendedFile, "Should generate an Extended entity from allOf")
    }

    /// Tests generation with 3.1 string formats
    func testGenerateStringFormats31() throws {
        let yaml = """
        openapi: "3.1.0"
        info:
          title: TestAPI
          version: "1.0.0"
        paths: {}
        components:
          schemas:
            Contact:
              type: object
              properties:
                email:
                  type: string
                  format: email
                website:
                  type: string
                  format: uri
                id:
                  type: string
                  format: uuid
                createdAt:
                  type: string
                  format: date-time
                birthday:
                  type: string
                  format: date
                ipAddress:
                  type: string
                  format: ipv4
        """
        let data = yaml.data(using: .utf8)!
        let doc = try YAMLDecoder().decode(OpenAPI.Document.self, from: data)

        let options = GenerateOptions.default
        let arguments = GenerateArguments(isVerbose: false, isParallel: false, isStrict: false, isIgnoringErrors: false)
        let generator = Generator(spec: doc, options: options, arguments: arguments)

        let output = try generator.schemas()
        let contactFile = output.files.first { $0.name == "Contact" }
        XCTAssertNotNil(contactFile, "Should generate a Contact entity")

        if let contents = contactFile?.contents {
            // uri format should map to URL
            XCTAssertTrue(contents.contains("URL"), "uri format should generate URL type")
            // uuid format should map to UUID
            XCTAssertTrue(contents.contains("UUID"), "uuid format should generate UUID type")
            // date-time should map to Date
            XCTAssertTrue(contents.contains("Date"), "date-time format should generate Date type")
        }
    }

    /// Tests that nullable properties via type arrays generate optional types.
    func testNullableTypeArrayGeneratesOptional() throws {
        let yaml = """
        openapi: "3.1.0"
        info:
          title: TestAPI
          version: "1.0.0"
        paths: {}
        components:
          schemas:
            Profile:
              type: object
              required:
                - name
                - bio
              properties:
                name:
                  type: string
                bio:
                  type:
                    - string
                    - "null"
        """
        let data = yaml.data(using: .utf8)!
        let doc = try YAMLDecoder().decode(OpenAPI.Document.self, from: data)

        let options = GenerateOptions.default
        let arguments = GenerateArguments(isVerbose: false, isParallel: false, isStrict: false, isIgnoringErrors: false)
        let generator = Generator(spec: doc, options: options, arguments: arguments)

        let output = try generator.schemas()
        let profileFile = output.files.first { $0.name == "Profile" }
        XCTAssertNotNil(profileFile, "Should generate a Profile entity")

        if let contents = profileFile?.contents {
            // bio is required but nullable, so it should be optional (String?)
            XCTAssertTrue(contents.contains("String?"), "Nullable required property should generate optional type")
        }
    }
}

// MARK: - Typed Error Enum Generation Tests

final class TypedErrorGenerationTests: XCTestCase {

    private func makeGenerator(from yaml: String) throws -> Generator {
        let data = yaml.data(using: .utf8)!
        let doc = try YAMLDecoder().decode(OpenAPI.Document.self, from: data)
        let options = GenerateOptions.default
        let arguments = GenerateArguments(isVerbose: false, isParallel: false, isStrict: false, isIgnoringErrors: false)
        return Generator(spec: doc, options: options, arguments: arguments)
    }

    /// Tests that an operation with error responses generates typed throws.
    func testGeneratesTypedThrowsForErrors() throws {
        let generator = try makeGenerator(from: """
        openapi: "3.1.0"
        info:
          title: Test
          version: "1.0.0"
        paths:
          /items:
            get:
              operationId: listItems
              responses:
                '200':
                  description: Success
                  content:
                    application/json:
                      schema:
                        type: array
                        items:
                          type: string
                '404':
                  description: Not found
                '500':
                  description: Server error
                  content:
                    application/json:
                      schema:
                        $ref: "#/components/schemas/ErrorBody"
        components:
          schemas:
            ErrorBody:
              type: object
              required: [message]
              properties:
                message:
                  type: string
        """)

        let output = try generator.paths()
        XCTAssertFalse(output.files.isEmpty)

        let pathFile = output.files.first
        XCTAssertNotNil(pathFile)

        if let contents = pathFile?.contents {
            // Should return Request with error type
            XCTAssertTrue(contents.contains("GetError>"), "Should return Request with GetError type parameter")

            // Should have error enum conforming to RequestError
            XCTAssertTrue(contents.contains("enum GetError: RequestError"), "Should generate GetError enum")

            // Should have notFound case (no body)
            XCTAssertTrue(contents.contains("case notFound"), "Should have notFound case")

            // Should have internalServerError case with body type
            XCTAssertTrue(contents.contains("case internalServerError"), "Should have internalServerError case")
            XCTAssertTrue(contents.contains("ErrorBody"), "internalServerError should reference ErrorBody type")

            // Should have decode method
            XCTAssertTrue(contents.contains("static func decode(statusCode:"), "Should generate decode method")

            // Should have unhandled case
            XCTAssertTrue(contents.contains("case unhandled(any Swift.Error)"), "Should have unhandled case")
        }
    }

    /// Tests that an operation with no error responses generates no throws.
    func testNoThrowsWhenNoErrors() throws {
        let generator = try makeGenerator(from: """
        openapi: "3.1.0"
        info:
          title: Test
          version: "1.0.0"
        paths:
          /items:
            post:
              operationId: createItem
              requestBody:
                required: true
                content:
                  application/json:
                    schema:
                      type: object
                      properties:
                        name:
                          type: string
              responses:
                '201':
                  description: Created
        components:
          schemas: {}
        """)

        let output = try generator.paths()
        let pathFile = output.files.first

        if let contents = pathFile?.contents {
            // Should use DefaultRequestError since no error responses
            XCTAssertTrue(contents.contains("DefaultRequestError"), "Should use DefaultRequestError when no error responses")
            // Should NOT generate an error enum
            XCTAssertFalse(contents.contains("enum") && contents.contains("RequestError"), "Should not generate error enum")
        }
    }

    /// Tests that a default error response generates a case with statusCode.
    func testDefaultErrorResponseHasStatusCode() throws {
        let generator = try makeGenerator(from: """
        openapi: "3.1.0"
        info:
          title: Test
          version: "1.0.0"
        paths:
          /items:
            get:
              operationId: listItems
              responses:
                '200':
                  description: Success
                  content:
                    application/json:
                      schema:
                        type: array
                        items:
                          type: string
                default:
                  description: Error
                  content:
                    application/json:
                      schema:
                        $ref: "#/components/schemas/ErrorBody"
        components:
          schemas:
            ErrorBody:
              type: object
              required: [message]
              properties:
                message:
                  type: string
        """)

        let output = try generator.paths()
        let pathFile = output.files.first

        if let contents = pathFile?.contents {
            // Default case should include statusCode parameter
            XCTAssertTrue(contents.contains("statusCode: Int"), "Default error case should have statusCode parameter")
            XCTAssertTrue(contents.contains("`default`"), "Should generate escaped default case name")
        }
    }

    /// Tests that multiple error codes generate separate enum cases.
    func testMultipleErrorCodesGenerateSeparateCases() throws {
        let generator = try makeGenerator(from: """
        openapi: "3.1.0"
        info:
          title: Test
          version: "1.0.0"
        paths:
          /items:
            post:
              operationId: createItem
              requestBody:
                required: true
                content:
                  application/json:
                    schema:
                      type: object
                      properties:
                        name:
                          type: string
              responses:
                '201':
                  description: Created
                  content:
                    application/json:
                      schema:
                        type: object
                        properties:
                          id:
                            type: string
                '400':
                  description: Bad request
                  content:
                    application/json:
                      schema:
                        $ref: "#/components/schemas/ValidationError"
                '401':
                  description: Unauthorized
                '409':
                  description: Conflict
                  content:
                    application/json:
                      schema:
                        $ref: "#/components/schemas/ConflictError"
                '500':
                  description: Server error
        components:
          schemas:
            ValidationError:
              type: object
              required: [message]
              properties:
                message:
                  type: string
            ConflictError:
              type: object
              required: [reason]
              properties:
                reason:
                  type: string
        """)

        let output = try generator.paths()
        let pathFile = output.files.first

        if let contents = pathFile?.contents {
            XCTAssertTrue(contents.contains("PostError>"), "Should return Request with PostError type parameter")
            XCTAssertTrue(contents.contains("case badRequest"), "Should have badRequest case")
            XCTAssertTrue(contents.contains("case unauthorized"), "Should have unauthorized case (no body)")
            XCTAssertTrue(contents.contains("case conflict"), "Should have conflict case")
            XCTAssertTrue(contents.contains("case internalServerError"), "Should have internalServerError case")
            XCTAssertTrue(contents.contains("ValidationError"), "badRequest should reference ValidationError")
            XCTAssertTrue(contents.contains("ConflictError"), "conflict should reference ConflictError")
        }
    }

    /// Tests that error cases without response bodies generate cases without associated values.
    func testErrorCaseWithNoBody() throws {
        let generator = try makeGenerator(from: """
        openapi: "3.1.0"
        info:
          title: Test
          version: "1.0.0"
        paths:
          /items/{id}:
            delete:
              operationId: deleteItem
              parameters:
                - name: id
                  in: path
                  required: true
                  schema:
                    type: string
              responses:
                '204':
                  description: Deleted
                '404':
                  description: Not found
        components:
          schemas: {}
        """)

        let output = try generator.paths()
        // The delete operation is on /items/{id}, which generates as the second file
        let pathFile = output.files.first { $0.contents.contains("delete") }
        XCTAssertNotNil(pathFile, "Should find a file with delete operation")

        if let contents = pathFile?.contents {
            XCTAssertTrue(contents.contains("DeleteError>"), "Should return Request with DeleteError type parameter")
            // notFound has no body, so should be a plain case
            XCTAssertTrue(contents.contains("case notFound"), "Should have notFound case")
            // Make sure it doesn't have parentheses (no associated value)
            XCTAssertFalse(contents.contains("case notFound("), "notFound with no body should not have associated value")
        }
    }

    /// Tests that an operation with request body AND error responses generates both correctly.
    func testRequestBodyWithTypedErrors() throws {
        let generator = try makeGenerator(from: """
        openapi: "3.1.0"
        info:
          title: Test
          version: "1.0.0"
        paths:
          /items:
            post:
              operationId: createItem
              requestBody:
                required: true
                content:
                  application/json:
                    schema:
                      type: object
                      properties:
                        name:
                          type: string
              responses:
                '201':
                  description: Created
                  content:
                    application/json:
                      schema:
                        type: object
                        properties:
                          id:
                            type: string
                '400':
                  description: Bad request
        components:
          schemas: {}
        """)

        let output = try generator.paths()
        let pathFile = output.files.first

        if let contents = pathFile?.contents {
            // Should have both body param and typed throws
            XCTAssertTrue(contents.contains("body"), "Should accept request body")
            XCTAssertTrue(contents.contains("PostError>"), "Should return Request with PostError type parameter")
            XCTAssertTrue(contents.contains("case badRequest"), "Should have badRequest case")
        }
    }

    /// Tests that an error response via $ref to components/responses works.
    func testErrorResponseViaRef() throws {
        let generator = try makeGenerator(from: """
        openapi: "3.1.0"
        info:
          title: Test
          version: "1.0.0"
        paths:
          /items:
            get:
              operationId: listItems
              responses:
                '200':
                  description: Success
                  content:
                    application/json:
                      schema:
                        type: array
                        items:
                          type: string
                '401':
                  $ref: "#/components/responses/Unauthorized"
        components:
          responses:
            Unauthorized:
              description: Authentication required
              content:
                application/json:
                  schema:
                    $ref: "#/components/schemas/AuthError"
          schemas:
            AuthError:
              type: object
              required:
                - message
              properties:
                message:
                  type: string
        """)

        let output = try generator.paths()
        let pathFile = output.files.first

        if let contents = pathFile?.contents {
            XCTAssertTrue(contents.contains("GetError>"), "Should return Request with GetError type parameter for $ref response")
            XCTAssertTrue(contents.contains("case unauthorized"), "Should resolve $ref response to unauthorized case")
            XCTAssertTrue(contents.contains("AuthError"), "Should reference the AuthError schema type")
        }
    }

    /// Tests that only success responses (no errors) produces no error enum.
    func testMultipleSuccessCodesNoErrors() throws {
        let generator = try makeGenerator(from: """
        openapi: "3.1.0"
        info:
          title: Test
          version: "1.0.0"
        paths:
          /items:
            post:
              operationId: createItem
              requestBody:
                required: true
                content:
                  application/json:
                    schema:
                      type: object
                      properties:
                        name:
                          type: string
              responses:
                '200':
                  description: Updated existing
                  content:
                    application/json:
                      schema:
                        type: object
                        properties:
                          id:
                            type: string
                '201':
                  description: Created new
                  content:
                    application/json:
                      schema:
                        type: object
                        properties:
                          id:
                            type: string
        components:
          schemas: {}
        """)

        let output = try generator.paths()
        let pathFile = output.files.first

        if let contents = pathFile?.contents {
            XCTAssertTrue(contents.contains("DefaultRequestError"), "Should use DefaultRequestError for success-only responses")
            XCTAssertFalse(contents.contains("enum") && contents.contains("RequestError"), "Should not generate error enum")
        }
    }
}
