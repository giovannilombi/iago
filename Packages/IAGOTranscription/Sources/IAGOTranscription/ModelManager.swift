import CryptoKit
import FluidAudio
import Foundation

/// A model IAGO can download (spec 7.5): fixed source, pinned SHA-256, known size.
public struct ModelSpec: Sendable, Identifiable, Equatable {
    public enum Source: Sendable, Equatable {
        /// A single file downloaded from a fixed URL.
        case file(URL)
        /// A FluidAudio model folder (pinned revision), fetched by FluidAudio itself.
        case fluidAudio
    }

    public var id: String
    public var displayName: String
    public var source: Source
    /// Path under the models root.
    public var relativePath: String
    /// SHA-256 of the file, or of the folder tree (see `ModelManager.treeHash`).
    public var sha256: String
    public var approximateBytes: Int64

    /// Models needed for the default transcription (ADR-0023): whisper turbo, VAD and diarization.
    public static let required: [ModelSpec] = [whisperTurbo, vad, diarizer]

    /// Models needed by an engine (Parakeet is the optional "fast" engine).
    public static func required(for engine: Engine) -> [ModelSpec] {
        switch engine {
        case .whisper: [whisperTurbo, vad, diarizer]
        case .parakeet: [parakeet, vad, diarizer]
        }
    }

    public enum Engine: String, Sendable, CaseIterable {
        case whisper, parakeet
    }

    public static let all: [ModelSpec] = [whisperTurbo, parakeet, vad, diarizer]

    public static let parakeet = ModelSpec(
        id: "parakeet-tdt-0.6b-v3", displayName: "Parakeet v3 (veloce)", source: .fluidAudio,
        relativePath: "FluidAudio/Models/parakeet-tdt-0.6b-v3",
        sha256: "032ae8cd619950a9bbd88015953ca27d54ec93f0573ac861b0c244c3b03d6f34", approximateBytes: 483_257_242)

    public static let whisperTurbo = ModelSpec(
        id: "whisper-large-v3-turbo", displayName: "Whisper large-v3-turbo",
        source: .file(
            URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")!),
        relativePath: "ggml-large-v3-turbo.bin",
        sha256: "1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69", approximateBytes: 1_624_555_275)

    public static let vad = ModelSpec(
        id: "silero-vad", displayName: "Silero VAD", source: .fluidAudio,
        relativePath: "FluidAudio/Models/silero-vad",
        sha256: "afbdfee41b442f9764db2980e842789c98a22ffbe8a2cbde9346b5e36002baf1", approximateBytes: 1_063_427)

    public static let diarizer = ModelSpec(
        id: "speaker-diarization", displayName: "Diarizzazione (pyannote community-1)", source: .fluidAudio,
        relativePath: "FluidAudio/Models/speaker-diarization",
        sha256: "94e171fd88406ba786232eb86860767185a57b47d89bda6dc8dd8b914563dafb", approximateBytes: 21_786_966)
}

/// Downloads, verifies and loads the models (spec 5.2, 7.5). Network access happens only in
/// `download`, called on an explicit user action; every access is reported to `onNetworkAccess` for the
/// audit log. FluidAudio is kept offline at all other times.
public final class ModelManager: Sendable {
    public let root: URL
    private let verified = VerifiedSet()

    public enum ModelError: Error, Sendable, CustomStringConvertible {
        case missing([String])
        case checksumMismatch(String)

        public var description: String {
            switch self {
            case .missing(let names): "Missing models: \(names.joined(separator: ", "))"
            case .checksumMismatch(let name): "Checksum mismatch for \(name)"
            }
        }
    }

    public init(root: URL) {
        self.root = root
        FluidAudioServices.setDownloadsAllowed(false)
    }

    public func url(of spec: ModelSpec) -> URL { root.appendingPathComponent(spec.relativePath) }
    var fluidAudioBase: URL { root.appendingPathComponent("FluidAudio", isDirectory: true) }

    public func isPresent(_ spec: ModelSpec) -> Bool { FileManager.default.fileExists(atPath: url(of: spec).path) }

    public func missing(_ specs: [ModelSpec] = ModelSpec.required) -> [ModelSpec] { specs.filter { !isPresent($0) } }

    /// Checks the SHA-256 (cached for the session: hashing whisper takes a few seconds).
    public func verify(_ spec: ModelSpec) throws {
        if verified.contains(spec.id) { return }
        guard isPresent(spec) else { throw ModelError.missing([spec.displayName]) }
        let hash = spec.source == .fluidAudio ? try Self.treeHash(url(of: spec)) : try Self.fileHash(url(of: spec))
        guard hash == spec.sha256 else { throw ModelError.checksumMismatch(spec.displayName) }
        verified.insert(spec.id)
    }

    /// Copies a model from a local file or folder (e.g. a previous download) after checking its hash.
    public func installLocal(_ spec: ModelSpec, from source: URL) throws {
        let hash = spec.source == .fluidAudio ? try Self.treeHash(source) : try Self.fileHash(source)
        guard hash == spec.sha256 else { throw ModelError.checksumMismatch(spec.displayName) }
        let destination = url(of: spec)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        try verify(spec)
    }

