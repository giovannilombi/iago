import Foundation
import IAGOCore
import IAGOEngine
import IAGOStore
import Observation
import os

/// What needs the local engine (ADR-0048). Without an engine these stay clickable and explain how to get one.
enum EngineFeature: String, Identifiable, Sendable {
    case tidyText, suggestions, chat, summary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tidyText: String(localized: "Riordina testo")
        case .suggestions: String(localized: "Proposte automatiche")
        case .chat: String(localized: "Chiedi")
        case .summary: String(localized: "Sintesi")
        }
    }

    var explanation: String {
        switch self {
        case .tidyText:
            String(
                localized:
                    "Toglie intercalari, ripetizioni e frasi ripartite da un testo dettato, sistema la punteggiatura e lo divide in paragrafi, senza aggiungere né togliere informazioni. Vedi il risultato prima di sostituire il testo."
            )
        case .suggestions:
            String(
                localized:
                    "Dopo ogni trascrizione o importazione propone decisioni, attività, nomi degli speaker, tag, progetto e collegamenti, ognuno con la frase da cui viene. Niente viene applicato senza la tua conferma."
            )
        case .chat:
            String(
                localized:
                    "Fai una domanda sul progetto, sul cliente o su tutto l'archivio: la risposta usa solo i tuoi contenuti e rimanda a ogni fonte, con il minuto della call."
            )
        case .summary:
            String(
                localized:
                    "Scrive la sintesi della call con il modello della sua categoria (1to1, SAL, Kickoff…). Ogni punto porta il minuto da cui viene, controllato sulla trascrizione; le sezioni senza contenuto dicono «Non emerso»."
            )
        }
    }
}

/// The local engine in the app (ADR-0048): downloads in the background, the model in use, the provider handed to
/// the features. IAGO works without it; nothing falls back to system models.
@MainActor
@Observable
final class EngineService {
    let library: EngineLibrary
    private let archive: Archive
    private let notifier: Notifier
    private let logger = Logger(subsystem: "com.giovannilombi.iago", category: "engine")

    /// Downloads in progress.
    private(set) var progress: [String: EngineProgress] = [:]
    /// The last failure of a download, by model.
    private(set) var failures: [String: String] = [:]
    private var tasks: [String: Task<Void, Never>] = [:]
    /// Bumped when files or the active model change, so views read the library again.
    private(set) var revision = 0
    private var provider: MLXProvider?
    private var embedderInstance: MLXEmbedder?
    /// The single lane of heavy work (ADR-0069), shared with the transcription.
    let lane: EngineLane
    @ObservationIgnored private var memory: EngineMemory?

    /// "Il motore è pronto": shown once after a download (ADR-0048).
    var readyToAnnounce: EngineModel?
    /// A feature was asked for without an engine: "Serve un motore locale".
    var neededFor: EngineFeature?

    init(root: URL, archive: Archive, notifier: Notifier, lane: EngineLane) {
        library = EngineLibrary(root: root)
        self.archive = archive
        self.notifier = notifier
        self.lane = lane
        let memory = EngineMemory(lane: lane) { [weak self] in await self?.freeModels() }
        memory.start()
        self.memory = memory
        adaptToThisMac()
    }

    /// The models are freed now (after background work on Macs with little memory, or under memory pressure); the
    /// next request loads them again.
    func freeModels() async {
        await provider?.free()
        await embedderInstance?.free()
    }

    /// A model that does not fit this Mac (ADR-0069: Gemma 4 12B below 24 GB) is not used: the biggest installed
    /// model that fits takes its place, and the user is told.
    private func adaptToThisMac() {
        guard let active = library.activeModel, !fits(active) else { return }
        let installed = EngineCatalog.models.filter { library.state(of: $0) == .installed }
        guard let replacement = EnginePolicy.replacement(for: active, installed: installed, ramGB: Self.ramGB) else {
            logger.notice("Engine \(active.id, privacy: .public) does not fit this Mac and has no replacement")
            return
        }
        try? library.setActive(replacement.id)
        try? archive.audit(.llm, action: "engine_selected", detail: replacement.id)
        notifier.post(
            title: String(localized: "Motore cambiato"),
            body: String(
                localized:
                    "\(active.name) richiede più memoria di quella di questo Mac: IAGO usa \(replacement.name)."))
        logger.notice("Engine \(active.id, privacy: .public) replaced by \(replacement.id, privacy: .public)")
    }

    /// The model can work on this Mac (ADR-0069).
    func fits(_ model: EngineModel) -> Bool { EnginePolicy.fits(model, ramGB: Self.ramGB) }

    var activeModel: EngineModel? {
        _ = revision
        return library.activeModel
    }

