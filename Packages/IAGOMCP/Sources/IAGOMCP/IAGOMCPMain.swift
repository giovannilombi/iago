import CryptoKit
import Foundation
import IAGOStore

/// The `iago-mcp` executable (ADR-0043): started by Claude Desktop or Claude Code over stdio, reads the archive of
/// the user who runs it, only the projects marked "Consultabile da Claude". No network. Shared by the package's
/// executable and the tool target bundled inside IAGO.app.
public enum IAGOMCPMain {
    /// The server's own copy of the master key (ADR-0043, option chosen by the user): created by the server itself,
    /// so macOS lets it read it without asking. A server started by Claude Desktop cannot show the keychain prompt.
    static let ownKey = KeychainMasterKeyStore(service: "com.giovannilombi.iago.mcp", account: "master-key-copy")

    public static func run() {
        // `--provision`: IAGO hands over the master key on stdin (base64) at launch.
        if CommandLine.arguments.contains("--provision") {
            let input = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
            guard let data = Data(base64Encoded: input.trimmingCharacters(in: .whitespacesAndNewlines)),
                data.count == 32
            else { exit(2) }
            do {
                let current = try ownKey.existingKey()?.withUnsafeBytes { Data($0) }
                if current != data { try ownKey.store(SymmetricKey(data: data)) }
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("iago-mcp: provision failed (\(type(of: error)))\n".utf8))
                exit(1)
            }
        }

        let root =
            ProcessInfo.processInfo.environment["IAGO_ROOT"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/IAGO", isDirectory: true)
        let databaseURL = root.appendingPathComponent("iago.sqlite")
        // `--project ID` or `--client ID`: a connection limited to one project or client.
        let arguments = CommandLine.arguments
        var restriction: IAGOTools.Restriction?
        if let index = arguments.firstIndex(of: "--project"), index + 1 < arguments.count {
            restriction = .project(arguments[index + 1])
        } else if let index = arguments.firstIndex(of: "--client"), index + 1 < arguments.count {
            restriction = .client(arguments[index + 1])
        } else if arguments.contains("--unclassified") {
            restriction = .includingUnclassified
        }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"

        let provider: any ToolProvider
        if !FileManager.default.fileExists(atPath: databaseURL.path) {
            provider = UnavailableTools(
                reason: "l'archivio di IAGO non esiste su questo Mac (apri IAGO almeno una volta).")
        } else {
            do {
                let database = try AppDatabase.openReadOnly(at: databaseURL)
                // Own copy first (no prompt); the app's item only if IAGO has not handed it over yet.
                // Never creates a key: without one the archive simply cannot be read.
                guard let key = try ownKey.existingKey() ?? KeychainMasterKeyStore().existingKey() else {
                    throw KeyStoreError.corruptKey
                }
                let keyStore = EphemeralMasterKeyStore(key: key)
                let archive = try Archive(
                    database: database, itemsRoot: root.appendingPathComponent("Items", isDirectory: true),
                    keyStore: keyStore, readOnly: true)
                let writer = LazyWriter(
                    databaseURL: databaseURL, itemsRoot: root.appendingPathComponent("Items"), keyStore: keyStore)
                provider = IAGOTools(
                    archive: archive, restriction: restriction,
                    inbox: root.appendingPathComponent("tmp/mcp-inbox", isDirectory: true), openWriter: writer.open
                ) {
                    action, detail in
                    do {
                        try Archive.appendAudit(databaseAt: databaseURL, .mcp, action: action, detail: detail)
                    } catch {
                        FileHandle.standardError.write(Data("iago-mcp: audit not written (\(type(of: error)))\n".utf8))
                    }
                }
            } catch {
                provider = UnavailableTools(
                    reason:
                        "non riesco ad aprire l'archivio o la chiave nel Portachiavi. Apri IAGO almeno una volta: "
                        + "all'avvio passa la chiave al collegamento. Poi riprova (\(error)).")
            }
        }

        MCPServer(provider: provider, version: version).run()
    }
}

/// When the archive cannot be opened every tool answers with the reason, so Claude can tell the user.
struct UnavailableTools: ToolProvider {
    let reason: String
    var instructions: String { "IAGO non è disponibile: \(reason)" }
    var tools: [ToolDefinition] {
        [
            ToolDefinition(
                name: "list_projects", description: "Elenca i progetti di IAGO consultabili.",
                inputSchema: ["type": "object", "properties": .object([:])])
        ]
    }
    func call(_ name: String, arguments: JSON) throws -> String { throw ToolError(reason) }
}

/// The write connection (ADR-0044), opened on the first write tool call and then kept.
final class LazyWriter: @unchecked Sendable {
    let databaseURL: URL
    let itemsRoot: URL
    let keyStore: any MasterKeyStore
    private let lock = NSLock()
    private var archive: Archive?

    init(databaseURL: URL, itemsRoot: URL, keyStore: any MasterKeyStore) {
        self.databaseURL = databaseURL
        self.itemsRoot = itemsRoot
        self.keyStore = keyStore
    }

    func open() throws -> Archive {
        lock.lock()
        defer { lock.unlock() }
        if let archive { return archive }
        let opened = try Archive(
            database: try AppDatabase.openWithoutMigrating(at: databaseURL), itemsRoot: itemsRoot,
            keyStore: keyStore)
        archive = opened
        return opened
    }
}
