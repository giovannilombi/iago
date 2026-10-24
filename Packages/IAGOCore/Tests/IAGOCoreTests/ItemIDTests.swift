import Foundation
import Testing

@testable import IAGOCore

@Suite struct ItemIDTests {
    @Test func uuidV7HasVersionAndVariant() {
        let uuid = UUIDv7.make()
        #expect(uuid.uuid.6 >> 4 == 0x7)
        #expect(uuid.uuid.8 >> 6 == 0b10)
    }

    @Test func uuidV7EncodesTimestamp() {
        let date = Date(timeIntervalSince1970: 1_760_000_000.123)
        let uuid = UUIDv7.make(at: date)
        #expect(UUIDv7.timestampMillis(of: uuid) == 1_760_000_000_123)
    }

    @Test func idsSortByCreationTime() {
        let earlier = ItemID.generate(at: Date(timeIntervalSince1970: 1_000))
        let later = ItemID.generate(at: Date(timeIntervalSince1970: 2_000))
        #expect(earlier.rawValue < later.rawValue)
    }

    @Test func rejectsInvalidRawValue() {
        #expect(ItemID(rawValue: "not-a-uuid") == nil)
    }

    @Test func roundTripsThroughJSON() throws {
        let id = ItemID.generate()
        let data = try JSONEncoder().encode([id])
        #expect(try JSONDecoder().decode([ItemID].self, from: data) == [id])
    }
}
