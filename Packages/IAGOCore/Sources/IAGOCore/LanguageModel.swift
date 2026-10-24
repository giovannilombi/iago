import Foundation

/// A local language model (ADR-0048): it runs on the Mac, inside IAGO, and never uses the network. The app gives
/// one to the features that need it only when the user has downloaded and chosen a model.
public protocol LLMProvider: Sendable {
    /// Catalog id of the model, recorded with what it writes.
    var modelID: String { get }
    /// Name shown to the user ("Qwen 3.5 9B").
    var modelName: String { get }
    /// Generates the answer to one request; cancelling the task stops it.
    func generate(_ request: LLMRequest) async throws -> String
}

public struct LLMRequest: Sendable, Equatable {
    /// How the model must behave.
    public var system: String
    /// The text to work on.
    public var prompt: String
    public var maxTokens: Int
    /// 0: always the most likely answer (default, for rewriting and extraction).
    public var temperature: Float

    public init(system: String, prompt: String, maxTokens: Int = 1_024, temperature: Float = 0) {
        self.system = system
        self.prompt = prompt
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}

/// A local embedding model for the search by meaning (ADR-0049): vectors of texts, L2-normalised, on the Mac.
public protocol TextEmbedder: Sendable {
    /// Catalog id of the model; vectors of different models are never mixed.
    var modelID: String { get }
    /// `query`: a search question (some models want it marked); otherwise passages to index.
    func embed(_ texts: [String], query: Bool) async throws -> [[Float]]
}