    /// Downloads a model from its fixed source and verifies it. `progress` receives 0…1.
    public func download(
        _ spec: ModelSpec, progress: @escaping @Sendable (Double) -> Void,
        onNetworkAccess: @Sendable (String) -> Void
    ) async throws {
        switch spec.source {
        case .file(let remote):
            onNetworkAccess("GET \(remote.absoluteString)")
            let destination = url(of: spec)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            let session = URLSession(configuration: configuration)
            defer { session.finishTasksAndInvalidate() }
            let (temporary, response) = try await session.download(from: remote, delegate: DownloadProgress(progress))
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            guard try Self.fileHash(temporary) == spec.sha256 else {
                try? FileManager.default.removeItem(at: temporary)
                throw ModelError.checksumMismatch(spec.displayName)
            }
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporary, to: destination)
        case .fluidAudio:
            onNetworkAccess("FluidAudio model \(spec.id) from huggingface.co (pinned revision)")
            FluidAudioServices.setDownloadsAllowed(true)
            defer { FluidAudioServices.setDownloadsAllowed(false) }
            progress(0)
            if spec.id == ModelSpec.vad.id {
                _ = try await FluidAudioServices.VoiceActivityDetector.load(from: fluidAudioBase)
            } else if spec.id == ModelSpec.parakeet.id {
                _ = try await ParakeetEngine.load(directory: url(of: spec))
            } else {
                _ = try await FluidAudioServices.Diarizer.load(from: fluidAudioBase)
            }
        }
        progress(1)
        verified.remove(spec.id)
        do {
            try verify(spec)
        } catch {
            try? FileManager.default.removeItem(at: url(of: spec))
            throw error
        }
    }

    /// Loads the pipeline for `engine` (whisper by default, ADR-0023), offline, after verifying the models.
    public func loadPipeline(engine kind: ModelSpec.Engine = .whisper) async throws -> TranscriptionPipeline {
        let specs = ModelSpec.required(for: kind)
        let missing = missing(specs)
        guard missing.isEmpty else { throw ModelError.missing(missing.map(\.displayName)) }
        for spec in specs { try verify(spec) }
        FluidAudioServices.setDownloadsAllowed(false)
        let engine: any TranscriptionEngine =
            switch kind {
            case .whisper: try WhisperCppEngine(modelURL: url(of: .whisperTurbo))
            case .parakeet: try await ParakeetEngine.load(directory: url(of: .parakeet))
            }
        let vad = try await FluidAudioServices.VoiceActivityDetector.load(from: fluidAudioBase)
        let diarizer = try await FluidAudioServices.Diarizer.load(from: fluidAudioBase)
        return TranscriptionPipeline(engine: engine, vad: vad, diarizer: diarizer)
    }

    /// Deletes a downloaded model (Settings › Spazio).
    public func delete(_ spec: ModelSpec) throws {
        if isPresent(spec) { try FileManager.default.removeItem(at: url(of: spec)) }
        verified.remove(spec.id)
    }

    /// Size on disk of a model file or folder.
    public func diskSize(_ spec: ModelSpec) -> Int64 {
        Self.diskSize(url(of: spec))
    }

    public static func diskSize(_ url: URL) -> Int64 {
        let resolved = url.resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDirectory) else { return 0 }
        if !isDirectory.boolValue {
            return (try? resolved.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        }
        let enumerator = FileManager.default.enumerator(at: resolved, includingPropertiesForKeys: [.fileSizeKey])
        var total: Int64 = 0
        while let file = enumerator?.nextObject() as? URL {
            total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    // MARK: Hashes

    static func fileHash(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 8 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// SHA-256 over the sorted list of `relative path NUL file-sha256 LF` of every regular file in the
    /// folder, hidden files excluded (FluidAudio keeps a revision marker there).
    static func treeHash(_ folder: URL) throws -> String {
        let base = folder.standardizedFileURL.resolvingSymlinksInPath()
        guard
            let enumerator = FileManager.default.enumerator(
                at: base, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        else { throw CocoaError(.fileReadNoSuchFile) }
        var files: [(String, URL)] = []
        for case let url as URL in enumerator
        where (try url.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true {
            let path = url.standardizedFileURL.resolvingSymlinksInPath().path
            files.append((String(path.dropFirst(base.path.count + 1)), url))
        }
        var hasher = SHA256()
        for (relative, url) in files.sorted(by: { $0.0 < $1.0 }) {
            hasher.update(data: Data("\(relative)\u{0}\(try fileHash(url))\n".utf8))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

private final class VerifiedSet: @unchecked Sendable {
    private let lock = NSLock()
    private var ids: Set<String> = []
    func contains(_ id: String) -> Bool { lock.withLock { ids.contains(id) } }
    func insert(_ id: String) { lock.withLock { _ = ids.insert(id) } }
    func remove(_ id: String) { lock.withLock { _ = ids.remove(id) } }
}

private final class DownloadProgress: NSObject, URLSessionDownloadDelegate, Sendable {
    let report: @Sendable (Double) -> Void

    init(_ report: @escaping @Sendable (Double) -> Void) { self.report = report }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        report(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    }
}
