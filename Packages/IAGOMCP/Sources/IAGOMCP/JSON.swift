import Foundation

/// A JSON value: the messages of the MCP protocol (JSON-RPC 2.0) and the arguments of the tools.
public enum JSON: Sendable, Hashable, Codable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSON])
    case object([String: JSON])

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSON].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSON].self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value):
            if value.rounded() == value, abs(value) < 1e15 {
                try container.encode(Int64(value))
            } else {
                try container.encode(value)
            }
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    public subscript(key: String) -> JSON? {
        if case .object(let object) = self { return object[key] }
        return nil
    }

    public var string: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var int: Int? {
        switch self {
        case .number(let value): Int(value)
        case .string(let value): Int(value)
        default: nil
        }
    }

    public var array: [JSON]? {
        if case .array(let value) = self { return value }
        return nil
    }

    /// A list of strings, also accepting a single string or a comma-separated one.
    public var strings: [String]? {
        switch self {
        case .array(let values): values.compactMap(\.string)
        case .string(let value):
            value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        default: nil
        }
    }
}

extension JSON: ExpressibleByStringLiteral, ExpressibleByDictionaryLiteral, ExpressibleByArrayLiteral,
    ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral
{
    public init(stringLiteral value: String) { self = .string(value) }
    public init(dictionaryLiteral elements: (String, JSON)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { $1 }))
    }
    public init(arrayLiteral elements: JSON...) { self = .array(elements) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
}
