import Foundation

// Buffer the variants before writing to the caller's encoder. Keeping native
// scalar values preserves that encoder's date, data, float and key strategies.
let anyOfEncoder = #"""
private protocol AnyOfStringDictionary {
    var anyOfEntries: [String: any Encodable] { get }
}

extension Dictionary: AnyOfStringDictionary where Key == String, Value: Encodable {
    fileprivate var anyOfEntries: [String: any Encodable] { mapValues { $0 } }
}

final class AnyOfEncoder {
    private let encoder: Encoder
    private var value: Value?

    init(encoder: Encoder) {
        self.encoder = encoder
    }

    func encode<T: Encodable>(_ value: T) throws {
        let next = try Value.capture(value, codingPath: encoder.codingPath, userInfo: encoder.userInfo)
        if let current = self.value {
            try current.merge(next, codingPath: encoder.codingPath)
        } else {
            self.value = next
        }
    }

    func finish(allowsNull: Bool) throws {
        guard let value else {
            guard allowsNull else {
                throw EncodingError.invalidValue("anyOf", .init(codingPath: encoder.codingPath, debugDescription: "Expected at least one anyOf value to be set."))
            }
            var container = encoder.singleValueContainer()
            try container.encodeNil()
            return
        }
        try value.encode(to: encoder)
    }

    private final class Value: Encodable {
        enum Storage {
            case empty
            case null
            case scalar(any Encodable, AnyHashable)
            case object([String: Value])
            case array([Value])
        }

        var storage: Storage = .empty
        var error: Error?
        var isDictionary = false

        static func capture<T: Encodable>(_ value: T, codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any]) throws -> Value {
            let node = Value()
            if let dictionary = value as? AnyOfStringDictionary {
                var entries: [String: Value] = [:]
                for (key, value) in dictionary.anyOfEntries {
                    entries[key] = try capture(value, codingPath: codingPath + [StringCodingKey(string: key)], userInfo: userInfo)
                }
                node.storage = .object(entries)
                node.isDictionary = true
            } else if let comparable = value as? AnyHashable,
               value is String || value is Bool || value is Int || value is Int8 || value is Int16 || value is Int32 || value is Int64 ||
               value is UInt || value is UInt8 || value is UInt16 || value is UInt32 || value is UInt64 || value is Float || value is Double ||
               value is Date || value is Data || value is URL || value is Decimal {
                node.storage = .scalar(value, comparable)
            } else {
                try value.encode(to: Recorder(value: node, codingPath: codingPath, userInfo: userInfo))
            }
            if let error = node.error { throw error }
            return node
        }

        func merge(_ other: Value, codingPath: [CodingKey]) throws {
            if let error { throw error }
            if let error = other.error { throw error }
            switch (storage, other.storage) {
            case (.empty, .empty), (.null, .null):
                return
            case (.scalar(_, let lhs), .scalar(_, let rhs)) where lhs == rhs:
                return
            case (.object(var lhs), .object(let rhs)):
                for key in rhs.keys.sorted() {
                    if let existing = lhs[key] {
                        try existing.merge(rhs[key]!, codingPath: codingPath + [StringCodingKey(string: key)])
                    } else {
                        lhs[key] = rhs[key]
                    }
                }
                storage = .object(lhs)
                // A mixture of model properties and dictionary entries uses
                // the enclosing model's keyed-container encoding rules.
                isDictionary = isDictionary && other.isDictionary
            case (.array(let lhs), .array(let rhs)) where lhs.count == rhs.count:
                for index in lhs.indices {
                    try lhs[index].merge(rhs[index], codingPath: codingPath + [StringCodingKey(intValue: index)!])
                }
            default:
                throw EncodingError.invalidValue("anyOf", .init(codingPath: codingPath, debugDescription: "Conflicting values in overlapping anyOf variants."))
            }
        }

