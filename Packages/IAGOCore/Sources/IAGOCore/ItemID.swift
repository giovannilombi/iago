import Foundation

/// Identifier of an `Item`. Backed by a UUIDv7, so IDs sort by creation time (ADR-0008).
public struct ItemID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init?(rawValue: String) {
        guard UUID(uuidString: rawValue) != nil else { return nil }
        self.rawValue = rawValue.lowercased()
    }

    public static func generate(at date: Date = Date()) -> ItemID {
        ItemID(uuid: UUIDv7.make(at: date))
    }

    init(uuid: UUID) {
        self.rawValue = uuid.uuidString.lowercased()
    }

    public var description: String { rawValue }

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        guard let id = ItemID(rawValue: value) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid ItemID"))
        }
        self = id
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// RFC 9562 UUID version 7: 48-bit Unix milliseconds, version, variant, random bits.
public enum UUIDv7 {
    public static func make(at date: Date = Date()) -> UUID {
        var generator = SystemRandomNumberGenerator()
        return make(at: date, using: &generator)
    }

    public static func make<G: RandomNumberGenerator>(at date: Date, using generator: inout G) -> UUID {
        let millis = UInt64(max(0, date.timeIntervalSince1970 * 1000))
        var bytes = (0..<16).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        for index in 0..<6 {
            bytes[index] = UInt8(truncatingIfNeeded: millis >> (8 * (5 - index)))
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x70
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
            ))
    }

    /// Unix milliseconds encoded in a v7 UUID.
    public static func timestampMillis(of uuid: UUID) -> UInt64 {
        let u = uuid.uuid
        return [u.0, u.1, u.2, u.3, u.4, u.5].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }
}
