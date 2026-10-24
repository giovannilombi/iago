import AVFoundation
import CoreAudio
import Foundation
import IAGOStore
import IAGOTranscription
import Observation
import SwiftUI
import os

/// Where a dictated text goes, saved next to the audio so a voice note interrupted by a crash or a failed
/// transcription can be offered again at launch (FR-215).
struct VoiceNoteTarget: Codable, Sendable {
    var itemID: String?
    var projectID: String?
    /// Existing note the text is added to (nil: a new note).
    var noteID: String?
    var startedAt: Date
}

/// Records one voice note from the microphone only (FR-212): the default input, or the microphone chosen in
/// the menu bar. The audio goes to `tmp/voice-notes/<id>.caf` and is deleted once its text is saved (FR-215).
@MainActor
@Observable
final class VoiceNoteRecorder {
    enum State: Equatable {
        case idle
        case recording
        case transcribing
        /// The transcription failed: the audio is kept until "Riprova" works or the user discards it.
        case failed(String)
    }

    private(set) var state = State.idle
    private(set) var level: Float = 0
    private(set) var elapsed: TimeInterval = 0
    /// The audio of the last recording, until it is saved or discarded.
    private(set) var audioURL: URL?
    /// Text of the last transcription, taken (and cleared) by the view that shows it. Set also when a call
    /// stops the dictation (FR-217), so the text still reaches its note.
    var transcribedText: String?

    private let service: VoiceNoteService
    private var engine: AVAudioEngine?
    private var file: AVAudioFile?
    private var started = Date()
    private var timer: Timer?
    /// Peak level of the last buffer, written on the audio thread.
    private let meter = OSAllocatedUnfairLock(initialState: Float(0))

    init(service: VoiceNoteService) {
        self.service = service
    }

    var isRecording: Bool { state == .recording }

    func start(target: VoiceNoteTarget) throws {
        guard state != .recording else { return }
        discardAudio()
        let url = try service.newAudioURL(target: target)
        let engine = AVAudioEngine()
        let input = engine.inputNode
        if let uid = service.micUID, let device = Self.deviceID(uid: uid), let unit = input.audioUnit {
            var id = device
            AudioUnitSetProperty(
                unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &id,
                UInt32(MemoryLayout<AudioDeviceID>.size))
        }
        let format = input.outputFormat(forBus: 0)
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        input.installTap(
            onBus: 0, bufferSize: 4096, format: format, block: Self.tapBlock(file: file, meter: self.meter))
        try engine.start()
        self.engine = engine
        self.file = file
        audioURL = url
        started = Date()
        elapsed = 0
        state = .recording
        service.active = self
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.elapsed = Date().timeIntervalSince(self.started)
                self.level = self.meter.withLock { $0 }
            }
        }
    }

    /// The microphone tap runs on a real-time audio thread: built outside the main actor, or Swift 6 would
    /// check its isolation there and stop the app.
    nonisolated private static func tapBlock(file: AVAudioFile, meter: OSAllocatedUnfairLock<Float>)
        -> AVAudioNodeTapBlock
    {
        nonisolated(unsafe) let file = file
        return { buffer, _ in
            try? file.write(from: buffer)
            guard let channel = buffer.floatChannelData?[0] else { return }
            var peak: Float = 0
            for index in 0..<Int(buffer.frameLength) { peak = max(peak, abs(channel[index])) }
            let measured = peak
            meter.withLock { $0 = measured }
        }
    }

    /// Stops and transcribes. Returns the text, or nil if the transcription failed (state `.failed`).
    func stopAndTranscribe() async -> String? {
        stopEngine()
        return await transcribe()
    }

    /// "Riprova" after a failure.
    func transcribe() async -> String? {
        guard let audioURL else { return nil }
        state = .transcribing
        do {
            let text = try await service.transcribe(audioURL)
            state = .idle
            transcribedText = text
            return text
        } catch {
            state = .failed(service.describe(error))
            return nil
        }
    }

    /// The text is in a saved note: the audio is no longer needed (FR-215).
    func finish() {
        if let audioURL { service.delete(audioURL) }
        audioURL = nil
        state = .idle
    }

    /// "Scarta audio", or the editor closed without saving.
    func discardAudio() {
        stopEngine()
        finish()
    }

    private func stopEngine() {
        timer?.invalidate()
        timer = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        file = nil
        level = 0
        if service.active === self { service.active = nil }
        if state == .recording { state = .idle }
    }

    static func deviceID(uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var cfUID = uid as CFString
        let status = withUnsafePointer(to: &cfUID) { pointer in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &address, UInt32(MemoryLayout<CFString>.size), pointer, &size,
                &device)
        }
        return status == noErr && device != 0 ? device : nil
    }
}

/// Voice notes across the app: the temporary folder, the transcription and the recordings left behind.
@MainActor
final class VoiceNoteService {
    private let transcription: TranscriptionService
    private let archive: Archive
    private let folder: URL
    /// The recorder that is listening, so a call starting can stop it first (FR-217).
    weak var active: VoiceNoteRecorder?

    init(transcription: TranscriptionService, archive: Archive, folder: URL) {
        self.transcription = transcription
        self.archive = archive
        self.folder = folder
    }

    var micUID: String? { try? archive.setting(StatusItemController.micKey) }