    func state(of model: EngineModel) -> EngineLibrary.State {
        _ = revision
        return library.state(of: model)
    }

    func diskSize(of model: EngineModel) -> Int64 {
        _ = revision
        return library.diskSize(of: model)
    }

    var totalDiskSize: Int64 { EngineCatalog.models.reduce(0) { $0 + diskSize(of: $1) } }

    static var ramGB: Int { EnginePolicy.ramGB }

    /// The engine for a feature; nil after asking the user to choose one (also when the active one is too small for
    /// it: summaries need 9B or more).
    func engine(for feature: EngineFeature) -> (any LLMProvider)? {
        guard let engine = currentEngine, isBigEnough(for: feature) else {
            neededFor = feature
            return nil
        }
        return engine
    }

    /// The active model is big enough for the feature (no active model: false).
    func isBigEnough(for feature: EngineFeature) -> Bool {
        guard let model = activeModel, fits(model) else { return false }
        return model.billions >= (EngineCatalog.minimumBillions[feature.rawValue] ?? 0)
    }

    /// The engine for background work on a feature: nil without one big enough, and nobody is asked.
    func currentEngine(for feature: EngineFeature) -> (any LLMProvider)? {
        isBigEnough(for: feature) ? currentEngine : nil
    }

    /// The engine for background work: nil without one, and nobody is asked.
    var currentEngine: (any LLMProvider)? {
        guard let model = activeModel, fits(model) else { return nil }
        if let provider, provider.modelID == model.id { return provider }
        let fresh = MLXProvider(model: model, folder: library.folder(of: model), lane: lane)
        provider = fresh
        return fresh
    }

    /// The embedding model of the search by meaning (ADR-0049), when downloaded.
    var embedder: (any TextEmbedder)? {
        _ = revision
        guard let model = library.embeddingModel else { return nil }
        if let embedderInstance { return embedderInstance }
        let fresh = MLXEmbedder(model: model, folder: library.folder(of: model), lane: lane)
        embedderInstance = fresh
        return fresh
    }

    // MARK: Download

    func download(_ model: EngineModel) {
        guard tasks[model.id] == nil, fits(model) else { return }
        failures[model.id] = nil
        progress[model.id] = EngineProgress(
            bytes: library.diskSize(of: model), total: model.downloadBytes, bytesPerSecond: 0)
        let downloader = EngineDownloader(library: library)
        let archive = archive
        let id = model.id
        tasks[model.id] = Task { [weak self] in
            do {
                try await downloader.download(
                    model,
                    progress: { value in Task { @MainActor in self?.progress[id] = value } },
                    onNetworkAccess: { line in
                        try? archive.audit(.modelDownload, action: "engine_download", detail: line)
                    })
                self?.finished(model)
            } catch is CancellationError {
                self?.stopped(model, failure: nil)
            } catch {
                self?.stopped(model, failure: ErrorText.describe(error))
            }
        }
    }

    func cancel(_ model: EngineModel) { tasks[model.id]?.cancel() }

    var isDownloading: Bool { !tasks.isEmpty }

    private func finished(_ model: EngineModel) {
        tasks[model.id] = nil
        progress[model.id] = nil
        // ADR-0049: the search by meaning comes with the first engine.
        if model.role == .chat, library.state(of: EngineCatalog.embedding) != .installed {
            download(EngineCatalog.embedding)
        }
        guard model.role == .chat else {
            revision += 1
            return
        }
        // The first engine on this Mac is put to use at once; with others the user chooses.
        if library.activeModel == nil { try? library.setActive(model.id) }
        revision += 1
        readyToAnnounce = model
        notifier.post(
            title: String(localized: "Il motore è pronto"),
            body: String(localized: "\(model.name) è scaricato e verificato. Apri IAGO per vedere cosa puoi fare."))
        logger.notice("Engine \(model.id, privacy: .public) downloaded")
    }

    private func stopped(_ model: EngineModel, failure: String?) {
        tasks[model.id] = nil
        progress[model.id] = nil
        failures[model.id] = failure
        revision += 1
    }

    // MARK: Choice

    func use(_ model: EngineModel) {
        guard fits(model) else { return }
        do {
            try library.setActive(model.id)
            try? archive.audit(.llm, action: "engine_selected", detail: model.id)
        } catch {
            failures[model.id] = ErrorText.describe(error)
        }
        revision += 1
    }

    func delete(_ model: EngineModel) {
        cancel(model)
        do {
            try library.delete(model)
            if provider?.modelID == model.id { provider = nil }
            if model.role == .embedding { embedderInstance = nil }
        } catch {
            failures[model.id] = ErrorText.describe(error)
        }
        revision += 1
    }
}
