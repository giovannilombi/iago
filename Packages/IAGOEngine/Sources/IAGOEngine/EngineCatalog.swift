import Foundation

/// One file of a model, at a fixed revision: size and SHA-256 checked after the download (ADR-0048).
public struct EngineFile: Sendable, Hashable, Codable {
    public var path: String
    public var size: Int64
    public var sha256: String

    public init(path: String, size: Int64, sha256: String) {
        self.path = path
        self.size = size
        self.sha256 = sha256
    }
}

/// A model of the curated catalog (ADR-0048): MLX 4-bit weights from Hugging Face, pinned to a commit.
public struct EngineModel: Sendable, Hashable, Identifiable {
    /// A language model the user chooses, or the embedding model of the search by meaning (ADR-0049).
    public enum Role: Sendable, Hashable { case chat, embedding }

    public var id: String
    /// Parameters, in billions: the UI describes the model from it (texts stay in the app's String Catalog).
    public var billions: Double
    public var name: String
    public var family: String
    /// RAM below which IAGO warns before the download.
    public var recommendedRAMGB: Int
    public var license: String
    public var licenseURL: URL
    public var repo: String
    public var revision: String
    public var files: [EngineFile]
    /// End-of-turn tokens the chat template uses besides the tokenizer's own.
    public var extraEOSTokens: [String]
    public var role: Role = .chat

    public var downloadBytes: Int64 { files.reduce(0) { $0 + $1.size } }

    /// The fixed address of a file: `resolve/<commit>`, never a branch.
    public func url(of file: EngineFile) -> URL {
        URL(string: "https://huggingface.co/\(repo)/resolve/\(revision)/\(file.path)")!
    }
}

/// The models the user can choose from. Generated with `scripts/make-engine-catalog.py`; `recommended(forRAMGB:)`
/// comes from the trial on a real call (ADR-0048).
public enum EngineCatalog {
    public static func model(_ id: String) -> EngineModel? { (models + [embedding]).first { $0.id == id } }

    /// The search by meaning (ADR-0049): Qwen3 Embedding 0.6B, multilingual, downloaded with the first engine.
    public static let embedding = EngineModel(
        id: "qwen3-embedding-0.6b", billions: 0.6, name: "Qwen3 Embedding 0.6B", family: "Qwen (Alibaba)",
        recommendedRAMGB: 8, license: "Apache 2.0",
        licenseURL: URL(string: "https://www.apache.org/licenses/LICENSE-2.0")!,
        repo: "mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ", revision: "6c3ae70858513f1a78e9cdca3cae330d9075cd2a",
        files: [
            .init(
                path: "added_tokens.json", size: 707,
                sha256: "c0284b582e14987fbd3d5a2cb2bd139084371ed9acbae488829a1c900833c680"),
            .init(
                path: "chat_template.jinja", size: 4116,
                sha256: "87a2728cb8dc9fe424d624542f6060ec05a1d285ebbec578bb078900e33396b5"),
            .init(
                path: "config.json", size: 937,
                sha256: "e7dfa5b73fb2a03cbc8fb40c394e95b99f03348e237f7f28e7a1daf56a2169bb"),
            .init(
                path: "generation_config.json", size: 117,
                sha256: "28396d421a2108acce96383f6a7de78008f7f1b17f807958f3c14c51dbfb65fb"),
            .init(
                path: "merges.txt", size: 1671853,
                sha256: "8831e4f1a044471340f7c0a83d7bd71306a5b867e95fd870f74d0c5308a904d5"),
            .init(
                path: "model.safetensors", size: 335296756,
                sha256: "3d773d5ee582eda445daeee23f7a2b76124011796df244ddb45e22638fdb7cde"),
            .init(
                path: "model.safetensors.index.json", size: 49770,
                sha256: "90d82744cdb6b7d093f0b812fc21a49b6ffa9d0084a45428f0cfd01eb4adbe12"),
            .init(
                path: "special_tokens_map.json", size: 613,
                sha256: "76862e765266b85aa9459767e33cbaf13970f327a0e88d1c65846c2ddd3a1ecd"),
            .init(
                path: "tokenizer.json", size: 11423705,
                sha256: "def76fb086971c7867b829c23a26261e38d9d74e02139253b38aeb9df8b4b50a"),
            .init(
                path: "tokenizer_config.json", size: 5404,
                sha256: "443bfa629eb16387a12edbf92a76f6a6f10b2af3b53d87ba1550adfcf45f7fa0"),
            .init(
                path: "vocab.json", size: 2776833,
                sha256: "ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910"),
        ], extraEOSTokens: [], role: .embedding)