    func newAudioURL(target: VoiceNoteTarget) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let id = UUID().uuidString
        let url = folder.appendingPathComponent("\(id).caf")
        try JSONEncoder().encode(target).write(to: sidecar(url))
        return url
    }

    func transcribe(_ url: URL) async throws -> String {
        try await transcription.dictate(url)
    }

    func delete(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: sidecar(url))
    }

    func describe(_ error: Error) -> String {
        if case ModelManager.ModelError.missing = error {
            return String(localized: "Mancano i modelli di trascrizione")
        }
        return ErrorText.describe(error)
    }

    /// Stops a voice note being dictated before a call starts; its text is saved where it was going.
    func stopForCall() async {
        guard let recorder = active, recorder.isRecording else { return }
        _ = await recorder.stopAndTranscribe()
    }

    /// Recordings left behind (failed transcription, crash, editor closed by force), oldest first.
    func leftovers() -> [(audio: URL, target: VoiceNoteTarget)] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "caf" }.compactMap { url in
            guard let data = try? Data(contentsOf: sidecar(url)),
                let target = try? JSONDecoder().decode(VoiceNoteTarget.self, from: data)
            else { return nil }
            return (url, target)
        }
        .sorted { $0.target.startedAt < $1.target.startedAt }
    }

    /// Transcribes a leftover recording and saves its text as a dictated note on its target.
    func recover(_ audio: URL, _ target: VoiceNoteTarget) async throws {
        let text = try await transcribe(audio)
        if let noteID = target.noteID, try archive.note(noteID) != nil {
            try archive.updateNote(noteID) { note in
                note.body = note.body.isEmpty ? text : "\(note.body)\n\n\(text)"
            }
        } else {
            try archive.addNote(
                itemID: target.itemID, projectID: target.itemID == nil ? target.projectID : nil, body: text,
                notedAt: target.startedAt, input: .voice)
        }
        delete(audio)
    }

    private func sidecar(_ url: URL) -> URL { url.deletingPathExtension().appendingPathExtension("json") }
}

/// "Nota vocale…" from the menu bar (FR-216): starts listening at once; the note goes to the last item
/// created or opened, or to another recent item or a project. The date is the moment of the recording.
struct VoiceNotePanel: View {
    let model: AppModel
    let close: () -> Void
    @State private var recorder: VoiceNoteRecorder?
    @State private var target: String = ""
    @State private var text = ""
    @State private var startedAt = Date()
    @State private var recentItems: [Item] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "Nota vocale"), systemImage: "mic.fill").font(.title3).bold()
            Picker(String(localized: "Aggiungi a"), selection: $target) {
                Section(String(localized: "Elementi recenti")) {
                    ForEach(recentItems) { item in
                        Text(item.title).tag("item:\(item.id)")
                    }
                }
                Section(String(localized: "Progetti")) {
                    ForEach(model.projects) { project in
                        Text(String(localized: "Nota di progetto · \(project.name)")).tag("project:\(project.id)")
                    }
                }
            }
            .disabled(recorder?.isRecording == true)
            if let recorder {
                DictationBar(recorder: recorder, replace: .constant(false), hasText: !text.isEmpty) { toggle(recorder) }
            }
            TextEditor(text: $text)
                .font(.body).frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
            Text(
                String(
                    localized:
                        "Data: \(startedAt.formatted(date: .abbreviated, time: .shortened)) · l'audio non viene conservato"
                )
            )
            .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) {
                    recorder?.discardAudio()
                    close()
                }
                .keyboardShortcut(.cancelAction)
                Button(String(localized: "Salva")) { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(
                        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || target.isEmpty
                            || recorder?.state == .recording || recorder?.state == .transcribing)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear {
            recentItems = Array(((try? model.archive.items()) ?? []).prefix(8))
            if let last = model.lastItemID, let item = model.item(last), !recentItems.contains(where: { $0.id == last })
            {
                recentItems.insert(item, at: 0)
            }
            target = (model.lastItemID ?? recentItems.first?.id).map { "item:\($0)" } ?? ""
            let recorder = VoiceNoteRecorder(service: model.voiceNotes)
            self.recorder = recorder
            toggle(recorder)
        }
        .onChange(of: recorder?.transcribedText) { _, value in
            guard let value else { return }
            text = text.isEmpty ? value : "\(text)\n\n\(value)"
            recorder?.transcribedText = nil
        }
    }

    private var targetIDs: (item: String?, project: String?) {
        if target.hasPrefix("item:") { return (String(target.dropFirst(5)), nil) }
        if target.hasPrefix("project:") { return (nil, String(target.dropFirst(8))) }
        return (nil, nil)
    }

    private func toggle(_ recorder: VoiceNoteRecorder) {
        if recorder.isRecording {
            Task { _ = await recorder.stopAndTranscribe() }
        } else if case .failed = recorder.state {
            Task { _ = await recorder.transcribe() }
        } else {
            Task {
                guard await MicrophonePermission.ensure() else { return }
                startedAt = Date()
                let ids = targetIDs
                do {
                    try recorder.start(
                        target: VoiceNoteTarget(
                            itemID: ids.item, projectID: ids.project, noteID: nil, startedAt: startedAt))
                } catch {
                    model.lastError = String(
                        localized: "Impossibile avviare il microfono: \(ErrorText.describe(error))")
                }
            }
        }
    }

    private func save() {
        let ids = targetIDs
        var draft = ids.item.map { NoteDraft(itemID: $0) } ?? NoteDraft(projectID: ids.project ?? "")
        if ids.item == nil { draft.streamIDs = model.scopeStreamIDs }
        draft.body = text
        draft.notedAt = startedAt
        draft.input = .voice
        model.saveNote(draft)
        recorder?.finish()
        close()
    }
}
