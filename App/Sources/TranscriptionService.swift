import Foundation
import IAGOCapture
import IAGOCore
import IAGOEngine
import IAGOExport
import IAGOStore
import IAGOTranscription
import IOKit.ps
import os

/// Transcription inside the app (spec 7.2, FR-20, FR-54, FR-55): a persistent "transcribe" job per
/// item. Audio is decrypted to the scratch folder only for the duration of the job.
final class TranscriptionService: Sendable {
    static let jobType = "transcribe"
    static let meLabelKey = "me_label"
    static let onlyOnPowerKey = "transcribe_only_on_power"
    static let engineKey = "transcription_engine"
    static let languageKey = "transcription_language"
    /// FR-22: action after Stop (`ask`, `audio`, `transcribe`, `transcribe_delete`).
    static let defaultActionKey = "default_action"

    /// Engine chosen in the settings (whisper by default, ADR-0023).
    var engine: ModelSpec.Engine {
        (try? archive.setting(Self.engineKey)).flatMap { ModelSpec.Engine(rawValue: $0) } ?? .whisper
    }

    struct Payload: Codable, Sendable {
        /// FR-20 action 3: delete the audio once the transcript is written and verified (FR-54).
        var deleteAudio: Bool
        /// ADR-0031: diarize the mic track too.
        var roomMode: Bool? = nil
    }

    let archive: Archive
    let paths: StoragePaths
    let models: ModelManager
    let queue: JobQueue
    private let pipeline = PipelineCache()
    private let logger = Logger(subsystem: "com.giovannilombi.iago", category: "transcription")

    /// Transcriptions take the engine lane (ADR-0069) and cannot be interrupted.
    private let lane: EngineLane?

    init(archive: Archive, paths: StoragePaths, lane: EngineLane? = nil) {
        self.lane = lane
        self.archive = archive
        self.paths = paths
        self.models = ModelManager(root: paths.models)
        self.queue = JobQueue(archive: archive) { [archive] in
            // Spec 4.3: optionally transcribe only on power.
            (try? archive.setting(Self.onlyOnPowerKey)) != "1" || Self.isOnACPower()
        }
    }

    func start() async throws {
        await queue.register(Self.jobType) { [self] job, progress in
            guard let lane else { return try await run(job, progress: progress) }
            try await lane.run(.background, preemptible: false) { try await self.run(job, progress: progress) }
        }
        try await queue.start()
    }

    /// Queues a transcription. Throws `ModelManager.ModelError.missing` if models must be downloaded first.
    @discardableResult
    func transcribe(itemID: String, deleteAudio: Bool, roomMode: Bool = false) async throws -> Job {
        let missing = models.missing(ModelSpec.required(for: engine))
        guard missing.isEmpty else { throw ModelManager.ModelError.missing(missing.map(\.displayName)) }
        let payload = String(
            decoding: try JSONEncoder().encode(Payload(deleteAudio: deleteAudio, roomMode: roomMode)), as: UTF8.self)
        return try await queue.enqueue(type: Self.jobType, itemID: itemID, payload: payload)
    }

