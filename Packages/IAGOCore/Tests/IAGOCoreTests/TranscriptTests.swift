import Foundation
import Testing

@testable import IAGOCore

@Suite struct TranscriptTests {
    @Test func matchesSpecSchema() throws {
        let transcript = Transcript(
            itemId: "0192", engine: .init(asr: "whisper.cpp", model: "large-v3-turbo", diarization: "fluidaudio"),
            language: "it", createdAt: Date(timeIntervalSince1970: 1_760_437_860),
            speakers: [.me(), .init(id: "s1", label: "Speaker 1", source: .system)],
            segments: [.init(id: 1, speaker: "s1", start: 12.34, end: 18.02, text: "Buongiorno", confidence: 0.91)])
        let json = try #require(try JSONSerialization.jsonObject(with: transcript.encoded()) as? [String: Any])
        #expect(json["schemaVersion"] as? Int == 1)
        #expect(json["itemId"] as? String == "0192")
        #expect((json["speakers"] as? [[String: Any]])?.first?["source"] as? String == "mic")
        #expect(try Transcript.decode(from: transcript.encoded()) == transcript)
    }
}
