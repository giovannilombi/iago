import Foundation

/// The models on this Mac and the one in use (ADR-0048). Each model lives in `<root>/<id>/`; a `.verified` file,
/// written after every file passed its SHA-256, holds the revision, so startup does not hash gigabytes again.
/// The active model is in `<root>/active.json`: one at a time, chosen by the user.
public struct EngineLibrary: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public enum State: Sendable, Equatable {
        case missing
        /// Some files are there (an interrupted download): it can be resumed.
        case partial(bytes: Int64)
        case installed
    }

    public func folder(of model: EngineModel) -> URL { root.appendingPathComponent(model.id, isDirectory: true) }

    var markerName: String { ".verified" }

    public func state(of model: EngineModel) -> State {
        let folder = folder(of: model)
        if let revision = try? String(contentsOf: folder.appendingPathComponent(markerName), encoding: .utf8),
            revision == model.revision,
            model.files.allSatisfy({ size(folder.appendingPathComponent($0.path)) == $0.size })
        {
            return .installed
        }
        let bytes = diskSize(of: model)
        return bytes > 0 ? .partial(bytes: bytes) : .missing
    }

    public func isInstalled(_ model: EngineModel) -> Bool { state(of: model) == .installed }

    /// Bytes on disk, partial files included.
    public func diskSize(of model: EngineModel) -> Int64 {
        let folder = folder(of: model)
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey])
        else { return 0 }
        var total: Int64 = 0
        while let file = enumerator.nextObject() as? URL { total += size(file) ?? 0 }
        return total
    }

    func size(_ url: URL) -> Int64? {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
    }

    func markVerified(_ model: EngineModel) throws {
        try Data(model.revision.utf8).write(to: folder(of: model).appendingPathComponent(markerName), options: .atomic)
    }

    /// Deletes a model; if it was in use, no model is active any more.
    public func delete(_ model: EngineModel) throws {
        if FileManager.default.fileExists(atPath: folder(of: model).path) {
            try FileManager.default.removeItem(at: folder(of: model))
        }
        if activeID == model.id { try setActive(nil) }
    }

    // MARK: Active model

    var activeURL: URL { root.appendingPathComponent("active.json") }

    struct Active: Codable { var id: String? }

    /// The id chosen by the user, even if its files are gone (see `activeModel`).
    public var activeID: String? {
        guard let data = try? Data(contentsOf: activeURL) else { return nil }
        return (try? JSONDecoder().decode(Active.self, from: data))?.id
    }

    /// The model in use: chosen by the user, in the catalog and installed. nil: IAGO works without an engine.
    public var activeModel: EngineModel? {
        guard let id = activeID, let model = EngineCatalog.model(id), model.role == .chat, isInstalled(model) else {
            return nil
        }
        return model
    }

    /// The embedding model, when downloaded (ADR-0049): the search by meaning works with or without a chat engine.
    public var embeddingModel: EngineModel? { isInstalled(EngineCatalog.embedding) ? EngineCatalog.embedding : nil }

    public func setActive(_ id: String?) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(Active(id: id)).write(to: activeURL, options: .atomic)
    }
}
