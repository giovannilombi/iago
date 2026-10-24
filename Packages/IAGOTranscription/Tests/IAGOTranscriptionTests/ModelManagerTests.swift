import Foundation
import Testing

@testable import IAGOTranscription

/// Local copies used by the integration test; absent on CI, where it is skipped.
let localWhisper = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("../../../../Models/ggml-large-v3-turbo.bin").standardizedFileURL
let localFluidAudio = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("FluidAudio/Models")
let modelsAvailable =
    FileManager.default.fileExists(atPath: localWhisper.path)
    && FileManager.default.fileExists(atPath: localFluidAudio.appendingPathComponent("speaker-diarization").path)

@Suite struct ModelManagerTests {
    func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("iago-models-\(UUID().uuidString)")
    }

    @Test func treeHashDependsOnNamesAndContents() throws {
        let a = temporaryRoot()
        try FileManager.default.createDirectory(at: a.appendingPathComponent("sub"), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: a.appendingPathComponent("sub/one"))
        try Data("y".utf8).write(to: a.appendingPathComponent("two"))
        try Data("ignored".utf8).write(to: a.appendingPathComponent(".revision"))
        let first = try ModelManager.treeHash(a)
        try Data("changed".utf8).write(to: a.appendingPathComponent(".revision"))
        #expect(try ModelManager.treeHash(a) == first)
        try Data("z".utf8).write(to: a.appendingPathComponent("two"))
        #expect(try ModelManager.treeHash(a) != first)
    }

    @Test func installRejectsWrongFiles() throws {
        let manager = ModelManager(root: temporaryRoot())
        let bogus = temporaryRoot()
        try Data("not a model".utf8).write(to: bogus)
        #expect(throws: ModelManager.ModelError.self) { try manager.installLocal(.whisperTurbo, from: bogus) }
        #expect(manager.missing().count == 3)
    }

    @Test(.enabled(if: modelsAvailable), .timeLimit(.minutes(5)))
    func installedModelsLoadOfflineAndStayIntact() async throws {
        let manager = ModelManager(root: temporaryRoot())
        try manager.installLocal(.vad, from: localFluidAudio.appendingPathComponent("silero-vad"))
        try manager.installLocal(.diarizer, from: localFluidAudio.appendingPathComponent("speaker-diarization"))
        try FileManager.default.createDirectory(at: manager.root, withIntermediateDirectories: true)
        // Linked, not copied: 1.6 GB. The hash is still checked through the link.
        try FileManager.default.createSymbolicLink(at: manager.url(of: .whisperTurbo), withDestinationURL: localWhisper)
        #expect(manager.missing().isEmpty)

        _ = try await manager.loadPipeline()

        // Loading must not modify the pinned folders (their hash is checked at every launch).
        #expect(try ModelManager.treeHash(manager.url(of: .vad)) == ModelSpec.vad.sha256)
        #expect(try ModelManager.treeHash(manager.url(of: .diarizer)) == ModelSpec.diarizer.sha256)
    }
}

@Suite struct ParakeetModelTests {
    @Test(
        .enabled(
            if: FileManager.default.fileExists(
                atPath: localFluidAudio.appendingPathComponent("parakeet-tdt-0.6b-v3").path)),
        .timeLimit(.minutes(10)))
    func parakeetLoadsOfflineFromIAGOFolder() async throws {
        let manager = ModelManager(
            root: FileManager.default.temporaryDirectory.appendingPathComponent("iago-pk-\(UUID().uuidString)"))
        try manager.installLocal(.parakeet, from: localFluidAudio.appendingPathComponent("parakeet-tdt-0.6b-v3"))
        try manager.installLocal(.vad, from: localFluidAudio.appendingPathComponent("silero-vad"))
        try manager.installLocal(.diarizer, from: localFluidAudio.appendingPathComponent("speaker-diarization"))
        let pipeline = try await manager.loadPipeline(engine: .parakeet)
        #expect(pipeline.engine.asrName == "parakeet")
        #expect(try ModelManager.treeHash(manager.url(of: .parakeet)) == ModelSpec.parakeet.sha256)
    }
}
