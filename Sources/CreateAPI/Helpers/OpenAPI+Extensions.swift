import Foundation
import OpenAPIKit

extension Either where A == OpenAPI.Reference<JSONSchema>, B == JSONSchema {
    func unwrapped(in spec: OpenAPI.Document) throws -> JSONSchema {
        switch self {
        case .a(let reference):
            return try reference.jsonReference.dereferenced(in: spec.components).jsonSchema
        case .b(let schema):
            return schema
        }
    }
}

extension Either where A == OpenAPI.Reference<OpenAPI.Parameter>, B == OpenAPI.Parameter {
    func unwrapped(in spec: OpenAPI.Document) throws -> OpenAPI.Parameter {
        switch self {
        case .a(let reference):
            return try reference.jsonReference.dereferenced(in: spec.components).underlyingParameter
        case .b(let value):
            return value
        }
    }
}

extension Either where A == OpenAPI.Reference<OpenAPI.Request>, B == OpenAPI.Request {
    func unwrapped(in spec: OpenAPI.Document) throws -> OpenAPI.Request {
        switch self {
        case .a(let reference):
            guard let name = reference.jsonReference.name else {
                throw GeneratorError("Inalid reference")
            }
            guard let key = OpenAPI.ComponentKey(rawValue: name), let request = spec.components.requestBodies[key] else {
                throw GeneratorError("Failed to find a requesty body named \(name)")
            }
            return request
        case .b(let request):
            return request
        }
    }
}

extension Either where A == OpenAPI.Reference<OpenAPI.Header>, B == OpenAPI.Header {
    func unwrapped(in spec: OpenAPI.Document) throws -> OpenAPI.Header {
        switch self {
        case .a(let reference):
            return try reference.jsonReference.dereferenced(in: spec.components).underlyingHeader
        case .b(let value):
            return value
        }
    }
}

extension OpenAPI.Parameter {
    func unwrapped(in spec: OpenAPI.Document) throws -> OpenAPI.Parameter.SchemaContext {
        switch schemaOrContent {
        case .a(let schemaContext):
            return schemaContext
        case .b:
            throw GeneratorError("Parameter content map not supported for parameter: \(name)")
        }
    }
}

extension OpenAPI.Operation {
    var firstSuccessfulResponse: Either<OpenAPI.Reference<OpenAPI.Response>, OpenAPI.Response>? {
        guard responses.count > 1 else {
            return responses.first { $0.key == .default || $0.key.isSuccess }?.value
        }
        return responses.first { $0.key.isSuccess }?.value
    }
}

extension OpenAPI.PathItem {
    var allOperations: [(String, OpenAPI.Operation)] {
        [
            self.get.map { ("get", $0) },
            self.post.map { ("post", $0) },
            self.put.map { ("put", $0) },
            self.patch.map { ("patch", $0) },
            self.delete.map { ("delete", $0) },
            self.options.map { ("options", $0) },
            self.head.map { ("head", $0) },
            self.trace.map { ("trace", $0) }
        ].compactMap { $0 }
    }
}

extension JSONSchema {
    var isOptional: Bool {
        !self.required || self.nullable
    }
}

// Helper to resolve Either<OpenAPI.Reference<PathItem>, PathItem> to PathItem
extension Either where A == OpenAPI.Reference<OpenAPI.PathItem>, B == OpenAPI.PathItem {
    func resolvedPathItem(in spec: OpenAPI.Document) throws -> OpenAPI.PathItem {
        switch self {
        case .a(let reference):
            return try reference.jsonReference.dereferenced(in: spec.components).underlyingPathItem
        case .b(let pathItem):
            return pathItem
        }
    }
}