        func encode(to encoder: Encoder) throws {
            if let error { throw error }
            switch storage {
            case .empty:
                _ = encoder.container(keyedBy: StringCodingKey.self)
            case .null:
                var container = encoder.singleValueContainer()
                try container.encodeNil()
            case .scalar(let value, _):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .object(let values) where isDictionary:
                // JSONEncoder deliberately leaves dictionary keys unchanged by
                // keyEncodingStrategy. Keep that behavior when replaying them.
                var container = encoder.singleValueContainer()
                try container.encode(values)
            case .object(let values):
                var container = encoder.container(keyedBy: StringCodingKey.self)
                for key in values.keys.sorted() {
                    try container.encode(values[key]!, forKey: StringCodingKey(string: key))
                }
            case .array(let values):
                var container = encoder.unkeyedContainer()
                for value in values { try container.encode(value) }
            }
        }
    }

    private final class Recorder: Encoder {
        let value: Value
        let codingPath: [CodingKey]
        let userInfo: [CodingUserInfoKey: Any]

        init(value: Value, codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any]) {
            self.value = value
            self.codingPath = codingPath
            self.userInfo = userInfo
        }

        func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
            if case .empty = value.storage { value.storage = .object([:]) }
            if case .object = value.storage {} else { recordContainerConflict() }
            return KeyedEncodingContainer(Keyed<Key>(recorder: self))
        }

        func unkeyedContainer() -> UnkeyedEncodingContainer {
            if case .empty = value.storage { value.storage = .array([]) }
            if case .array = value.storage {} else { recordContainerConflict() }
            return Unkeyed(recorder: self)
        }

        func singleValueContainer() -> SingleValueEncodingContainer { Single(recorder: self) }

        func recordContainerConflict() {
            value.error = EncodingError.invalidValue("anyOf", .init(codingPath: codingPath, debugDescription: "Incompatible encoding containers in an anyOf variant."))
        }

        func child(for key: CodingKey) -> Recorder {
            guard case .object(var values) = value.storage else {
                recordContainerConflict()
                return Recorder(value: Value(), codingPath: codingPath + [key], userInfo: userInfo)
            }
            let child = values[key.stringValue] ?? Value()
            values[key.stringValue] = child
            value.storage = .object(values)
            return Recorder(value: child, codingPath: codingPath + [key], userInfo: userInfo)
        }

        func append() -> Recorder {
            guard case .array(var values) = value.storage else {
                recordContainerConflict()
                return Recorder(value: Value(), codingPath: codingPath, userInfo: userInfo)
            }
            let child = Value()
            let key = StringCodingKey(intValue: values.count)!
            values.append(child)
            value.storage = .array(values)
            return Recorder(value: child, codingPath: codingPath + [key], userInfo: userInfo)
        }

        func write<T: Encodable>(_ value: T) throws {
            let captured = try Value.capture(value, codingPath: codingPath, userInfo: userInfo)
            self.value.storage = captured.storage
            self.value.isDictionary = captured.isDictionary
            self.value.error = captured.error
        }
    }

    private struct Keyed<Key: CodingKey>: KeyedEncodingContainerProtocol {
        let recorder: Recorder
        var codingPath: [CodingKey] { recorder.codingPath }

        mutating func encodeNil(forKey key: Key) throws { recorder.child(for: key).value.storage = .null }
        mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws { try recorder.child(for: key).write(value) }
        mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
            recorder.child(for: key).container(keyedBy: keyType)
        }
        mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer { recorder.child(for: key).unkeyedContainer() }
        mutating func superEncoder() -> Encoder { recorder.child(for: StringCodingKey(string: "super")) }
        mutating func superEncoder(forKey key: Key) -> Encoder { recorder.child(for: key) }
    }

    private struct Unkeyed: UnkeyedEncodingContainer {
        let recorder: Recorder
        var codingPath: [CodingKey] { recorder.codingPath }
        var count: Int {
            if case .array(let values) = recorder.value.storage { return values.count }
            return 0
        }

        mutating func encodeNil() throws { recorder.append().value.storage = .null }
        mutating func encode<T: Encodable>(_ value: T) throws { try recorder.append().write(value) }
        mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> { recorder.append().container(keyedBy: keyType) }
        mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer { recorder.append().unkeyedContainer() }
        mutating func superEncoder() -> Encoder { recorder.append() }
    }

    private struct Single: SingleValueEncodingContainer {
        let recorder: Recorder
        var codingPath: [CodingKey] { recorder.codingPath }

        mutating func encodeNil() throws { recorder.value.storage = .null }
        mutating func encode<T: Encodable>(_ value: T) throws { try recorder.write(value) }
    }
}
"""#
