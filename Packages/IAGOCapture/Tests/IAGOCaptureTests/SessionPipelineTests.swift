import AVFoundation
import Foundation
import IAGOCore
import Testing

@testable import IAGOCapture

/// End-to-end session tests with synthetic buffers (no audio hardware).
@Suite struct SessionPipelineTests {
    let paths: StoragePaths
    let start: UInt64 = 10_000_000

    init() throws {
        paths = StoragePaths(root: FileManager.default.temporaryDirectory.appendingPathComponent("iago-\(UUID())"))
        try paths.createDirectories()
    }

    func host(_ seconds: Double) -> UInt64 { start + HostClock.ticks(seconds: seconds) }

    /// Feeds `seconds` of a sine wave in 10 ms buffers starting at timeline time `from`.
    func feed(_ session: RecordingSession, track: TrackKind, from: Double, seconds: Double, rate: Double = 48_000) {
        let frames = Int(rate / 100)
        for index in 0..<Int(seconds * 100) {
            let t0 = from + Double(index) / 100
            // Split up: older compilers (CI) time out type-checking the one-line version.
            let omega = 2 * Double.pi * 440
            let samples: [Float] = (0..<frames).map { frame in
                let time: Double = t0 + Double(frame) / rate
                return Float(0.5 * sin(omega * time))
            }
            session.consume(CapturedBuffer(track: track, hostTime: host(t0), sampleRate: rate, samples: samples))
        }
    }

    func duration(of url: URL) throws -> Double {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.fileFormat.sampleRate
    }

    @Test func recordsBothTracksAndFinalizes() throws {
        let session = try RecordingSession(sessionsRoot: paths.sessions, startHostTime: start)
        feed(session, track: .mic, from: 0, seconds: 3)
        feed(session, track: .system, from: 0, seconds: 3, rate: 44_100)
        try session.stop(at: host(3))

        let result = try SessionFinalizer.finalize(sessionDirectory: session.directory, into: paths.finalized)
        #expect(!result.recovered)
        #expect(abs(result.duration - 3) < 0.01)
        for name in ["mic.m4a", "system.m4a", "mix.m4a"] {
            #expect(abs(try duration(of: result.directory.appendingPathComponent(name)) - 3) < 0.1, "\(name)")
        }
        #expect(!FileManager.default.fileExists(atPath: session.directory.path))
    }

    @Test func mutedMicGetsSilenceAndTheMeetingTitleIsKept() throws {
        let session = try RecordingSession(sessionsRoot: paths.sessions, startHostTime: start)
        session.setSuggestedTitle("Adesione fondo pensione")
        feed(session, track: .mic, from: 0, seconds: 1)
        session.setMicMuted(true, at: host(1))
        feed(session, track: .mic, from: 1, seconds: 1)
        session.setMicMuted(false, at: host(2))
        feed(session, track: .mic, from: 2, seconds: 1)
        feed(session, track: .system, from: 0, seconds: 3)
        try session.stop(at: host(3))
        #expect(session.manifest.markers.map(\.kind) == [.micMuted, .micUnmuted])
        #expect(abs(session.manifest.markers[0].at - 1) < 0.001)

        // Before finalizing, the mic track holds silence between 1 s and 2 s and the tone around it.
        let file = try AVAudioFile(forReading: session.directory.appendingPathComponent("mic.caf"))
        let buffer = try #require(
            AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let samples = UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))
        func peak(_ from: Double, _ to: Double) -> Float {
            samples[Int(from * 48_000)..<Int(to * 48_000)].map(abs).max() ?? 0
        }
        #expect(peak(0.1, 0.9) > 0.3)
        #expect(peak(1.1, 1.9) == 0)
        #expect(peak(2.1, 2.9) > 0.3)

        let result = try SessionFinalizer.finalize(sessionDirectory: session.directory, into: paths.finalized)
        #expect(result.title == "Adesione fondo pensione")
        #expect(abs(try duration(of: result.directory.appendingPathComponent("mic.m4a")) - 3) < 0.1)
    }

    @Test func pauseExcludesAudioAndRecordsMarkers() throws {
        let session = try RecordingSession(sessionsRoot: paths.sessions, startHostTime: start)
        feed(session, track: .mic, from: 0, seconds: 2)
        session.pause(at: host(2))
        // Buffers delivered during the pause are dropped.
        for index in 0..<100 {
            let t = 2 + Double(index) / 100
            session.consume(
                CapturedBuffer(
                    track: .mic, hostTime: host(t), sampleRate: 48_000, samples: .init(repeating: 1, count: 480)))
        }
        session.resume(at: host(3))
        let frames = 480
        for index in 0..<200 {
            let t = 3 + Double(index) / 100
            session.consume(
                CapturedBuffer(
                    track: .mic, hostTime: host(t), sampleRate: 48_000, samples: .init(repeating: 0.1, count: frames)))
        }
        try session.stop(at: host(5))

        #expect(session.manifest.markers.map(\.kind) == [.pause, .resume])
        #expect(abs(session.manifest.markers[0].at - 2) < 0.001)
        #expect(abs((session.manifest.duration ?? 0) - 4) < 0.001)
        let result = try SessionFinalizer.finalize(sessionDirectory: session.directory, into: paths.finalized)
        #expect(abs(try duration(of: result.directory.appendingPathComponent("mic.m4a")) - 4) < 0.1)
    }

    @Test func gapBecomesSilenceKeepingAlignment() throws {
        let session = try RecordingSession(sessionsRoot: paths.sessions, startHostTime: start)
        feed(session, track: .mic, from: 0, seconds: 1)
        feed(session, track: .mic, from: 2, seconds: 1)  // device change: 1 s without buffers
        try session.stop(at: host(3))
        let caf = session.directory.appendingPathComponent("mic.caf")
        let file = try AVAudioFile(forReading: caf)
        #expect(abs(Double(file.length) - 3 * 48_000) <= 480)
    }

    @Test func crashedSessionIsRecovered() throws {
        let directory: URL
        do {
            // The session is never stopped: simulates kill -9 (data already flushed by tick()).
            let session = try RecordingSession(sessionsRoot: paths.sessions, startHostTime: start)
            feed(session, track: .mic, from: 0, seconds: 2)
            feed(session, track: .system, from: 0, seconds: 2)
            session.tick()
            directory = session.directory
        }
        let pending = SessionFinalizer.pendingSessions(in: paths.sessions)
        #expect(pending.map(\.lastPathComponent) == [directory.lastPathComponent])
        let result = try SessionFinalizer.finalize(sessionDirectory: directory, into: paths.finalized)
        #expect(result.recovered)
        #expect(abs(result.duration - 2) < 0.05)
        #expect(SessionFinalizer.pendingSessions(in: paths.sessions).isEmpty)
    }

    /// kill -9 while no app plays audio: the system track holds only its header.
    @Test func crashedSessionWithEmptySystemTrackKeepsBothTracks() throws {
        let directory: URL
        do {
            let session = try RecordingSession(sessionsRoot: paths.sessions, startHostTime: start)
            feed(session, track: .mic, from: 0, seconds: 2)
            session.tick()
            directory = session.directory
        }
        let result = try SessionFinalizer.finalize(sessionDirectory: directory, into: paths.finalized)
        let mic = try duration(of: result.directory.appendingPathComponent("mic.m4a"))
        let system = try duration(of: result.directory.appendingPathComponent("system.m4a"))
        #expect(abs(mic - 2) < 0.1)
        #expect(abs(system - mic) < 0.05)
    }

    @Test func activeSessionIsNotPending() throws {
        let session = try RecordingSession(sessionsRoot: paths.sessions, startHostTime: start)
        #expect(SessionFinalizer.pendingSessions(in: paths.sessions, excluding: [session.itemID]).isEmpty)
    }
}

