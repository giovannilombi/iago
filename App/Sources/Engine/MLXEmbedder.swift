import Foundation
import IAGOCore
import IAGOEngine
import MLX
import MLXEmbedders
import MLXLMCommon
import os

/// The embedding model on MLX (ADR-0049): Qwen3 Embedding, last-token pooling, L2-normalised vectors. Loaded from its
/// folder at the first request and freed after 10 minutes idle, like the chat engine. Questions get the instruction
/// the model was trained with; passages go as they are. Requests go through the engine lane (ADR-0069).
actor MLXEmbedder: TextEmbedder {
    nonisolated let modelID: String
    private let folder: URL
    private let lane: EngineLane?
    private var container: EmbedderModelContainer?
    private var unload: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.giovannilombi.iago", category: "engine")

    static let maxTokens = 1_024
    static let instruction =
        "Instruct: Given a question, retrieve passages of work calls, emails, documents and notes that answer it\nQuery: "

    init(model: EngineModel, folder: URL, lane: EngineLane? = nil) {
        modelID = model.id
        self.folder = folder
        self.lane = lane
    }

    func embed(_ texts: [String], query: Bool) async throws -> [[Float]] {
        guard !texts.isEmpty else { return [] }
        guard let lane else { return try await vectors(texts, query: query) }
        return try await lane.run { try await self.vectors(texts, query: query) }
    }

    private func vectors(_ texts: [String], query: Bool) async throws -> [[Float]] {
        unload?.cancel()
        let container = try await loaded()
        let inputs = query ? texts.map { Self.instruction + $0 } : texts
        let vectors = await container.perform { context -> [[Float]] in
            let tokenizer = context.tokenizer
            let end = tokenizer.convertTokenToId("<|endoftext|>") ?? tokenizer.eosTokenId ?? 0
            let tokens = inputs.map { text -> [Int] in
                let encoded = Array(tokenizer.encode(text: text, addSpecialTokens: true).prefix(Self.maxTokens - 1))
                return encoded.last == end ? encoded : encoded + [end]
            }
            let width = tokens.map(\.count).max() ?? 1
            let padded = stacked(tokens.map { MLXArray($0 + Array(repeating: end, count: width - $0.count)) })
            let mask = MLXArray(
                tokens.flatMap {
                    Array(repeating: Int32(1), count: $0.count) + Array(repeating: 0, count: width - $0.count)
                }
            ).reshaped([tokens.count, width])
            let output = context.model(padded, positionIds: nil, tokenTypeIds: nil, attentionMask: mask)
            let pooled = context.pooling(output, mask: mask, normalize: true)
            pooled.eval()
            return (0..<tokens.count).map { pooled[$0].asArray(Float.self) }
        }
        scheduleUnload()
        return vectors
    }

    private func loaded() async throws -> EmbedderModelContainer {
        if let container { return container }
        let loaded = try await EmbedderModelFactory.shared.loadContainer(from: folder, using: LocalTokenizerLoader())
        logger.notice("Loaded \(self.modelID, privacy: .public)")
        container = loaded
        return loaded
    }

    private func scheduleUnload() {
        unload?.cancel()
        unload = Task { [weak self] in
            try? await Task.sleep(for: MLXProvider.idleTime)
            guard !Task.isCancelled else { return }
            await self?.free()
        }
    }

    func free() {
        guard container != nil else { return }
        unload?.cancel()
        container = nil
        Memory.clearCache()
    }
}
