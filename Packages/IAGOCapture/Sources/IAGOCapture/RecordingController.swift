import Foundation
import IAGOCore

/// Single point of control for recording (spec 5.2), used by the menu bar, shortcuts and UI.
/// State machine: idle → recording ⇄ paused → (finalizing in background) → idle.
public actor RecordingController {
    public enum State: Sendable, Equatable {
        case idle
        case recording
        case paused
    }

    public struct Snapshot: Sendable, Equatable {
        public var state: State
        public var elapsed: Double
        public var micName: String?
        public var silentTrack: TrackKind?
        /// No audio at all from the microphone while recording: the yellow dot (ADR-0093).
        public var micAbsent = false
        public var finalizingCount: Int
        public var lastError: String?
        /// The item being recorded, if any.
        public var itemID: ItemID?
        /// Teams' mute is putting silence on the mic track (ADR-0051).
        public var micMuted = false
    }

    public enum Event: Sendable {
        case finalized(FinalizedRecording)
        case finalizationFailed(itemID: String, message: String)
        case captureFailure(String)
    }

    private let paths: StoragePaths
    private let router = SessionRouter()
    private var engine: CaptureEngine?
    private var micMuted = false
    private var state: State = .idle
    private var finalizingCount = 0
    private var lastError: String?
    private let eventContinuation: AsyncStream<Event>.Continuation
    public nonisolated let events: AsyncStream<Event>

    public init(paths: StoragePaths) {
        self.paths = paths
        (events, eventContinuation) = AsyncStream.makeStream(of: Event.self)
    }

    public func snapshot() -> Snapshot {
        let mic = engine?.currentMic
        let status = router.status(at: HostClock.now(), hasMic: mic != nil)
        return Snapshot(
            state: state, elapsed: status.elapsed, micName: mic?.name, silentTrack: status.silentTrack,
            micAbsent: state == .recording && status.micAbsent,
            finalizingCount: finalizingCount, lastError: lastError ?? status.error,
            itemID: state == .idle ? nil : router.activeItemID, micMuted: state != .idle && micMuted)
    }

    /// Left click on the menu bar icon (FR-02).
    public func toggle() throws {
        switch state {
        case .idle: try start()
        case .recording: pause()
        case .paused: resume()
        }
    }

    public func start() throws {
        guard state == .idle else { return }
        try paths.createDirectories()
        let engine = makeEngine()
        let session = try RecordingSession(sessionsRoot: paths.sessions, startHostTime: HostClock.now())
        router.install(session)
        do {
            try engine.start()
        } catch {
            if let old = router.detach(at: HostClock.now()) { finalizeInBackground(old) }
            throw error
        }
        self.engine = engine
        state = .recording
        lastError = nil
        if micMuted { router.setMicMuted(true, at: HostClock.now()) }
    }

    public func pause(dueToSleep: Bool = false) {
        guard state == .recording else { return }
        router.pause(at: HostClock.now(), kind: dueToSleep ? .autoPauseSleep : .pause)
        state = .paused
    }

    public func resume() {
        guard state == .paused else { return }
        router.resume(at: HostClock.now())
        state = .recording
    }

    /// Stop: saves and finalizes in background (FR-17).
    public func stop() {
        guard state != .idle else { return }
        engine?.stop()
        engine = nil
        if let session = router.detach(at: HostClock.now()) {
            finalizeInBackground(session)
        }
        state = .idle
    }

    /// "Nuova registrazione" (FR-03): the new session starts at the exact host time the old one ends,
    /// while capture keeps running, so there is no gap.
    public func newRecording() throws {
        guard state != .idle else { return try start() }
        let now = HostClock.now()
        let session = try RecordingSession(sessionsRoot: paths.sessions, startHostTime: now)
        if let mic = engine?.currentMic?.name { router.noteDevice(mic, for: .mic, in: session) }
        if let old = router.replace(with: session, at: now) {
            finalizeInBackground(old)
        }
        if micMuted { router.setMicMuted(true, at: now) }
        state = .recording
    }

    /// Waits until all background finalizations are done (used before quitting).
    public func waitForFinalizations() async {
        while finalizingCount > 0 {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// "Segna momento" (FR-05): bookmark at the current position, only while recording.
    /// Returns the timeline position, used to attach a note afterwards.
    @discardableResult
    public func addBookmark(note: String? = nil) -> Double? {
        guard state == .recording else { return nil }
        return router.addBookmark(note: note, at: HostClock.now())
    }

    public func setBookmarkNote(at position: Double, note: String?) {
        router.updateBookmarkNote(at: position, note: note)
    }

    /// "Segna momento con screenshot" (ADR-0072): only while recording (also paused). `hostTime` is the moment the
    /// user asked for it (capture and OCR take a moment). Returns the position.
    @discardableResult
    public func addScreenshot(png: Data, text: String?, at hostTime: UInt64 = HostClock.now()) throws -> Double? {
        guard state != .idle else { return nil }
        return try router.addScreenshot(png: png, text: text, at: hostTime)
    }

    public func setMicOverride(uid: String?) {
        engine?.setMicOverride(uid: uid)
    }

    /// ADR-0051: muted in Teams. Kept for the next session too, until the call app says otherwise.
    public func setMicMuted(_ muted: Bool) {
        micMuted = muted
        router.setMicMuted(muted, at: HostClock.now())
    }

    /// ADR-0051: the meeting title as the tentative title of the recording in progress.
    public func setSuggestedTitle(_ title: String?) {
        router.setSuggestedTitle(title)
    }

    /// Finalizes sessions interrupted by a crash, reboot or power loss (FR-14).
    public func recoverInterruptedSessions() async -> [FinalizedRecording] {
        let active = router.activeItemID.map { Set([$0]) } ?? []
        var recovered: [FinalizedRecording] = []
        for directory in SessionFinalizer.pendingSessions(in: paths.sessions, excluding: active) {
            let output = paths.finalized
            do {
                let result = try await Task.detached(priority: .utility) {
                    try SessionFinalizer.finalize(sessionDirectory: directory, into: output)
                }.value
                recovered.append(result)
            } catch {
                eventContinuation.yield(
                    .finalizationFailed(itemID: directory.lastPathComponent, message: "\(error)"))
            }
        }
        return recovered
    }

    // MARK: Private

    private func makeEngine() -> CaptureEngine {
        let router = router
        return CaptureEngine(
            onBuffer: { router.consume($0) },
            onEvent: { [weak self] event in
                Task { await self?.handle(event) }
            })
    }

    private func handle(_ event: CaptureEngine.Event) {
        let now = HostClock.now()
        switch event {
        case .micChanged(let device, let reason):
            router.markDeviceChange(device.name, reason: "\(reason)", at: now)
        case .micUnavailable:
            router.mark(.deviceChange, track: .mic, detail: "unavailable", at: now)
        case .systemTapRebuilt:
            router.mark(.systemTapRebuilt, track: .system, detail: nil, at: now)
        case .failure(let message):
            lastError = message
            eventContinuation.yield(.captureFailure(message))
        }
    }

    private func finalizeInBackground(_ directory: URL) {
        finalizingCount += 1
        let output = paths.finalized
        Task.detached(priority: .utility) { [weak self] in
            let result = Result { try SessionFinalizer.finalize(sessionDirectory: directory, into: output) }
            await self?.finalizationDone(result, directory: directory)
        }
    }

    private func finalizationDone(_ result: Result<FinalizedRecording, Error>, directory: URL) {
        finalizingCount -= 1
        switch result {
        case .success(let recording):
            eventContinuation.yield(.finalized(recording))
        case .failure(let error):
            lastError = "\(error)"
            eventContinuation.yield(.finalizationFailed(itemID: directory.lastPathComponent, message: "\(error)"))
        }
    }
}

/// Holds the current session and serializes all access to it on one queue: buffers from the capture
/// threads and control calls from the controller.
final class SessionRouter: @unchecked Sendable {
    struct Status {
        var elapsed: Double = 0
        var silentTrack: TrackKind?
        var micAbsent = false
        var error: String?
    }

    private let queue = DispatchQueue(label: "iago.capture.session", qos: .userInitiated)
    private var current: RecordingSession?
    private var lastDevice: [TrackKind: String] = [:]
    private var flushTimer: DispatchSourceTimer?

    init() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in self?.current?.tick() }
        timer.resume()
        flushTimer = timer
    }

    deinit {
        flushTimer?.cancel()
    }

    var activeItemID: ItemID? { queue.sync { current?.itemID } }

    func consume(_ buffer: CapturedBuffer) {
        queue.async { [self] in current?.consume(buffer) }
    }

    func install(_ session: RecordingSession) {
        queue.sync {
            current = session
            lastDevice = [:]
            session.noteDevice("System audio (process tap)", for: .system)
        }
    }

    /// Stops the current session and returns its directory for finalization.
    func detach(at hostTime: UInt64) -> URL? {
        queue.sync {
            guard let session = current else { return nil }
            current = nil
            do { try session.stop(at: hostTime) } catch {}
            return session.directory
        }
    }

    func replace(with session: RecordingSession, at hostTime: UInt64) -> URL? {
        queue.sync {
            let old = current
            do { try old?.stop(at: hostTime) } catch {}
            current = session
            session.noteDevice("System audio (process tap)", for: .system)
            return old?.directory
        }
    }

    func pause(at hostTime: UInt64, kind: CaptureMarker.Kind) {
        queue.sync { current?.pause(at: hostTime, kind: kind) }
    }

    func setMicMuted(_ muted: Bool, at hostTime: UInt64) {
        queue.sync { current?.setMicMuted(muted, at: hostTime) }
    }

    func setSuggestedTitle(_ title: String?) {
        queue.sync { current?.setSuggestedTitle(title) }
    }

    func resume(at hostTime: UInt64) {
        queue.sync { current?.resume(at: hostTime) }
    }

    func mark(_ kind: CaptureMarker.Kind, track: TrackKind?, detail: String?, at hostTime: UInt64) {
        queue.async { [self] in current?.addMarker(kind, track: track, detail: detail, at: hostTime) }
    }

    func markDeviceChange(_ name: String, reason: String, at hostTime: UInt64) {
        queue.async { [self] in
            guard let session = current else { return }
            let isFirst = session.manifest.devices[.mic] == nil
            session.noteDevice(name, for: .mic)
            if !isFirst {
                session.addMarker(.deviceChange, track: .mic, detail: "\(name) (\(reason))", at: hostTime)
            }
        }
    }

    func addBookmark(note: String?, at hostTime: UInt64) -> Double? {
        queue.sync { current?.addBookmark(note: note, at: hostTime) }
    }

    func updateBookmarkNote(at position: Double, note: String?) {
        queue.sync { current?.updateBookmarkNote(at: position, note: note) }
    }

    func addScreenshot(png: Data, text: String?, at hostTime: UInt64) throws -> Double? {
        try queue.sync { try current?.addScreenshot(png: png, text: text, at: hostTime) }
    }

    func noteDevice(_ name: String, for track: TrackKind, in session: RecordingSession) {
        queue.sync { session.noteDevice(name, for: track) }
    }

    func status(at hostTime: UInt64, hasMic: Bool) -> Status {
        queue.sync {
            guard let session = current else { return Status() }
            return Status(
                elapsed: session.elapsed(at: hostTime), silentTrack: session.silentTrack(at: hostTime),
                micAbsent: session.micAbsent(at: hostTime, hasDevice: hasMic),
                error: session.lastError.map { "\($0)" })
        }
    }
}
