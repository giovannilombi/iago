import Foundation
import IAGOCore

/// One recording in progress: two track writers plus `session.json` in `tmp/sessions/<itemId>/`.
/// Not thread-safe: confined to `SessionRouter.queue`.
final class RecordingSession {
    static let manifestName = "session.json"
    static let sampleRate: Double = 48_000
    /// Bookmarks point this far before the click: by the time the user reacts, the moment has passed (ADR-0024).
    static let bookmarkLookback: Double = 5

    let directory: URL
    private(set) var manifest: SessionManifest
    private var timeline: SessionTimeline
    private var writers: [TrackKind: TrackWriter] = [:]
    private(set) var lastError: Error?
    /// ADR-0051: muted in the call app; the mic track receives silence, so the tracks stay aligned.
    private(set) var micMuted = false

    var itemID: ItemID { manifest.itemID }

    init(sessionsRoot: URL, startHostTime: UInt64, startedAt: Date = Date()) throws {
        let itemID = ItemID.generate(at: startedAt)
        directory = sessionsRoot.appendingPathComponent(itemID.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        manifest = SessionManifest(itemID: itemID, startedAt: startedAt, sampleRate: Self.sampleRate)
        timeline = SessionTimeline(startHostTime: startHostTime)
        for kind in TrackKind.allCases {
            writers[kind] = try TrackWriter(
                kind: kind, url: directory.appendingPathComponent("\(kind.rawValue).caf"), sampleRate: Self.sampleRate)
        }
        try saveManifest()
    }

    func consume(_ buffer: CapturedBuffer) {
        guard manifest.state == .recording || manifest.state == .paused,
            let position = timeline.position(of: buffer.hostTime)
        else { return }
        let samples =
            buffer.track == .mic && micMuted ? [Float](repeating: 0, count: buffer.samples.count) : buffer.samples
        do {
            try writers[buffer.track]?.append(samples, sourceRate: buffer.sampleRate, at: position)
        } catch {
            lastError = error
        }
    }

    func elapsed(at hostTime: UInt64) -> Double { timeline.elapsed(at: hostTime) }

    func setMicMuted(_ muted: Bool, at hostTime: UInt64) {
        guard muted != micMuted else { return }
        micMuted = muted
        manifest.markers.append(
            CaptureMarker(kind: muted ? .micMuted : .micUnmuted, at: timeline.elapsed(at: hostTime), track: .mic))
        try? saveManifest()
    }

    func setSuggestedTitle(_ title: String?) {
        manifest.suggestedTitle = title
        try? saveManifest()
    }

    var isPaused: Bool { timeline.isPaused }

    func pause(at hostTime: UInt64, kind: CaptureMarker.Kind = .pause) {
        guard !timeline.isPaused else { return }
        manifest.markers.append(CaptureMarker(kind: kind, at: timeline.elapsed(at: hostTime)))
        timeline.pause(at: hostTime)
        manifest.state = .paused
        flushAndSave()
    }

    func resume(at hostTime: UInt64) {
        guard timeline.isPaused else { return }
        timeline.resume(at: hostTime)
        manifest.markers.append(CaptureMarker(kind: .resume, at: timeline.elapsed(at: hostTime)))
        manifest.state = .recording
        flushAndSave()
    }

    func addMarker(_ kind: CaptureMarker.Kind, track: TrackKind?, detail: String?, at hostTime: UInt64) {
        manifest.markers.append(
            CaptureMarker(kind: kind, at: timeline.elapsed(at: hostTime), track: track, detail: detail))
        try? saveManifest()
    }

    /// Returns the timeline position of the bookmark, `bookmarkLookback` before `hostTime` (clamped to 0).
    func addBookmark(note: String?, at hostTime: UInt64) -> Double {
        let position = max(0, timeline.elapsed(at: hostTime) - Self.bookmarkLookback)
        manifest.markers.append(CaptureMarker(kind: .bookmark, at: position, detail: note))
        flushAndSave()
        return position
    }

    /// "Segna momento con screenshot" (ADR-0072): the PNG and the text read on it go into the session folder, so the
    /// archiver encrypts them with the recording; the marker is at the current position, without look-back.
    func addScreenshot(png: Data, text: String?, at hostTime: UInt64) throws -> Double {
        let position = timeline.elapsed(at: hostTime)
        let count = manifest.markers.filter { $0.kind == .screenshot }.count + 1
        let name = "screenshot-\(count).png"
        try png.write(to: directory.appendingPathComponent(name), options: .atomic)
        if let text, !text.isEmpty {
            try Data(text.utf8).write(
                to: directory.appendingPathComponent("screenshot-\(count).txt"), options: .atomic)
        }
        manifest.markers.append(CaptureMarker(kind: .screenshot, at: position, detail: name))
        try saveManifest()
        return position
    }

    func updateBookmarkNote(at position: Double, note: String?) {
        guard let index = manifest.markers.lastIndex(where: { $0.kind == .bookmark && $0.at == position }) else {
            return
        }
        manifest.markers[index].detail = note
        try? saveManifest()
    }

    func noteDevice(_ name: String, for track: TrackKind) {
        guard manifest.devices[track]?.last != name else { return }
        manifest.devices[track, default: []].append(name)
        try? saveManifest()
    }

    func silentTrack(at hostTime: UInt64) -> TrackKind? {
        guard !timeline.isPaused else { return nil }
        var lastSignal: [TrackKind: Double] = [:]
        for (kind, writer) in writers {
            lastSignal[kind] = writer.lastSignalPosition
        }
        return SilenceAlarm.silentTrack(now: timeline.elapsed(at: hostTime), lastSignal: lastSignal)
    }

    func micAbsent(at hostTime: UInt64, hasDevice: Bool) -> Bool {
        guard !timeline.isPaused else { return false }
        return SilenceAlarm.micAbsent(
            now: timeline.elapsed(at: hostTime), lastBuffer: writers[.mic]?.lastBufferPosition, hasDevice: hasDevice)
    }

    /// Periodic flush, so data reaches the disk even if buffers stop arriving.
    func tick() {
        for writer in writers.values {
            do { try writer.flush() } catch { lastError = error }
        }
    }

    /// Closes the tracks. The session directory is then ready for `SessionFinalizer`.
    func stop(at hostTime: UInt64) throws {
        manifest.duration = timeline.elapsed(at: hostTime)
        manifest.state = .stopped
        let frames = Int64((timeline.elapsed(at: hostTime) * Self.sampleRate).rounded())
        for writer in writers.values {
            writer.pad(toFrames: frames)
            try writer.close()
        }
        try saveManifest()
    }

    private func flushAndSave() {
        tick()
        do { try saveManifest() } catch { lastError = error }
    }

    private func saveManifest() throws {
        try manifest.encoded().write(to: directory.appendingPathComponent(Self.manifestName), options: .atomic)
    }
}
