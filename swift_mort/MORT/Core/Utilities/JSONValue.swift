import Foundation

enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value: Bool = try Self.decodeCandidate(from: container) { self = .bool(value) }
        else if let value: Double = try Self.decodeCandidate(from: container) { self = .number(value) }
        else if let value: String = try Self.decodeCandidate(from: container) { self = .string(value) }
        else if let value: [String: JSONValue] = try Self.decodeCandidate(from: container) { self = .object(value) }
        else if let value: [JSONValue] = try Self.decodeCandidate(from: container) { self = .array(value) }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value") }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    var intValue: Int? {
        guard case let .number(value) = self else { return nil }
        return Int(value)
    }

    var boolValue: Bool? {
        guard case let .bool(value) = self else { return nil }
        return value
    }

    var displayValue: String {
        switch self {
        case let .string(value): value
        case let .number(value): value.rounded() == value ? String(Int(value)) : String(value)
        case let .bool(value): value ? "Yes" : "No"
        case let .object(value): value.map { "\($0.key): \($0.value.displayValue)" }.sorted().joined(separator: ", ")
        case let .array(value): value.map(\.displayValue).joined(separator: ", ")
        case .null: "-"
        }
    }

    private static func decodeCandidate<Value: Decodable>(
        from container: SingleValueDecodingContainer
    ) throws -> Value? {
        do { return try container.decode(Value.self) }
        catch DecodingError.typeMismatch { return nil }
        catch DecodingError.valueNotFound { return nil }
    }
}