    private func run(_ job: Job, progress: @escaping JobQueue.Progress) async throws {
        guard let itemID = job.itemId, let item = try archive.item(itemID) else {
            throw ArchiveError.notFound(job.itemId ?? "?")
        }
        let payload = try JSONDecoder().decode(Payload.self, from: Data((job.payload ?? "{}").utf8))
        let previousStatus = item.status
        try archive.updateItem(itemID) { $0.status = .transcribing }

        let workspace = paths.scratch.appendingPathComponent("job-\(job.id)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: workspace) }
        do {
            try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
            // «Più persone nella stanza» ticked: always; otherwise IAGO decides (ADR-0031).
            let input = try decryptInput(
                itemID: itemID, into: workspace, roomMode: payload.roomMode == true ? .on : .auto)
            var pipeline = try await pipeline.get(models, engine: engine)
            pipeline.meLabel = (try archive.setting(Self.meLabelKey)) ?? MeLabel.defaultName
            let language = (try archive.setting(Self.languageKey)) ?? "it"
            let output = try await pipeline.run(
                itemId: itemID, input: input,
                options: .init(language: language == "auto" ? nil : language, vocabulary: vocabulary(for: item)),
                progress: progress)
            try Task.checkCancellation()
            try store(output.transcript, itemID: itemID)
            // Voices are a help: a failure there does not lose the transcript.
            do { try recognizeVoices(output.voices, itemID: itemID) } catch {
                logger.error("Voice prints of \(itemID, privacy: .public) failed: \(error, privacy: .public)")
            }
            if payload.deleteAudio { try deleteAudioAfterVerifying(output.transcript, itemID: itemID) }
            try archive.updateItem(itemID) { $0.status = .transcribed }
            logger.notice(
                "Transcribed \(itemID, privacy: .public): \(output.transcript.segments.count) segments, \(output.metrics.speedFactor, format: .fixed(precision: 1))x"
            )
        } catch {
            let cancelled = error is CancellationError
            try? archive.updateItem(itemID) { $0.status = cancelled ? previousStatus : .error }
            throw error
        }
    }

    static let glossaryKey = "transcription.glossary"

    /// What Whisper should spell right for this item: the user's glossary, then project, client, streams and the
    /// people of the project.
    func vocabulary(for item: Item) -> [String] {
        var terms = ((try? archive.setting(Self.glossaryKey)) ?? nil)?.split(separator: ",").map(String.init) ?? []
        if let projectID = item.projectId,
            let project = (try? archive.projects(includeArchived: true))?.first(where: { $0.id == projectID })
        {
            terms.append(project.name)
            if let clientID = project.clientId,
                let client = (try? archive.clients(includeArchived: true))?.first(where: { $0.id == clientID })
            {
                terms.append(client.name)
            }
            terms += ((try? archive.streams()) ?? []).filter { $0.projectId == projectID }.map(\.name)
            terms += ((try? archive.contacts(projectID: projectID)) ?? []).map(\.name)
        }
        return terms
    }

    /// Decrypts the tracks to transcribe: mic + system for a recording, the single track for an import
    /// (or for a phase 0 recording without system track).
    private func decryptInput(
        itemID: String, into workspace: URL, roomMode: TranscriptionPipeline.RoomMode
    ) throws -> TranscriptionPipeline.Input {
        let assets = try archive.assets(itemID: itemID)
        func decrypt(_ kind: Asset.Kind) throws -> URL? {
            guard let asset = assets.first(where: { $0.kind == kind }) else { return nil }
            let url = workspace.appendingPathComponent("\(kind.rawValue).m4a")
            try archive.readAsset(asset, to: url)
            return url
        }
        if let imported = try decrypt(.audioImport) { return .imported(imported) }
        guard let mic = try decrypt(.audioMic) else { throw TranscriptionError.audio("No audio left to transcribe") }
        if let system = try decrypt(.audioSystem) { return .recording(mic: mic, system: system, roomMode: roomMode) }
        return .imported(mic)
    }

    /// `transcript.json` is the source of truth; TXT and MD are rendered from it (FR-51).
    /// A call that had only Teams' transcript keeps it beside IAGO's (ADR-0078); IAGO's becomes the main one, since
    /// its minutes are tied to the audio.
    private func store(_ transcript: Transcript, itemID: String) throws {
        if let main = try archive.transcripts(itemID: itemID).main,
            (try? Transcript.decode(from: archive.readAssetData(main)))?.isImported == true
        {
            try archive.setMainTranscriptAside(itemID: itemID)
        }
        try archive.storeAsset(
            try transcript.encoded(), itemID: itemID, kind: .transcriptJSON, fileName: "transcript.json")
        try archive.setSpeakers(transcript.speakers.map { ($0.id, $0.label) }, for: itemID)
        try archive.indexTranscript(transcript, itemID: itemID)
        try renderTextAssets(itemID: itemID, transcript: transcript)
    }

    /// Voice prints (ADR-0073), only when the user turned them on: the speakers' voices are kept, and a speaker
    /// that sounds like a known voice gets a proposal with that name, to confirm like any other.
    private func recognizeVoices(_ voices: [TranscriptionPipeline.Voice], itemID: String) throws {
        guard archive.voicesEnabled() else { return }
        try archive.storeVoices(
            voices.map { SpeakerVoice(speakerID: $0.speakerID, embedding: $0.embedding, seconds: $0.seconds) },
            itemID: itemID)
        let labels = Dictionary(
            uniqueKeysWithValues: try archive.speakers(itemID: itemID).map { ($0.speakerId, $0.label) })
        let proposals = try archive.voiceMatches(itemID: itemID).map { match in
            (
                kind: Suggestion.Kind.person,
                payload: SuggestionPayload(
                    text: match.name, confidence: String(Int((match.similarity * 100).rounded())),
                    targetID: match.speakerID, reason: labels[match.speakerID] ?? match.speakerID)
            )
        }
        try archive.replacePendingSuggestions(itemID: itemID, model: "voice", origin: .voice, proposals)
    }

    /// Regenerates `transcript.txt` and `transcript.md` (also after renames and notes).
    func renderTextAssets(itemID: String, transcript: Transcript? = nil) throws {
        try TextAssets.render(archive: archive, itemID: itemID, transcript: transcript)
    }

    /// FR-54: the audio goes only after the stored JSON has been read back, checksum-verified and decoded
    /// to the same transcript. Deleted for good, not moved to the trash (ADR-0030).
    private func deleteAudioAfterVerifying(_ transcript: Transcript, itemID: String) throws {
        guard let stored = try archive.assets(itemID: itemID).first(where: { $0.kind == .transcriptJSON }) else {
            throw TranscriptionError.engineFailure("transcript.json not stored")
        }
        // `readAssetData` checks the SHA-256 recorded when it was written.
        let data = try archive.readAssetData(stored)
        guard data == (try transcript.encoded()), (try? Transcript.decode(from: data)) != nil else {
            throw TranscriptionError.engineFailure("transcript.json does not match after writing")
        }
        for asset in try archive.assets(itemID: itemID, includeTrashed: true) where asset.kind.isAudio {
            try archive.purgeAsset(asset.id)
        }
    }

    /// Downloads the missing models one after the other (explicit user action, spec 7.5), logging every
    /// network access in the audit log. `progress` receives 0…1 over the total size.
    func downloadMissingModels(progress: @escaping @Sendable (Double) -> Void) async throws {
        try await downloadModels(models.missing(ModelSpec.required(for: engine)), progress: progress)
    }

    func downloadModels(_ missing: [ModelSpec], progress: @escaping @Sendable (Double) -> Void) async throws {
        let total = Double(max(1, missing.reduce(0) { $0 + $1.approximateBytes }))
        var done = 0.0
        for spec in missing {
            let weight = Double(spec.approximateBytes) / total
            let offset = done
            try await models.download(
                spec, progress: { progress(offset + weight * $0) },
                onNetworkAccess: { [archive] detail in
                    try? archive.audit(.modelDownload, action: "download", detail: detail)
                })
            done += weight
        }
        progress(1)
    }

    /// Voice note (FR-211): transcribed right away, outside the job queue. The engine is shared with call jobs
    /// and serializes its chunks, so a dictation slips in between the chunks of a long transcription.
    func dictate(_ url: URL) async throws -> String {
        let missing = models.missing(ModelSpec.required(for: engine))
        guard missing.isEmpty else { throw ModelManager.ModelError.missing(missing.map(\.displayName)) }
        let pipeline = try await pipeline.get(models, engine: engine)
        let language = (try archive.setting(Self.languageKey)) ?? "it"
        return try await pipeline.dictate(url, options: .init(language: language == "auto" ? nil : language))
    }

    /// Releases the models before quitting: whisper.cpp aborts in its static destructors if its Metal
    /// context is still alive at exit.
    func shutdown() async {
        if let job = await queue.runningJob { try? await queue.cancel(job.id) }
        await pipeline.release()
    }

    static func isOnACPower() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        else { return true }
        return type == kIOPMACPowerKey
    }
}

/// Loads the pipeline once (models take seconds to load) and keeps it for later jobs.
private actor PipelineCache {
    private var pipeline: (engine: ModelSpec.Engine, pipeline: TranscriptionPipeline)?

    func get(_ models: ModelManager, engine: ModelSpec.Engine) async throws -> TranscriptionPipeline {
        if let pipeline, pipeline.engine == engine { return pipeline.pipeline }
        pipeline = nil
        let loaded = try await models.loadPipeline(engine: engine)
        pipeline = (engine, loaded)
        return loaded
    }

    func release() {
        pipeline = nil
    }
}
