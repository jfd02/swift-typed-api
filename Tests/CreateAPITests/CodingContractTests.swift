import Foundation
import XCTest
import CreateOptions
import OpenAPIKit
import Yams
@testable import create_api

final class CodingContractTests: XCTestCase {
    func testRequiredNullableFieldsRoundTripAndRejectMissingKeys() throws {
        for composition in [false, true] {
            for optimizeCodingKeys in [true, false] {
                let options = try GenerateOptions(data: nil) {
                    $0.entities.protocols = ["Codable"]
                    $0.entities.optimizeCodingKeys = optimizeCodingKeys
                    $0.entities.alwaysIncludeDecodableImplementation = false
                    $0.entities.alwaysIncludeEncodableImplementation = false
                }
                let nullable = !composition
                    ? "type: [string, 'null']"
                    : "anyOf:\n  - type: string\n  - type: 'null'"
                let output = try generate("""
                openapi: '3.1.0'
                info: {title: Test, version: '1'}
                paths: {}
                components:
                  schemas:
                    Profile:
                      type: object
                      required: [required_value]
                      properties:
                        required_value:
                \(nullable.split(separator: "\n").map { "          " + $0 }.joined(separator: "\n"))
                        optional_value:
                \(nullable.split(separator: "\n").map { "          " + $0 }.joined(separator: "\n"))
                """, options: options)
                try run(output, assertions: #"""
                let decoder = JSONDecoder()
                let profile = try decoder.decode(Profile.self, from: Data(#"{"required_value":null}"#.utf8))
                precondition(profile.requiredValue == nil)
                precondition(profile.optionalValue == nil)
                let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as! [String: Any]
                precondition(object["required_value"] is NSNull)
                precondition(object["optional_value"] == nil)
                let populated = try decoder.decode(Profile.self, from: Data(#"{"required_value":"hello"}"#.utf8))
                precondition(populated.requiredValue == "hello")
                do {
                    _ = try decoder.decode(Profile.self, from: Data("{}".utf8))
                    fatalError("Missing required nullable field was accepted")
                } catch DecodingError.keyNotFound(let key, _) {
                    precondition(key.stringValue == "required_value")
                }
                do {
                    _ = try decoder.decode(Profile.self, from: Data(#"{"required_value":123}"#.utf8))
                    fatalError("Invalid nullable field type was accepted")
                } catch DecodingError.typeMismatch { }
                """#)
            }
        }
    }

    func testAnyOfRejectsUnmatchedValuesAndAcceptsMultipleMatchesAndNullWhenDeclared() throws {
        let options = try GenerateOptions(data: nil) {
            $0.entities.protocols = ["Codable"]
        }
        let output = try generate("""
        openapi: '3.1.0'
        info: {title: Test, version: '1'}
        paths: {}
        components:
          schemas:
            First:
              type: object
              required: [first]
              properties:
                first: {type: string}
            Second:
              type: object
              required: [second]
              properties:
                second: {type: integer}
            Result:
              anyOf:
                - $ref: '#/components/schemas/First'
                - $ref: '#/components/schemas/Second'
            NullableResult:
              anyOf:
                - $ref: '#/components/schemas/First'
                - $ref: '#/components/schemas/Second'
                - type: 'null'
            DefaultResult:
              anyOf:
                - type: boolean
                  default: false
                - type: integer
        """, options: options)
        try run(output, assertions: #"""
        let decoder = JSONDecoder()
        let first = try decoder.decode(Result.self, from: Data(#"{"first":"value"}"#.utf8))
        precondition(first.first?.first == "value" && first.second == nil)
        let second = try decoder.decode(Result.self, from: Data(#"{"second":42}"#.utf8))
        precondition(second.first == nil && second.second?.second == 42)
        let both = try decoder.decode(Result.self, from: Data(#"{"first":"value","second":42}"#.utf8))
        precondition(both.first != nil && both.second != nil)
        let encodedBoth = try JSONSerialization.jsonObject(with: JSONEncoder().encode(both)) as! [String: Any]
        precondition(encodedBoth["first"] as? String == "value")
        precondition(encodedBoth["second"] as? Int == 42)
        do {
            _ = try JSONEncoder().encode(Result())
            fatalError("Empty non-nullable anyOf was encoded")
        } catch EncodingError.invalidValue { }

        for invalid in ["{}", "null", "[]", #"{"first":5}"#] {
            do {
                _ = try decoder.decode(Result.self, from: Data(invalid.utf8))
                fatalError("Invalid anyOf response accepted: \(invalid)")
            } catch DecodingError.dataCorrupted { }
        }
        let nullable = try decoder.decode(NullableResult.self, from: Data("null".utf8))
        precondition(nullable.first == nil && nullable.second == nil)
        let encodedNull = try JSONEncoder().encode(nullable)
        precondition(String(data: encodedNull, encoding: .utf8) == "null")
        do {
            _ = try decoder.decode(NullableResult.self, from: Data("{}".utf8))
            fatalError("Explicit null variant accepted a non-null invalid value")
        } catch DecodingError.dataCorrupted { }
        do {
            _ = try decoder.decode(DefaultResult.self, from: Data("{}".utf8))
            fatalError("A default value was mistaken for a matching variant")
        } catch DecodingError.dataCorrupted { }
        _ = try decoder.decode(DefaultResult.self, from: Data("false".utf8))
        """#)
    }

    func testNullableCollectionElementsRoundTrip() throws {
        for composition in [false, true] {
            let options = try GenerateOptions(data: nil) { $0.entities.protocols = ["Codable"] }
            let nullable = composition ? "{anyOf: [{type: string}, {type: 'null'}]}" : "{type: [string, 'null']}"
            let output = try generate("""
            openapi: '3.1.0'
            info: {title: Test, version: '1'}
            paths: {}
            components:
              schemas:
                NullableString: \(nullable)
                Collection:
                  type: object
                  required: [values, lookup, objects, nested]
                  properties:
                    values:
                      type: array
                      items: {$ref: '#/components/schemas/NullableString'}
                    lookup:
                      type: object
                      additionalProperties: \(nullable)
                    objects:
                      type: array
                      items:
                        anyOf:
                          - type: object
                            required: [name]
                            properties:
                              name: {type: string}
                          - type: 'null'
                    nested:
                      type: array
                      items:
                        type: [array, 'null']
                        items: \(nullable)
            """, options: options)
            try run(output, assertions: #"""
            let input = Data(#"{"values":["a",null],"lookup":{"a":null,"b":"value"},"objects":[{"name":"hi"},null],"nested":[["a",null],null]}"#.utf8)
            let value = try JSONDecoder().decode(Collection.self, from: input)
            precondition(value.values == ["a", nil])
            precondition(value.lookup.keys.contains("a") && value.lookup["a"]! == nil)
            precondition(value.objects[0]?.name == "hi" && value.objects[1] == nil)
            precondition(value.nested[0]! == ["a", nil] && value.nested[1] == nil)
            let encoded = try JSONEncoder().encode(value)
            let actual = try JSONSerialization.jsonObject(with: encoded) as! NSDictionary
            let expected = try JSONSerialization.jsonObject(with: input) as! NSDictionary
            precondition(actual == expected)
            """#)
        }
    }

    func testOptionalNonNullableFieldsRejectNullEvenWithDefaultValues() throws {
        for optimizeCodingKeys in [true, false] {
            let options = try GenerateOptions(data: nil) {
                $0.entities.protocols = ["Codable"]
                $0.entities.optimizeCodingKeys = optimizeCodingKeys
                $0.entities.alwaysIncludeDecodableImplementation = false
                $0.entities.alwaysIncludeEncodableImplementation = false
            }
            let output = try generate("""
            openapi: '3.1.0'
            info: {title: Test, version: '1'}
            paths: {}
            components:
              schemas:
                Profile:
                  type: object
                  properties:
                    display_name: {type: string}
                    active: {type: boolean, default: false}
            """, options: options)
            try run(output, assertions: #"""
            let decoder = JSONDecoder()
            let missing = try decoder.decode(Profile.self, from: Data("{}".utf8))
            precondition(missing.displayName == nil)
            let present = try decoder.decode(Profile.self, from: Data(#"{"display_name":"hello","active":true}"#.utf8))
            precondition(present.displayName == "hello")
            for input in [#"{"display_name":null}"#, #"{"active":null}"#] {
                do {
                    _ = try decoder.decode(Profile.self, from: Data(input.utf8))
                    fatalError("Null accepted for non-nullable field: \(input)")
                } catch DecodingError.valueNotFound {
                } catch DecodingError.typeMismatch { }
            }
            """#)
        }
    }

    func testAnyOfEncodingMergesNestedValuesAndPreservesEncoderStrategies() throws {
        let output = GeneratorOutput(header: "", files: [], extensions: [
            GeneratedFile(name: "AnyOfEncoder", contents: anyOfEncoder),
            GeneratedFile(name: "StringCodingKey", contents: stringCodingKey)
        ])
        try run(output, assertions: #"""
        struct Overlap<A: Encodable, B: Encodable>: Encodable {
            let first: A
            let second: B
            func encode(to encoder: Encoder) throws {
                let container = AnyOfEncoder(encoder: encoder)
                try container.encode(first)
                try container.encode(second)
                try container.finish(allowsNull: false)
            }
        }
        struct Left: Encodable {
            var nested: [String: Int]
            var createdAt: Date
            var bytes: Data
        }
        struct Right: Encodable {
            var nested: [String: Int]
            var createdAt: Date
            var bytes: Data
        }
        let date = Date(timeIntervalSince1970: 123)
        let bytes = Data([1, 2, 3])
        let value = Overlap(first: Left(nested: ["leftKey": 1], createdAt: date, bytes: bytes),
                            second: Right(nested: ["rightKey": 2], createdAt: date, bytes: bytes))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.dataEncodingStrategy = .custom { _, encoder in
            var container = encoder.singleValueContainer()
            try container.encode("custom-data")
        }
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let object = try JSONSerialization.jsonObject(with: encoder.encode(value)) as! [String: Any]
        precondition(object["created_at"] as? Double == 123)
        precondition(object["bytes"] as? String == "custom-data")
        precondition(object["nested"] as? [String: Int] == ["leftKey": 1, "rightKey": 2])
        let array = Overlap(first: [["left": 1]], second: [["right": 2]])
        let encodedArray = try JSONSerialization.jsonObject(with: encoder.encode(array)) as! [[String: Int]]
        precondition(encodedArray == [["left": 1, "right": 2]])
        let number = try encoder.encode(Overlap(first: 42, second: 42.0))
        precondition(String(data: number, encoding: .utf8) == "42")
        struct Named: Encodable { var name: String }
        let mixed = Overlap(first: Named(name: "hello"), second: ["name": "hello", "extra": "world"])
        let mixedObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(mixed)) as! [String: String]
        precondition(mixedObject == ["name": "hello", "extra": "world"])
        do {
            _ = try encoder.encode(Overlap(first: ["x": 1], second: ["x": 2]))
            fatalError("Conflicting union fields were silently overwritten")
        } catch EncodingError.invalidValue(_, let context) {
            precondition(context.codingPath.last?.stringValue == "x")
        }
        do {
            _ = try encoder.encode(Overlap(first: true, second: 1))
            fatalError("Boolean and integer were treated as equal")
        } catch EncodingError.invalidValue { }
        do {
            _ = try encoder.encode(Overlap(first: [1], second: [1, 2]))
            fatalError("Incompatible arrays were merged")
        } catch EncodingError.invalidValue { }
        """#)
    }

    func testPatchNullableFieldsPreserveMissingAndExplicitNull() throws {
        for optimizeCodingKeys in [true, false] {
            let options = try GenerateOptions(data: nil) {
                $0.entities.protocols = ["Codable"]
                $0.entities.optimizeCodingKeys = optimizeCodingKeys
                $0.paths.makeOptionalPatchParametersDoubleOptional = true
                $0.entities.alwaysIncludeDecodableImplementation = false
                $0.entities.alwaysIncludeEncodableImplementation = false
            }
            let document = try YAMLDecoder().decode(OpenAPI.Document.self, from: Data("""
            openapi: '3.1.0'
            info: {title: Test, version: '1'}
            paths: {}
            components:
              schemas:
                Patch:
                  type: object
                  required: [required_value]
                  properties:
                    required_value: {type: [string, 'null']}
                    display_name: {type: [string, 'null']}
                    label: {type: string}
            """.utf8))
            let generator = Generator(spec: document, options: options,
                arguments: GenerateArguments(isVerbose: false, isParallel: false, isStrict: true, isIgnoringErrors: false))
            let declaration = try generator._makeDeclaration(name: TypeName("Patch"), schema: document.components.schemas["Patch"]!, context: Context(isPatch: true))
            let output = GeneratorOutput(header: "", files: [GeneratedFile(name: "Patch", contents: try generator.render(declaration))],
                extensions: [GeneratedFile(name: "StringCodingKey", contents: stringCodingKey)])
            try run(output, assertions: #"""
            let decoder = JSONDecoder()
            let missing = try decoder.decode(Patch.self, from: Data(#"{"required_value":null}"#.utf8))
            if case .some = missing.displayName { fatalError("Absent PATCH field became present") }
            let null = try decoder.decode(Patch.self, from: Data(#"{"required_value":null,"display_name":null}"#.utf8))
            guard case .some(.none) = null.displayName else { fatalError("Explicit null PATCH field became absent") }
            let missingObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(missing)) as! [String: Any]
            let nullObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(null)) as! [String: Any]
            precondition(missingObject["display_name"] == nil)
            precondition(nullObject["display_name"] is NSNull)
            precondition(nullObject["required_value"] is NSNull)
            let populated = try decoder.decode(Patch.self, from: Data(#"{"required_value":"a","display_name":"b","label":"c"}"#.utf8))
            precondition(populated.requiredValue == "a" && populated.displayName! == "b" && populated.label == "c")
            """#)
        }
    }

    func testOpenEnumFallbackDoesNotCollideWithDocumentedCases() throws {
        let options = try GenerateOptions(data: nil) {
            $0.entities.protocols = ["Codable"]
            $0.entities.openEnums = true
        }
        let output = try generate("""
        openapi: '3.1.0'
        info: {title: Test, version: '1'}
        paths: {}
        components:
          schemas:
            Status:
              type: string
              enum: [ready, unknown, unknown_value, unknown_value2]
        """, options: options)
        try run(output, assertions: #"""
        let decoder = JSONDecoder()
        let known = try decoder.decode(Status.self, from: Data(#""unknown""#.utf8))
        precondition(known == .unknown)
        let future = try decoder.decode(Status.self, from: Data(#""future""#.utf8))
        guard case .unknownValue3("future") = future else { fatalError("Unknown value lost") }
        precondition(future.rawValue == "future")
        let encoded = try JSONEncoder().encode(future)
        precondition(String(data: encoded, encoding: .utf8) == #""future""#)
        precondition(Status.allCases.map(\.rawValue) == ["ready", "unknown", "unknown_value", "unknown_value2"])
        """#)
    }

    private func generate(_ yaml: String, options: GenerateOptions) throws -> GeneratorOutput {
        let document = try YAMLDecoder().decode(OpenAPI.Document.self, from: Data(yaml.utf8))
        return try Generator(
            spec: document,
            options: options,
            arguments: GenerateArguments(isVerbose: false, isParallel: false, isStrict: true, isIgnoringErrors: false)
        ).schemas()
    }

    private func run(_ output: GeneratorOutput, assertions: String) throws {
        let temporary = TemporaryDirectory()
        defer { temporary.remove() }
        let source = (["import Foundation"] + (output.files + output.extensions).map(\.contents) + [assertions]).joined(separator: "\n")
        let path = temporary.url.appendingPathComponent("main.swift")
        try source.write(to: path, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", path.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let diagnostics = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, String(decoding: diagnostics, as: UTF8.self))
    }
}