    /// The model to suggest for a Mac (trial of 2026-10-16 on a real call, ADR-0048): Gemma 4 12B from 32 GB, which
    /// made no wrong proposal but needs ~12.5 GB; below, Qwen 3.5 4B, which fits 16 GB Macs. Qwen 3.5 9B was not more
    /// precise than the 4B and is never the suggestion.
    /// 32 GB or more: Gemma; 16 GB or more: Qwen 9B, the smallest that writes good summaries (trial 2026-10-21);
    /// less: Qwen 4B.
    public static func recommended(forRAMGB ram: Int) -> EngineModel {
        model(ram >= 32 ? "gemma-4-12b" : ram >= 16 ? "qwen3.5-9b" : "qwen3.5-4b")!
    }

    /// The smallest model a feature needs, in billions of parameters (summaries: 9B, ADR-0054).
    public static let minimumBillions: [String: Double] = ["summary": 9]

    public static let models: [EngineModel] = [
        EngineModel(
            id: "qwen3.5-4b", billions: 4, name: "Qwen 3.5 4B", family: "Qwen (Alibaba)",
            recommendedRAMGB: 16, license: "Apache 2.0",
            licenseURL: URL(string: "https://www.apache.org/licenses/LICENSE-2.0")!,
            repo: "mlx-community/Qwen3.5-4B-4bit", revision: "0e7ffd5c629ef7719d4cbc04069232580bfa9d9c",
            files: [
                .init(
                    path: "chat_template.jinja", size: 7756,
                    sha256: "a4aee8afcf2e0711942cf848899be66016f8d14a889ff9ede07bca099c28f715"),
                .init(
                    path: "config.json", size: 3366,
                    sha256: "f3efc81b2ea8d96a45301037d3ccccbcccdef44a961845c87f286aaddbc6eaaa"),
                .init(
                    path: "model.safetensors", size: 3034300695,
                    sha256: "5fb9acd0246866381cf8c5c354c6db1019f6498eec4ccb4f5edcc71ffeacb2db"),
                .init(
                    path: "model.safetensors.index.json", size: 101944,
                    sha256: "52e534c41f7b97708329c85f762e5882bf48bd5955a422c6ae74eba321e6048a"),
                .init(
                    path: "preprocessor_config.json", size: 390,
                    sha256: "27225450ac9c6529872ee1924fcb0962ff5634834f817040f444118116f4e516"),
                .init(
                    path: "processor_config.json", size: 1300,
                    sha256: "14932921ca485d458a04dafd8069fbb0a4505622a48208d19ed247115801385b"),
                .init(
                    path: "tokenizer.json", size: 19989343,
                    sha256: "87a7830d63fcf43bf241c3c5242e96e62dd3fdc29224ca26fed8ea333db72de4"),
                .init(
                    path: "tokenizer_config.json", size: 1139,
                    sha256: "e98f1901ac6f0adff67b1d540bfa0c36ac1a0cf59eb72ed78146ef89aafa1182"),
                .init(
                    path: "vocab.json", size: 6722759,
                    sha256: "ce99b4cb2983d118806ce0a8b777a35b093e2000a503ebde25853284c9dfa003"),
            ], extraEOSTokens: ["<|im_end|>"]),
        EngineModel(
            id: "qwen3.5-9b", billions: 9, name: "Qwen 3.5 9B", family: "Qwen (Alibaba)",
            recommendedRAMGB: 24, license: "Apache 2.0",
            licenseURL: URL(string: "https://www.apache.org/licenses/LICENSE-2.0")!,
            repo: "mlx-community/Qwen3.5-9B-4bit", revision: "8b2b98c00a6b4d291155e4890773ca8f769aee53",
            files: [
                .init(
                    path: "chat_template.jinja", size: 7756,
                    sha256: "a4aee8afcf2e0711942cf848899be66016f8d14a889ff9ede07bca099c28f715"),
                .init(
                    path: "config.json", size: 3331,
                    sha256: "a96942cb6a8a1d3f1d17514d81a1925d04362a6a3233b389d13012211baaa9f8"),
                .init(
                    path: "model-00001-of-00002.safetensors", size: 5349771222,
                    sha256: "a68b87558c6ef43f74c2bd63ce7e9092ceddc3101f3def0030774bae5f42aadd"),
                .init(
                    path: "model-00002-of-00002.safetensors", size: 600449850,
                    sha256: "b0a770bf8469c7f3f18756a0e0283f1c1174344a83e059a4e483f6af4907352d"),
                .init(
                    path: "model.safetensors.index.json", size: 123592,
                    sha256: "dd023913fb87cfdae27fb11dcf695117c925833796ccac3c64117d6652d8ff1e"),
                .init(
                    path: "preprocessor_config.json", size: 390,
                    sha256: "27225450ac9c6529872ee1924fcb0962ff5634834f817040f444118116f4e516"),
                .init(
                    path: "processor_config.json", size: 1300,
                    sha256: "14932921ca485d458a04dafd8069fbb0a4505622a48208d19ed247115801385b"),
                .init(
                    path: "tokenizer.json", size: 19989343,
                    sha256: "87a7830d63fcf43bf241c3c5242e96e62dd3fdc29224ca26fed8ea333db72de4"),
                .init(
                    path: "tokenizer_config.json", size: 1139,
                    sha256: "e98f1901ac6f0adff67b1d540bfa0c36ac1a0cf59eb72ed78146ef89aafa1182"),
                .init(
                    path: "vocab.json", size: 6722759,
                    sha256: "ce99b4cb2983d118806ce0a8b777a35b093e2000a503ebde25853284c9dfa003"),
            ], extraEOSTokens: ["<|im_end|>"]),
        EngineModel(
            id: "gemma-4-12b", billions: 12, name: "Gemma 4 12B", family: "Gemma (Google)",
            recommendedRAMGB: 32, license: "Apache 2.0",
            licenseURL: URL(string: "https://ai.google.dev/gemma/docs/gemma_4_license")!,
            repo: "mlx-community/gemma-4-12B-it-qat-4bit", revision: "e70c6b3ba0979b3357dcd2f223ad8bde7787a6b6",
            files: [
                .init(
                    path: "chat_template.jinja", size: 17466,
                    sha256: "36e3a42e5cf14cd0020e72d92e1fdd9970f59b82170e421f0cbe1bb42bead3f0"),
                .init(
                    path: "config.json", size: 39882,
                    sha256: "fe091f98e6f7e5e80461bd8ec7ced6d87ac16987586239386ed44b82ecbc2b12"),
                .init(
                    path: "generation_config.json", size: 260,
                    sha256: "a8349d9bd64cc5841297fcb5002f0fdc4749c473c8f1b10ea337f9ce4ee7014e"),
                .init(
                    path: "model-00001-of-00003.safetensors", size: 5343482357,
                    sha256: "9fc7406175fdfbca0f941767bfa222ecdaea71ab1d2865cd049eb2a0a1d9f2a1"),
                .init(
                    path: "model-00002-of-00003.safetensors", size: 5315166254,
                    sha256: "62a2b9715c9bef3a4f0a2769fe2d5022ae55907b631731a24568f3e8f444d9e9"),
                .init(
                    path: "model-00003-of-00003.safetensors", size: 329123819,
                    sha256: "fd75a04eb5cc73be2760898715472e92626b0a8ba03b19ee57737419885da6c9"),
                .init(
                    path: "model.safetensors.index.json", size: 135330,
                    sha256: "b87c93774de5d13ca9d0e21b045793e42e5df032fb5e7622212524f56f9695f2"),
                .init(
                    path: "processor_config.json", size: 868,
                    sha256: "016a1db9c4f41ea0c61919c46855ea5e7c45c6e4ae4bfbedfb5b6bed79a2fe92"),
                .init(
                    path: "tokenizer.json", size: 32169626,
                    sha256: "cc8d3a0ce36466ccc1278bf987df5f71db1719b9ca6b4118264f45cb627bfe0f"),
                .init(
                    path: "tokenizer_config.json", size: 2747,
                    sha256: "a4260621db48fa22f2b09ce3ba5ad0ec0cc0e032aa702e3ab743a0bc9d6e1d06"),
            ], extraEOSTokens: ["<turn|>"]),
    ]
}