@Suite struct BookmarkTests {
    @Test func bookmarkIsSavedWithNote() throws {
        let paths = StoragePaths(root: FileManager.default.temporaryDirectory.appendingPathComponent("iago-\(UUID())"))
        try paths.createDirectories()
        let start: UInt64 = 10_000_000
        let session = try RecordingSession(sessionsRoot: paths.sessions, startHostTime: start)
        let position = session.addBookmark(note: nil, at: start + HostClock.ticks(seconds: 42))
        session.updateBookmarkNote(at: position, note: "decisione sul budget")
        let saved = try SessionManifest.decode(
            from: Data(contentsOf: session.directory.appendingPathComponent(RecordingSession.manifestName)))
        let bookmark = try #require(saved.markers.first)
        #expect(bookmark.kind == .bookmark)
        #expect(abs(bookmark.at - 37) < 0.001)
        #expect(bookmark.detail == "decisione sul budget")
    }

    @Test func bookmarkNearStartIsClampedToZero() throws {
        let paths = StoragePaths(root: FileManager.default.temporaryDirectory.appendingPathComponent("iago-\(UUID())"))
        try paths.createDirectories()
        let start: UInt64 = 10_000_000
        let session = try RecordingSession(sessionsRoot: paths.sessions, startHostTime: start)
        #expect(session.addBookmark(note: nil, at: start + HostClock.ticks(seconds: 3)) == 0)
    }
}

@Suite struct TrackLengthTests {
    /// The system tap delivers nothing while no app plays: the track must still span the session.
    @Test func silentTrackIsPaddedToSessionLength() throws {
        let paths = StoragePaths(root: FileManager.default.temporaryDirectory.appendingPathComponent("iago-\(UUID())"))
        try paths.createDirectories()
        let start: UInt64 = 10_000_000
        let session = try RecordingSession(sessionsRoot: paths.sessions, startHostTime: start)
        for index in 0..<100 {
            let host = start + HostClock.ticks(seconds: Double(index) / 100)
            session.consume(
                CapturedBuffer(
                    track: .mic, hostTime: host, sampleRate: 48_000, samples: .init(repeating: 0.1, count: 480)))
        }
        try session.stop(at: start + HostClock.ticks(seconds: 5))
        for name in ["mic.caf", "system.caf"] {
            let file = try AVAudioFile(forReading: session.directory.appendingPathComponent(name))
            #expect(abs(Double(file.length) / 48_000 - 5) < 0.01, "\(name)")
        }
    }
}
