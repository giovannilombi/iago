import Foundation
import IAGOCore
import IAGOEngine
import MLX
import MLXLLM
import MLXLMCommon
import Tokenizers
import os

/// The local engine on MLX (ADR-0048): the only code that imports MLX. It loads the model from its folder only — the
/// downloader given to MLX refuses to download — at the first request, and frees the memory after 10 minutes idle.
/// No text is logged: only model, duration and length.
actor MLXProvider: LLMProvider {
    nonisolated let modelID: String
    nonisolated let modelName: String
    private let folder: URL
    private let extraEOSTokens: Set<String>
    private var container: ModelContainer?
    private var unload: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.giovannilombi.iago", category: "engine")

    static let idleTime: Duration = .seconds(600)

    init(model: EngineModel, folder: URL) {
        modelID = model.id
        modelName = model.name
        self.folder = folder
        extraEOSTokens = Set(model.extraEOSTokens)
    }

    func generate(_ request: LLMRequest) async throws -> String {
        unload?.cancel()
        let container = try await loaded()
        let started = ContinuousClock.now
        let session = ChatSession(
            container, instructions: request.system,
            generateParameters: GenerateParameters(maxTokens: request.maxTokens, temperature: request.temperature),
            // Qwen thinks aloud by default: not wanted for rewriting and extraction.
            additionalContext: ["enable_thinking": false])
        let answer = try await session.respond(to: request.prompt)
        logger.notice(
            "Generated with \(self.modelID, privacy: .public) in \(started.duration(to: .now), privacy: .public): \(request.prompt.count) → \(answer.count) characters"
        )
        scheduleUnload()
        return answer
    }

    /// Loads the model now (e.g. to check that a downloaded model works).
    func warmUp() async throws { _ = try await loaded() }

    private func loaded() async throws -> ModelContainer {
        if let container { return container }
        let started = ContinuousClock.now
        let loaded = try await LLMModelFactory.shared.loadContainer(
            from: NoDownloads(), using: LocalTokenizerLoader(),
            configuration: ModelConfiguration(directory: folder, extraEOSTokens: extraEOSTokens))
        logger.notice(
            "Loaded \(self.modelID, privacy: .public) in \(started.duration(to: .now), privacy: .public)")
        container = loaded
        return loaded
    }

    private func scheduleUnload() {
        unload?.cancel()
        unload = Task { [weak self] in
            try? await Task.sleep(for: Self.idleTime)
            guard !Task.isCancelled else { return }
            await self?.free()
        }
    }

    /// GPU memory MLX holds now and at most since the last reset, in bytes (for the trial of the models).
    func memory() -> (active: Int, peak: Int) { (Memory.activeMemory, Memory.peakMemory) }

    func resetPeakMemory() { Memory.peakMemory = 0 }

    func free() {
        container = nil
        Memory.clearCache()
        logger.notice("Unloaded \(self.modelID, privacy: .public) after inactivity")
    }
}

/// MLX may ask a downloader only for remote models; IAGO's are always local, so this one refuses.
struct NoDownloads: MLXLMCommon.Downloader {
    func download(
        id: String, revision: String?, matching patterns: [String], useLatest: Bool,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
        throw CocoaError(.featureUnsupported)
    }
}

/// The tokenizer from the model folder, through swift-transformers (no Hub access for local folders).
struct LocalTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        TokenizerBridge(try await Tokenizers.AutoTokenizer.from(modelFolder: directory))
    }
}

private struct TokenizerBridge: MLXLMCommon.Tokenizer {
    let upstream: any Tokenizers.Tokenizer

    init(_ upstream: any Tokenizers.Tokenizer) { self.upstream = upstream }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? { upstream.convertTokenToId(token) }
    func convertIdToToken(_ id: Int) -> String? { upstream.convertIdToToken(id) }
    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]], tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try upstream.applyChatTemplate(
                messages: messages, tools: tools, additionalContext: additionalContext)
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}
