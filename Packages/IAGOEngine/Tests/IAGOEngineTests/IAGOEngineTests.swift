import CryptoKit
import Foundation
import Testing

@testable import IAGOEngine

/// Serves files from memory, honouring `Range`, so downloads are tested without the network.
final class StubServer: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var files: [String: Data] = [:]
    nonisolated(unsafe) static var requests: [String] = []
    /// Bytes served before the connection "drops", to test resuming; nil: everything.
    nonisolated(unsafe) static var cutAfter: Int?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        let range = request.value(forHTTPHeaderField: "Range")
        Self.requests.append(url.lastPathComponent + (range.map { " \($0)" } ?? ""))
        guard let data = Self.files[url.lastPathComponent] else {
            client?.urlProtocol(
                self, didReceive: HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!,
                cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        var start = 0
        if let range, let value = Int(range.dropFirst("bytes=".count).dropLast()) { start = value }
        let status = start > 0 ? 206 : 200
        var body = data.subdata(in: start..<data.count)
        let cut = Self.cutAfter
        if let cut, body.count > cut { body = body.prefix(cut) }
        client?.urlProtocol(
            self, didReceive: HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!,
            cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        if cut != nil, body.count < data.count - start {
            // The bytes arrive, then the connection drops, as on a real network.
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
                self.client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost))
            }
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

func sha(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

@Suite(.serialized) struct EngineTests {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("iago-engine-\(UUID().uuidString)")

    func model(_ files: [String: Data], wrong: String? = nil) -> EngineModel {
        EngineModel(
            id: "test", billions: 1, name: "Test 1B", family: "Test", recommendedRAMGB: 8, license: "MIT",
            licenseURL: URL(string: "https://example.invalid")!, repo: "test/model", revision: "abc123",
            files: files.keys.sorted().map {
                EngineFile(
                    path: $0, size: Int64(files[$0]!.count),
                    sha256: $0 == wrong ? String(repeating: "0", count: 64) : sha(files[$0]!))
            }, extraEOSTokens: [])
    }

    func downloader(_ library: EngineLibrary) -> EngineDownloader {
        EngineDownloader(library: library) { delegate in
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [StubServer.self]
            return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        }
    }

    @Test func catalogIsPinnedAndChecked() {
        #expect(Set(EngineCatalog.models.map(\.id)).count == EngineCatalog.models.count)
        #expect(EngineCatalog.embedding.role == .embedding && EngineCatalog.models.allSatisfy { $0.role == .chat })
        #expect(EngineCatalog.model("qwen3-embedding-0.6b") == EngineCatalog.embedding)
        for model in EngineCatalog.models + [EngineCatalog.embedding] {
            #expect(model.revision.count == 40)
            #expect(model.files.allSatisfy { $0.sha256.count == 64 && $0.size > 0 })
            #expect(model.files.contains { $0.path.hasSuffix(".safetensors") })
            #expect(model.files.contains { $0.path == "tokenizer.json" })
            #expect(model.files.contains { $0.path == "config.json" })
            let url = model.url(of: model.files[0]).absoluteString
            #expect(url.hasPrefix("https://huggingface.co/\(model.repo)/resolve/\(model.revision)/"))
        }
    }

    @Test func theSuggestionFollowsTheRAM() {
        #expect(EngineCatalog.recommended(forRAMGB: 8).id == "qwen3.5-4b")
        #expect(EngineCatalog.recommended(forRAMGB: 16).id == "qwen3.5-9b")
        #expect(EngineCatalog.recommended(forRAMGB: 24).id == "qwen3.5-9b")
        #expect(EngineCatalog.recommended(forRAMGB: 36).id == "gemma-4-12b")
    }

    @Test func downloadsVerifiesResumesAndChoosesTheActiveModel() async throws {
        let library = EngineLibrary(root: root)
        let weights = Data((0..<200_000).map { UInt8($0 % 251) })
        let files = ["config.json": Data("{}".utf8), "model.safetensors": weights]
        StubServer.files = files
        StubServer.requests = []
        let model = model(files)
        #expect(library.state(of: model) == .missing)
        #expect(library.activeModel == nil)

        // The connection drops halfway: the partial file stays.
        StubServer.cutAfter = 100_000
        await #expect(throws: (any Error).self) {
            try await downloader(library).download(model, progress: { _ in }, onNetworkAccess: { _ in })
        }
        let part = library.folder(of: model).appendingPathComponent("model.safetensors.part")
        #expect(library.size(part) == 100_000)
        guard case .partial = library.state(of: model) else {
            Issue.record("expected a partial download")
            return
        }

        // The next download resumes with a range and verifies every file.
        StubServer.cutAfter = nil
        StubServer.requests = []
        let accesses = Accesses()
        try await downloader(library).download(model, progress: { _ in }, onNetworkAccess: { accesses.add($0) })
        #expect(StubServer.requests == ["model.safetensors bytes=100000-"], "\(StubServer.requests)")
        #expect(accesses.lines.count == 1 && accesses.lines[0].contains("resolve/abc123/model.safetensors"))
        #expect(library.state(of: model) == .installed)
        #expect(try Data(contentsOf: library.folder(of: model).appendingPathComponent("model.safetensors")) == weights)

        // Not active until the user chooses it; deleting it leaves IAGO without an engine.
        #expect(library.activeModel == nil)
        try library.setActive(model.id)
        #expect(library.activeID == "test")
        try library.delete(model)
        #expect(library.activeID == nil && library.state(of: model) == .missing)
    }

    @Test func aWrongChecksumIsDiscarded() async throws {
        let library = EngineLibrary(root: root)
        let files = ["config.json": Data("{}".utf8), "model.safetensors": Data(repeating: 7, count: 1_000)]
        StubServer.files = files
        StubServer.cutAfter = nil
        let model = model(files, wrong: "model.safetensors")
        await #expect(throws: EngineDownloadError.checksumMismatch("model.safetensors")) {
            try await downloader(library).download(model, progress: { _ in }, onNetworkAccess: { _ in })
        }
        let folder = library.folder(of: model)
        #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("model.safetensors").path))
        #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("model.safetensors.part").path))
        #expect(library.state(of: model) != .installed)
    }
}

final class Accesses: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []
    func add(_ line: String) { lock.withLock { stored.append(line) } }
    var lines: [String] { lock.withLock { stored } }
}
