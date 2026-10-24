import Foundation
import Testing

@testable import IAGOCore

@Suite struct CaptureTests {
    @Test func manifestRoundTrips() throws {
        var manifest = SessionManifest(
            itemID: .generate(), startedAt: Date(timeIntervalSince1970: 1_760_430_600), sampleRate: 48_000)
        manifest.markers = [
            CaptureMarker(kind: .pause, at: 12.5),
            CaptureMarker(kind: .deviceChange, at: 30, track: .mic, detail: "AirPods Pro"),
        ]
        manifest.devices = [.mic: ["MacBook Pro Microphone", "AirPods Pro"]]
        let decoded = try SessionManifest.decode(from: manifest.encoded())
        #expect(decoded == manifest)
    }

    @Test func unclassifiedTitleFormat() {
        let date = ISO8601DateFormatter().date(from: "2026-10-14T09:30:00Z")!
        let title = ItemTitle.unclassified(startedAt: date, timeZone: TimeZone(identifier: "UTC")!)
        #expect(title == "Unclassified · 2026-10-14 09:30")
    }
}
