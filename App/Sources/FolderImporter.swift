import CryptoKit
import Foundation
import IAGOCore
import IAGOIngest
import IAGOStore
import Observation
import os

/// Watched folders of emails (ADR-0050): `.eml`/`.emlx` files saved there (e.g. by a Power Automate rule into a
/// OneDrive folder) are imported in bulk, by delta, through the user's rules. Local files only, no network.
@MainActor
@Observable
final class FolderImporter {
    private let archiveService: ArchiveService
    private let notifier: Notifier
    private let logger = Logger(subsystem: "com.giovannilombi.iago", category: "import")
    @ObservationIgnored private var sources: [DispatchSourceFileSystemObject] = []
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var inboxLoop: Task<Void, Never>?
    @ObservationIgnored private var pending = false

    /// A scan in progress.
    private(set) var scanning = false
    /// The outcome of the last scan with something new, for Settings.
    private(set) var lastSummary: String?
    /// Bumped after every scan, so the lists reload.
    private(set) var revision = 0

    static let builtInKey = "import.builtin"
    static let importedFolder = "Importate"
    static let extensions: Set<String> = ["eml", "emlx"]

    private var archive: Archive { archiveService.archive }

    init(archiveService: ArchiveService, notifier: Notifier) {
        self.archiveService = archiveService
        self.notifier = notifier
    }

    // MARK: Settings

    var builtIn: BuiltInExclusions {
        get {
            (try? archive.setting(Self.builtInKey)).flatMap { $0 }
                .flatMap { try? JSONDecoder().decode(BuiltInExclusions.self, from: Data($0.utf8)) } ?? .init()
        }
        set {
            let json = (try? JSONEncoder().encode(newValue)).map { String(decoding: $0, as: UTF8.self) }
            try? archive.setSetting(Self.builtInKey, json)
            revision += 1
        }
    }

    var rules: [ImportRule] {
        get {
            ((try? archive.importRules()) ?? []).compactMap {
                try? JSONDecoder().decode(ImportRule.self, from: Data($0.json.utf8))
            }
        }
        set {
            let stored = newValue.compactMap { rule -> (id: String, json: String)? in
                guard let data = try? JSONEncoder().encode(rule) else { return nil }
                return (rule.id, String(decoding: data, as: UTF8.self))
            }
            try? archive.setImportRules(stored)
            revision += 1
        }
    }

    var folders: [WatchedFolder] {
        _ = revision
        return (try? archive.watchedFolders()) ?? []
    }

    func add(_ url: URL) {
        try? archive.addWatchedFolder(path: url.standardizedFileURL.path)
        restart()
    }

    func remove(_ folder: WatchedFolder) {
        try? archive.removeWatchedFolder(folder.id)
        restart()
    }

    func update(_ folder: WatchedFolder, _ change: @escaping @Sendable (inout WatchedFolder) -> Void) {
        try? archive.updateWatchedFolder(folder.id, change)
        restart()
    }

    // MARK: Watching

    func start() {
        restart()
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.scanAll()
                // OneDrive does not always signal new files: look every minute anyway.
                try? await Task.sleep(for: .seconds(60))
            }
        }
        inboxLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.importFromClaude()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    /// Files Claude handed over (audio, video, Teams transcripts): imported like a drop, then filed in the project
    /// Claude chose and marked as written through Claude (ADR-0047).
    private func importFromClaude() async {
        let inbox = archiveService.paths.root.appendingPathComponent("tmp/mcp-inbox", isDirectory: true)
        for entry in MCPInbox.pending(in: inbox) {
            let results = await archiveService.importFiles([entry.file])
            for (_, result) in results {
                guard case .success(let item) = result else { continue }
                let request = entry.request
                try? archive.updateItem(item.id) {
                    $0.projectId = request.projectID
                    $0.source = .mcp
                    if let title = request.title, !title.isEmpty { $0.title = title }
                }
                if let stream = request.streamID { try? archive.setStreams([stream], itemID: item.id) }
                for other in request.relatedItemIDs {
                    try? archive.addLink(from: item.id, to: other, kind: .related, origin: .mcp)
                }
                try? archive.recordMCPChange(.item, id: item.id, action: .create)
                notifier.post(
                    title: String(localized: "File da Claude importato"),
                    body: String(localized: "«\(item.title)» è in IAGO."))
            }
            try? FileManager.default.removeItem(at: entry.folder)
        }
    }

    /// Watches the enabled folders for changes; a change starts a scan a few seconds later.
    private func restart() {
        for source in sources { source.cancel() }
        sources = []
        for folder in folders where folder.enabled {
            let descriptor = open(folder.path, O_EVTONLY)
            guard descriptor >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor, eventMask: [.write, .rename, .extend], queue: .main)
            source.setEventHandler { [weak self] in
                Task { @MainActor in self?.scanSoon() }
            }
            source.setCancelHandler { close(descriptor) }
            source.resume()
            sources.append(source)
        }
        revision += 1
    }

    private func scanSoon() {
        guard !pending else { return }
        pending = true
        Task {
            try? await Task.sleep(for: .seconds(5))
            pending = false
            await scanAll()
        }
    }

    /// "Controlla ora", and every change or minute.
    func scanAll() async {
        guard !scanning else { return }
        scanning = true
        defer {
            scanning = false
            revision += 1
        }
        var imported = 0
        var excluded = 0
        var duplicates = 0
        var failed = 0
        let rules = self.rules
        let builtIn = self.builtIn
        for folder in folders where folder.enabled {
            for url in files(in: URL(fileURLWithPath: folder.path)) {
                switch await handle(url, folder: folder, rules: rules, builtIn: builtIn, force: false) {
                case .imported?: imported += 1
                case .excluded?: excluded += 1
                case .duplicate?: duplicates += 1
                case .failed?: failed += 1
                case nil: break
                }
            }
            try? archive.updateWatchedFolder(folder.id) { $0.lastScanAt = Date() }
        }
        guard imported + excluded + duplicates + failed > 0 else { return }
        var parts: [String] = []
        if excluded > 0 { parts.append(String(localized: "\(excluded) scartate")) }
        if duplicates > 0 { parts.append(String(localized: "\(duplicates) doppioni")) }
        if failed > 0 { parts.append(String(localized: "\(failed) non riuscite")) }
        let summary =
            String(localized: "Importate \(imported) email")
            + (parts.isEmpty ? "" : " (\(parts.joined(separator: ", ")))")
        lastSummary = summary + " · " + Date().formatted(date: .omitted, time: .shortened)
        if imported > 0 || failed > 0 {
            notifier.post(title: String(localized: "Email dalle cartelle sorvegliate"), body: summary)
        }
        logger.notice("Watched folders: \(imported) imported, \(excluded) excluded, \(duplicates) duplicates")
    }

    /// `.eml`/`.emlx` files, subfolders included, the "Importate" subfolder excluded.
    private func files(in root: URL) -> [URL] {
        guard
            let enumerator = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants])
        else { return [] }
        var result: [URL] = []
        for case let url as URL in enumerator {
            if url.lastPathComponent == Self.importedFolder, url.deletingLastPathComponent() == root {
                enumerator.skipDescendants()
                continue
            }
            if Self.extensions.contains(url.pathExtension.lowercased()) { result.append(url) }
        }
        return result.sorted { $0.path < $1.path }
    }

    /// One file through the delta register and the rules; nil when it was seen before and has not changed.
    @discardableResult
    func handle(
        _ url: URL, folder: WatchedFolder, rules: [ImportRule], builtIn: BuiltInExclusions, force: Bool
    ) async -> WatchedFile.Outcome? {
        let path = url.standardizedFileURL.path
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
            let size = values.fileSize, let modified = values.contentModificationDate
        else { return nil }
        // A file still being written (OneDrive syncing) waits for the next scan.
        guard Date().timeIntervalSince(modified) > 5 || force else { return nil }
        let known = try? archive.watchedFile(path)
        if !force, let known, known.size == Int64(size), abs(known.modifiedAt.timeIntervalSince(modified)) < 1 {
            return nil
        }
        var record = WatchedFile(
            path: path, folderId: folder.id, size: Int64(size), modifiedAt: modified, sha256: "", outcome: .failed)
        do {
            record.sha256 = try Self.sha256(url)
            if !force, try archive.watchedContentSeen(sha256: record.sha256, except: path) {
                record.outcome = .duplicate
                try archive.recordWatchedFile(record)
                return .duplicate
            }
            var draft = try archiveService.readEmail(url)
            record.subject = draft.message.subject
            if draft.alreadyImported, !force {
                record.outcome = .duplicate
                try archive.recordWatchedFile(record)
                return .duplicate
            }
            let verdict = force ? .none : ImportRules.evaluate(draft.message, rules: rules, builtIn: builtIn)
            switch verdict {
            case .exclude(let reason):
                record.outcome = .excluded
                record.reason = reason
                try archive.recordWatchedFile(record)
                return .excluded
            case .assign(let projectID, let streamID):
                draft.projectID = projectID
                draft.streamIDs = streamID.map { [$0] } ?? []
            case .none:
                // In bulk only a sure proposal files the email; otherwise it waits in "Da classificare".
                if draft.classification?.confident != true {
                    draft.projectID = nil
                    draft.streamIDs = []
                }
            }
            let item = try await archiveService.importEmail(draft)
            record.outcome = .imported
            record.itemId = item.id
            record.reason = nil
            try archive.recordWatchedFile(record)
            if folder.moveImported { moveToImported(url, folder: folder) }
            return .imported
        } catch {
            record.outcome = .failed
            record.reason = ErrorText.describe(error)
            try? archive.recordWatchedFile(record)
            return .failed
        }
    }

    /// "Importa comunque" from the list of discarded files: no rules, no duplicate check by content.
    func importAnyway(_ file: WatchedFile) async {
        guard let folder = folders.first(where: { $0.id == file.folderId }) else { return }
        await handle(
            URL(fileURLWithPath: file.path), folder: folder, rules: [],
            builtIn: .init(meetings: false, autoReplies: false), force: true)
        revision += 1
    }

    private func moveToImported(_ url: URL, folder: WatchedFolder) {
        let target = URL(fileURLWithPath: folder.path).appendingPathComponent(Self.importedFolder, isDirectory: true)
        try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        var destination = target.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            destination = target.appendingPathComponent("\(UUID().uuidString.prefix(8))-\(url.lastPathComponent)")
        }
        do {
            try FileManager.default.moveItem(at: url, to: destination)
            try archive.moveWatchedFile(from: url.standardizedFileURL.path, to: destination.standardizedFileURL.path)
        } catch {
            logger.error("Moving an imported email failed")
        }
    }

    static func sha256(_ url: URL) throws -> String {
        SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
    }
}
