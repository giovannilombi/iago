import Foundation
import IAGOCore
import IAGOStore
import Testing

@testable import IAGOMCP

struct EchoTools: ToolProvider {
    var instructions: String { "test" }
    var tools: [ToolDefinition] {
        [ToolDefinition(name: "echo", description: "", inputSchema: ["type": "object"])]
    }
    func call(_ name: String, arguments: JSON) throws -> String {
        guard let text = arguments["text"]?.string else { throw ToolError("manca text") }
        return text
    }
}

func decode(_ line: String?) throws -> JSON {
    try JSONDecoder().decode(JSON.self, from: Data(try #require(line).utf8))
}

@Suite struct ProtocolTests {
    let server = MCPServer(provider: EchoTools(), version: "1.0")

    @Test func initializeAgreesOnTheProtocolVersion() throws {
        let reply = try decode(
            server.handle(
                line: #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}"#))
        #expect(reply["id"] == 1)
        #expect(reply["result"]?["protocolVersion"]?.string == "2025-06-18")
        #expect(reply["result"]?["capabilities"]?["tools"] != nil)
        let unknown = try decode(
            server.handle(
                line: #"{"jsonrpc":"2.0","id":2,"method":"initialize","params":{"protocolVersion":"1999-01-01"}}"#))
        #expect(unknown["result"]?["protocolVersion"]?.string == MCPServer.supportedVersions.last)
    }

    @Test func notificationsGetNoReplyAndUnknownMethodsAnError() throws {
        #expect(server.handle(line: #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#) == nil)
        let reply = try decode(server.handle(line: #"{"jsonrpc":"2.0","id":"a","method":"resources/list"}"#))
        #expect(reply["error"]?["code"] == -32601)
        let parse = try decode(server.handle(line: "not json"))
        #expect(parse["error"]?["code"] == -32700)
    }

    @Test func toolsAreListedAndCalled() throws {
        let list = try decode(server.handle(line: #"{"jsonrpc":"2.0","id":3,"method":"tools/list"}"#))
        #expect(list["result"]?["tools"]?.array?.first?["name"]?.string == "echo")
        let call = try decode(
            server.handle(
                line:
                    #"{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"echo","arguments":{"text":"ciao"}}}"#
            ))
        #expect(call["result"]?["content"]?.array?.first?["text"]?.string == "ciao")
        #expect(call["result"]?["isError"] == false)
        let failing = try decode(
            server.handle(line: #"{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"echo"}}"#))
        #expect(failing["result"]?["isError"] == true)
        #expect(failing["result"]?["content"]?.array?.first?["text"]?.string == "manca text")
    }
}

@Suite struct IAGOToolsTests {
    let utc = TimeZone(identifier: "UTC")!

    /// An archive on disk (the app's side) and the same archive opened read-only (the server's side).
    struct Fixture {
        let root: URL
        let databaseURL: URL
        let app: Archive
        let key = EphemeralMasterKeyStore()

        init() throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("iago-mcp-\(UUID().uuidString)")
            databaseURL = root.appendingPathComponent("iago.sqlite")
            app = try Archive(
                database: try AppDatabase.open(at: databaseURL), itemsRoot: root.appendingPathComponent("Items"),
                keyStore: key)
        }

        func server() throws -> Archive {
            try Archive(
                database: try AppDatabase.openReadOnly(at: databaseURL),
                itemsRoot: root.appendingPathComponent("Items"), keyStore: key, readOnly: true)
        }
    }

    final class AuditLog: @unchecked Sendable {
        var rows: [(String, String)] = []
    }

    /// Preview, then confirm with the code it gives (ADR-0047).
    func write(_ tools: IAGOTools, _ name: String, arguments: JSON) throws -> String {
        let preview = try tools.call(name, arguments: arguments)
        #expect(preview.hasPrefix("ANTEPRIMA"))
        let code = try #require(preview.firstMatch(of: /confirmation="([^"]+)"/)?.1)
        guard case .object(var object) = arguments else { throw ToolError("arguments") }
        object["confirmation"] = .string(String(code))
        return try tools.call(name, arguments: .object(object))
    }

    func makeCall(_ archive: Archive, title: String, text: String, project: Project) throws -> Item {
        let call = try archive.createItem(
            title: title, occurredAt: Date(timeIntervalSince1970: 1_791_000_000), source: .recording,
            status: .transcribed, durationSec: 60)
        let transcript = Transcript(
            itemId: call.id, engine: .init(asr: "whisper.cpp", model: "turbo"), language: "it",
            speakers: [.me(), .init(id: "s1", label: "Speaker 1", source: .system)],
            segments: [.init(id: 1, speaker: "s1", start: 75, end: 80, text: text)])
        try archive.storeAsset(
            transcript.encoded(), itemID: call.id, kind: .transcriptJSON, fileName: "transcript.json")
        try archive.setSpeakers([("s1", "Mario Rossi")], for: call.id)
        try archive.updateItem(call.id) { $0.projectId = project.id }
        try archive.indexTranscript(transcript, itemID: call.id)
        return call
    }

    @Test func onlyAccessibleProjectsAreVisibleAndEveryCallIsAudited() throws {
        let fixture = try Fixture()
        let app = fixture.app
        let open = try app.createProject(name: "Portale")
        let closed = try app.createProject(name: "Segreto")
        try app.setProjectClaudeAccessible(open.id, true)
        let visible = try makeCall(app, title: "Kickoff", text: "Il budget è di dodicimila euro", project: open)
        let hidden = try makeCall(app, title: "Riservata", text: "Il budget segreto è altro", project: closed)
        try app.createDecision(
            Decision(
                text: "Budget confermato", decidedAt: visible.occurredAt, projectId: open.id,
                sourceItemId: visible.id, sourceAtSec: 75, origin: .selection))

        let log = AuditLog()
        let databaseURL = fixture.databaseURL
        let tools = IAGOTools(archive: try fixture.server(), timeZone: utc) { action, detail in
            log.rows.append((action, detail))
            try? Archive.appendAudit(databaseAt: databaseURL, .mcp, action: action, detail: detail)
        }

        let projects = try tools.call("list_projects", arguments: [:])
        #expect(projects.contains("Portale") && !projects.contains("Segreto"))

        let results = try tools.call("search", arguments: ["query": "budget"])
        #expect(results.contains(visible.id) && !results.contains(hidden.id))
        #expect(results.contains("@ 00:01:15"))

        let item = try tools.call("get_item", arguments: ["item_id": .string(visible.id)])
        #expect(item.contains("Mario Rossi") && item.contains("dodicimila"))
        #expect(item.contains("Budget confermato"))
        #expect(throws: ToolError.self) { try tools.call("get_item", arguments: ["item_id": .string(hidden.id)]) }
        #expect(throws: ToolError.self) { try tools.call("project_timeline", arguments: ["project": "Segreto"]) }

        let decisions = try tools.call("list_decisions", arguments: ["project": "portale", "status": "active"])
        #expect(decisions.contains("[Attiva]") && decisions.contains("Kickoff @ 00:01:15"))

        // Audit: tool, parameters and returned IDs, never the content; written by the server's own connection.
        #expect(log.rows.map(\.0) == ["list_projects", "search", "get_item", "list_decisions"])
        #expect(log.rows[1].1.contains("query=budget") && log.rows[1].1.contains(visible.id))
        #expect(!log.rows.contains { $0.1.contains("dodicimila") })
        let audited = try app.auditEntries().filter { $0.actor == "mcp" }
        #expect(audited.count == 4)
    }

    @Test func connectionLimitedToOneProjectOrClient() throws {
        let fixture = try Fixture()
        let app = fixture.app
        let client = try app.createClient(name: "Poldo")
        let first = try app.createProject(name: "Portale")
        let second = try app.createProject(name: "App")
        let other = try app.createProject(name: "Altro")
        for project in [first, second, other] { try app.setProjectClaudeAccessible(project.id, true) }
        try app.setProjectClient(first.id, client.id)
        try app.setProjectClient(second.id, client.id)
        let call = try makeCall(app, title: "Kickoff", text: "Il budget è approvato", project: first)
        _ = try makeCall(app, title: "Altra", text: "Il budget è altrove", project: other)

        let single = IAGOTools(archive: try fixture.server(), restriction: .project(first.id), timeZone: utc) { _, _ in
        }
        #expect(single.instructions.contains("limitata al progetto «Portale»"))
        // The only project is implied: no need to name it.
        #expect(try single.call("project_timeline", arguments: [:]).contains(call.id))
        let results = try single.call("search", arguments: ["query": "budget"])
        #expect(results.contains("Kickoff") && !results.contains("Altra"))
        #expect(throws: ToolError.self) { try single.call("list_decisions", arguments: ["project": "Altro"]) }

        let byClient = IAGOTools(archive: try fixture.server(), restriction: .client(client.id), timeZone: utc) {
            _, _ in
        }
        let projects = try byClient.call("list_projects", arguments: [:])
        #expect(projects.contains("Portale") && projects.contains("App") && !projects.contains("Altro"))
        #expect(throws: ToolError.self) { try byClient.call("project_timeline", arguments: [:]) }
    }

    @Test func unclassifiedItemsOnlyWhenTheConnectionIncludesThem() throws {
        let fixture = try Fixture()
        let app = fixture.app
        let project = try app.createProject(name: "Portale")
        try app.setProjectClaudeAccessible(project.id, true)
        let loose = try makeCall(app, title: "Senza casa", text: "Parliamo del preventivo", project: project)
        try app.updateItem(loose.id) { $0.projectId = nil }
        try app.indexTranscript(
            Transcript(
                itemId: loose.id, engine: .init(asr: "whisper.cpp", model: "turbo"), language: "it",
                speakers: [.me()], segments: [.init(id: 1, speaker: "me", start: 3, end: 5, text: "Il preventivo")]),
            itemID: loose.id)

        let normal = IAGOTools(archive: try fixture.server(), timeZone: utc) { _, _ in }
        #expect(!(try normal.call("search", arguments: ["query": "preventivo"])).contains(loose.id))
        #expect(throws: ToolError.self) { try normal.call("get_item", arguments: ["item_id": .string(loose.id)]) }

        let wide = IAGOTools(archive: try fixture.server(), restriction: .includingUnclassified, timeZone: utc) {
            _, _ in
        }
        #expect(try wide.call("list_projects", arguments: [:]).contains("Da classificare"))
        #expect(try wide.call("search", arguments: ["query": "preventivo"]).contains(loose.id))
        #expect(try wide.call("project_timeline", arguments: ["project": "Da classificare"]).contains(loose.id))
        #expect(try wide.call("get_item", arguments: ["item_id": .string(loose.id)]).contains("Senza casa"))
    }

    /// ADR-0071, ADR-0072: Claude finds a recent item, writes its summary and proposals (checked and undoable), and
    /// sees the screenshots only when the user shares them.
    @Test func claudeSummarizesAndProposesInsteadOfTheEngine() throws {
        let fixture = try Fixture()
        let app = fixture.app
        let project = try app.createProject(name: "Portale")
        try app.setProjectClaudeAccessible(project.id, true)
        try app.setProjectClaudeWritable(project.id, true)
        let call = try makeCall(
            app, title: "SAL portale", text: "Il rilascio slitta al 15 novembre per il ritardo dei testi.",
            project: project)
        let png = try #require(
            Data(
                base64Encoded:
                    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
            ))
        try app.addScreenshot(itemID: call.id, png: png, atSec: 90, text: "Roadmap\nRilascio a novembre")
        let databaseURL = fixture.databaseURL
        let key = fixture.key
        let itemsRoot = fixture.root.appendingPathComponent("Items")
        let tools = IAGOTools(
            archive: try fixture.server(), timeZone: utc,
            clock: { Date(timeIntervalSince1970: 1_791_100_000) },
            openWriter: {
                try Archive(
                    database: try AppDatabase.openWithoutMigrating(at: databaseURL), itemsRoot: itemsRoot,
                    keyStore: key)
            }
        ) { _, _ in }
        let server = MCPServer(provider: tools, version: "1.0")
        _ = server.handle(
            line:
                #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","clientInfo":{"name":"claude-ai","title":"Claude Desktop","version":"1"}}}"#
        )

        let recent = try tools.call("recent_items", arguments: ["days": 7])
        #expect(recent.contains("«SAL portale»") && recent.contains(call.id) && recent.contains("senza sintesi"))
        #expect(try tools.call("summary_template", arguments: ["item_id": .string(call.id)]).contains("Sezioni"))
        #expect(try tools.call("get_item", arguments: ["item_id": .string(call.id)]).contains("[00:01:30] Roadmap"))

        // The summary: one point verified, one dropped; written as Claude's, undoable.
        let summary = try write(
            tools, "set_summary",
            arguments: [
                "item_id": .string(call.id), "brief": "Il rilascio slitta.",
                "sections": [
                    [
                        "title": "punti salienti",
                        "points": [
                            ["text": "Rilascio spostato al 15 novembre", "quote": "Il rilascio slitta al 15 novembre"],
                            ["text": "Budget raddoppiato", "quote": "il budget raddoppia"],
                            ["text": "Roadmap mostrata", "screenshot_at": "01:30"],
                        ],
                    ]
                ],
            ])
        #expect(summary.contains("2 punti verificati"))
        let saved = try #require(try app.summary(itemID: call.id))
        #expect(saved.origin == .claude && saved.model == "Claude Desktop")
        #expect(saved.markdown.contains("Rilascio spostato al 15 novembre [01:15](iago://seek/75)"))
        #expect(saved.markdown.contains("Roadmap mostrata (dalla schermata) [01:30](iago://seek/90)"))
        #expect(!saved.markdown.contains("Budget"))

        // Proposals: they wait for the user, and do not replace the engine's.
        try app.replacePendingSuggestions(
            itemID: call.id, model: "qwen3.5-4b", [(.tag, SuggestionPayload(text: "portale", isNew: true))])
        _ = try write(
            tools, "propose_suggestions",
            arguments: [
                "item_id": .string(call.id),
                "items": [
                    [
                        "kind": "decision", "text": "Rilascio al 15 novembre",
                        "quote": "Il rilascio slitta al 15 novembre",
                    ],
                    ["kind": "tag", "text": "rilascio"],
                ],
            ])
        let pending = try app.suggestions(itemID: call.id)
        #expect(pending.count == 3)
        #expect(
            pending.filter { $0.origin == .claude }.map(\.kind).sorted { $0.rawValue < $1.rawValue } == [
                .decision, .tag,
            ])

        // Screenshots: only their text until the user shares the images.
        #expect(throws: ToolError.self) {
            try tools.content("get_screenshots", arguments: ["item_id": .string(call.id)])
        }
        try app.setSetting(IAGOTools.shareScreenshotsKey, "1")
        let content = try tools.content("get_screenshots", arguments: ["item_id": .string(call.id)])
        #expect(content.contains { $0["type"]?.string == "image" && $0["mimeType"]?.string == "image/jpeg" })

        // Undo from Settings › Claude: the summary and Claude's proposals go away, the engine's stay.
        for change in try app.mcpChanges() { try app.undoMCPChange(try #require(change.id)) }
        #expect(try app.summary(itemID: call.id) == nil)
        #expect(try app.suggestions(itemID: call.id).map(\.origin) == [.engine])
    }

    /// ADR-0074: Claude proposes the open work kinds, with owner, deadline, "waiting on", severity and the open entry
    /// a proposal closes; quotes are checked as before, wrong links and unclear deadlines are reported and dropped.
    @Test func claudeProposesOpenWork() throws {
        let fixture = try Fixture()
        let app = fixture.app
        let project = try app.createProject(name: "Portale")
        try app.setProjectClaudeAccessible(project.id, true)
        try app.setProjectClaudeWritable(project.id, true)
        // Saturday 3 October 2026.
        let call = try makeCall(
            app, title: "SAL portale",
            text:
                "Anna ci manda i file definitivi entro venerdì. Usiamo Azure AD per il login. Se il fornitore ritarda salta la consegna. Chi gestisce gli accessi esterni?",
            project: project)
        let question = try app.createDecision(
            Decision(
                text: "Quale provider per il login?", decidedAt: Date(timeIntervalSince1970: 1_790_000_000),
                projectId: project.id, origin: .manual, kind: .openQuestion))
        let databaseURL = fixture.databaseURL
        let key = fixture.key
        let itemsRoot = fixture.root.appendingPathComponent("Items")
        let tools = IAGOTools(
            archive: try fixture.server(), timeZone: utc,
            openWriter: {
                try Archive(
                    database: try AppDatabase.openWithoutMigrating(at: databaseURL), itemsRoot: itemsRoot,
                    keyStore: key)
            }
        ) { _, _ in }
        #expect(IAGOTools.workGuide.contains("waiting_on") && IAGOTools.workGuide.contains("closes"))
        let schema = try #require(tools.tools.first { $0.name == "propose_suggestions" }).inputSchema
        #expect("\(schema)".contains("question") && "\(schema)".contains("severity"))

        let arguments: JSON = [
            "item_id": .string(call.id),
            "items": [
                [
                    "kind": "decision", "text": "Login con Azure AD", "quote": "Usiamo Azure AD per il login",
                    "closes": .string(question.id),
                ],
                [
                    "kind": "activity", "text": "File definitivi", "quote": "Anna ci manda i file definitivi",
                    "waiting_on": "Anna", "due": "venerdì",
                ],
                [
                    "kind": "risk", "text": "Ritardo del fornitore",
                    "quote": "Se il fornitore ritarda salta la consegna",
                    "severity": "high", "due": "quando capita",
                ],
                [
                    "kind": "question", "text": "Chi gestisce gli accessi esterni?",
                    "quote": "Chi gestisce gli accessi esterni?", "closes": .string(question.id),
                ],
                [
                    "kind": "request", "text": "Accesso con SSO", "quote": "ci serve l'accesso con SSO per tutti",
                ],
            ],
        ]
        let preview = try tools.call("propose_suggestions", arguments: arguments)
        #expect(preview.contains("Decisione: Login con Azure AD · chiude «Quale provider per il login?»"))
        #expect(preview.contains("Attività: File definitivi · attende Anna · entro 2026-10-09"))
        #expect(preview.contains("Rischio: Ritardo del fornitore · gravità alta"))
        #expect(preview.contains("scadenza «quando capita» non chiara"))
        #expect(preview.contains("non può chiudere"))
        #expect(preview.contains("Scartata «Accesso con SSO»: citazione non trovata"))
        _ = try write(tools, "propose_suggestions", arguments: arguments)

        let pending = Dictionary(
            uniqueKeysWithValues: try app.suggestions(itemID: call.id).map { ($0.content.text, $0) })
        #expect(pending.count == 4)
        #expect(pending["Login con Azure AD"]?.content.supersedesID == question.id)
        let files = try #require(pending["File definitivi"])
        #expect(files.kind == .activity && files.content.waitingOn == "Anna" && files.content.due == "2026-10-09")
        let risk = try #require(pending["Ritardo del fornitore"])
        #expect(risk.kind == .risk && risk.content.severity == "high" && risk.content.due == nil)
        let open = try #require(pending["Chi gestisce gli accessi esterni?"])
        #expect(open.kind == .question && open.content.supersedesID == nil && open.content.atSec == 75)
    }

    @Test func writesOnlyWhereAllowedMarkedAndUndoable() throws {
        let fixture = try Fixture()
        let app = fixture.app
        let project = try app.createProject(name: "Portale")
        try app.setProjectClaudeAccessible(project.id, true)
        let call = try makeCall(app, title: "Kickoff", text: "Decidiamo il logo blu", project: project)
        let databaseURL = fixture.databaseURL
        let key = fixture.key
        let itemsRoot = fixture.root.appendingPathComponent("Items")
        let tools = IAGOTools(
            archive: try fixture.server(), timeZone: utc,
            openWriter: {
                try Archive(
                    database: try AppDatabase.openWithoutMigrating(at: databaseURL), itemsRoot: itemsRoot,
                    keyStore: key)
            }
        ) { _, _ in }
        #expect(tools.tools.contains { $0.name == "add_decision" })

        // Readable is not writable.
        #expect(throws: ToolError.self) { try tools.call("add_note", arguments: ["text": "x", "project": "Portale"]) }
        try app.setProjectClaudeWritable(project.id, true)

        let noted = try write(tools, "add_note", arguments: ["text": "Richiamare Mario", "item_id": .string(call.id)])
        #expect(noted.contains("tramite Claude (MCP)"))
        let note = try #require(try app.notes(itemID: call.id).first)
        #expect(note.input == .mcp)

        _ = try write(
            tools, "add_decision",
            arguments: ["text": "Logo blu", "source_item_id": .string(call.id), "at_sec": 75])
        let first = try #require(try app.decisions(sourceItemID: call.id).first)
        #expect(first.decision.origin == .mcp && first.decision.sourceAtSec == 75)
        _ = try write(
            tools, "add_decision", arguments: ["text": "Logo verde", "supersedes_id": .string(first.id)])
        #expect(try app.decision(first.id)?.status == .superseded)

        _ = try write(
            tools, "update_note", arguments: ["note_id": .string(note.id), "text": "Richiamare Mario lunedì"])
        _ = try write(
            tools, "update_decision", arguments: ["decision_id": .string(first.id), "chain_name": "Colore del logo"])
        #expect(try app.mcpProvenance(.note, ids: [note.id]) == [note.id: .create])

        _ = try write(
            tools, "create_document",
            arguments: ["title": "Verbale", "markdown": "Presenti: Mario.", "project": "Portale"])
        _ = try write(
            tools, "add_email",
            arguments: [
                "subject": "Offerta", "body": "In allegato.", "from": "Mario Rossi <mario@poldo.it>",
                "direction": "inbound",
            ])
        let created = try app.summaries(.project(project.id)).map(\.item).filter { $0.source == .mcp }
        #expect(Set(created.map(\.title)) == ["Verbale", "Offerta"])

        // Transcripts cannot be written: there is no tool for them.
        #expect(!tools.tools.contains { $0.name.contains("transcript") })

        // Undo, newest first: the email goes to the trash, the chain name and the note text come back.
        let changes = try app.mcpChanges()
        #expect(changes.count == 7)
        for change in changes { try app.undoMCPChange(try #require(change.id)) }
        #expect(try app.summaries(.project(project.id)).map(\.item).allSatisfy { $0.source != .mcp })
        #expect(try app.notes(itemID: call.id).isEmpty)
        #expect(try app.decisions(sourceItemID: call.id).isEmpty)
        #expect(throws: MCPChangeError.self) { try app.undoMCPChange(try #require(changes.first?.id)) }
    }

    @Test func readOnlyArchiveRefusesWrites() throws {
        let fixture = try Fixture()
        let server = try fixture.server()
        #expect(throws: (any Error).self) { try server.createProject(name: "No") }
    }

    @Test func datesAndUnknownProjectsGiveReadableErrors() throws {
        let fixture = try Fixture()
        let project = try fixture.app.createProject(name: "Portale")
        try fixture.app.setProjectClaudeAccessible(project.id, true)
        let tools = IAGOTools(archive: try fixture.server(), timeZone: utc) { _, _ in }
        #expect(throws: ToolError.self) {
            try tools.call("project_timeline", arguments: ["project": "Portale", "from": "ieri"])
        }
        do {
            _ = try tools.call("list_notes", arguments: ["project": "Altro"])
            Issue.record("expected an error")
        } catch let error as ToolError {
            #expect(error.message.contains("Portale"))
        }
    }

    final class Clock: @unchecked Sendable {
        var now = Date(timeIntervalSince1970: 1_791_100_000)
    }

    /// A writable "Portale" project with two streams and a call, and tools on it with a settable clock.
    func writable(_ fixture: Fixture, clock: Clock) throws -> (IAGOTools, Project, Item) {
        let app = fixture.app
        let project = try app.createProject(name: "Portale")
        try app.setProjectClaudeAccessible(project.id, true)
        try app.setProjectClaudeWritable(project.id, true)
        _ = try app.createStream(projectID: project.id, name: "Design")
        _ = try app.createStream(projectID: project.id, name: "Legale")
        let call = try makeCall(app, title: "Kickoff", text: "Decidiamo il logo blu", project: project)
        let databaseURL = fixture.databaseURL
        let key = fixture.key
        let itemsRoot = fixture.root.appendingPathComponent("Items")
        let tools = IAGOTools(
            archive: try fixture.server(), timeZone: utc, clock: { clock.now }, filesRoot: fixture.root,
            inbox: fixture.root.appendingPathComponent("inbox"),
            openWriter: {
                try Archive(
                    database: try AppDatabase.openWithoutMigrating(at: databaseURL), itemsRoot: itemsRoot,
                    keyStore: key)
            }
        ) { _, _ in }
        return (tools, project, call)
    }

    @Test func previewWritesNothingAndTheCodeIsBoundToTheArguments() throws {
        let fixture = try Fixture()
        let clock = Clock()
        let (tools, project, _) = try writable(fixture, clock: clock)
        let arguments: JSON = ["text": "Palette approvata", "stream": "Design"]
        let preview = try tools.call("add_note", arguments: arguments)
        #expect(preview.contains("ANTEPRIMA") && preview.contains("stream Design"))
        #expect(preview.contains("In cima alla timeline"))
        #expect(try fixture.app.notes(projectID: project.id).isEmpty)
        let code = String(try #require(preview.firstMatch(of: /confirmation="([^"]+)"/)?.1))

        // Changed arguments, a made-up code or an expired one are refused.
        #expect(throws: ToolError.self) {
            try tools.call(
                "add_note", arguments: ["text": "Altro testo", "stream": "Design", "confirmation": .string(code)])
        }
        #expect(throws: ToolError.self) {
            try tools.call(
                "add_note", arguments: ["text": "Palette approvata", "stream": "Design", "confirmation": "x-1"])
        }
        clock.now += 16 * 60
        #expect(throws: ToolError.self) {
            try tools.call(
                "add_note", arguments: ["text": "Palette approvata", "stream": "Design", "confirmation": .string(code)])
        }
        #expect(try fixture.app.notes(projectID: project.id).isEmpty)

        _ = try write(tools, "add_note", arguments: arguments)
        let note = try #require(try fixture.app.notes(projectID: project.id).first)
        #expect(note.notedAt == clock.now)
        let design = try #require(try fixture.app.streams(projectID: project.id).first { $0.name == "Design" })
        #expect(try fixture.app.streamIDs(noteID: note.id) == [design.id])

        // An unknown stream is an error that lists the valid ones.
        do {
            _ = try tools.call("add_note", arguments: ["text": "x", "stream": "Marketing"])
            Issue.record("expected an error")
        } catch let error as ToolError {
            #expect(error.message.contains("Design") && error.message.contains("Legale"))
        }
    }

    @Test func datesDefaultToNowAndDoubtsAreRaised() throws {
        let fixture = try Fixture()
        let clock = Clock()
        let (tools, project, call) = try writable(fixture, clock: clock)
        let app = fixture.app

        // From a call: still now by default; date="source" takes the exact moment.
        _ = try write(
            tools, "add_decision",
            arguments: [
                "text": "Logo blu per il portale", "source_item_id": .string(call.id), "at_sec": 75, "stream": "Design",
            ])
        let first = try #require(try app.decisions(sourceItemID: call.id).first)
        #expect(first.decision.decidedAt == clock.now)
        let sourced = try tools.call(
            "add_decision",
            arguments: ["text": "Font Inter", "source_item_id": .string(call.id), "at_sec": 75, "date": "source"])
        #expect(sourced.contains("quella della fonte, 2026-10-03 04:01"))
        #expect(sourced.contains("sotto"))

        // A similar active decision and missing stream raise doubts; a to-do title too.
        let similar = try tools.call("add_decision", arguments: ["text": "Logo verde per il portale"])
        #expect(similar.contains("simili") && similar.contains(first.id))
        #expect(similar.contains("stream (Design, Legale)"))
        let todo = try tools.call("add_decision", arguments: ["text": "Chiamare Mario per il logo"])
        #expect(todo.contains("attività"))
        let decisionNote = try tools.call("add_note", arguments: ["text": "Abbiamo deciso il logo verde"])
        #expect(decisionNote.contains("sembra una decisione"))

        // Superseding with an older date is flagged; a past date says where it goes.
        let older = try tools.call(
            "add_decision",
            arguments: ["text": "Logo verde", "supersedes_id": .string(first.id), "date": "2026-10-01"])
        #expect(older.contains("precedente") && older.contains("nel passato"))

        // list_decisions finds by topic.
        let found = try tools.call("list_decisions", arguments: ["query": "logo", "project": .string(project.name)])
        #expect(found.contains("Logo blu"))
        #expect(try tools.call("list_decisions", arguments: ["query": "budget"]).contains("Nessun punto chiave"))
    }

    @Test func batchesAndSimilarNotes() throws {
        let fixture = try Fixture()
        let clock = Clock()
        let (tools, project, call) = try writable(fixture, clock: clock)
        let app = fixture.app
        let entries: JSON = [
            "entries": [
                [
                    "tool": "add_decision",
                    "arguments": ["text": "Logo blu", "people": ["Mario"], "tags": ["brand"], "stream": "Design"],
                ],
                [
                    "tool": "add_decision",
                    "arguments": ["text": "Preparare il manuale del marchio", "kind": "activity", "stream": "Design"],
                ],
                [
                    "tool": "add_note",
                    "arguments": ["text": "Mario preferisce toni freddi", "item_id": .string(call.id)],
                ],
            ]
        ]
        let preview = try tools.call("write_batch", arguments: entries)
        #expect(preview.contains("Voce 3") && preview.contains("Persone: Mario") && preview.contains("#brand"))
        #expect(try app.decisions(DecisionQuery(scope: .project(project.id), statuses: [])).isEmpty)
        let written = try write(tools, "write_batch", arguments: entries)
        #expect(written.contains("Voce 1") && written.contains("Voce 3"))
        #expect(try app.decisions(DecisionQuery(scope: .project(project.id), statuses: [])).count == 2)
        #expect(try app.mcpChanges().count == 3)  // each one undoable on its own

        // Only notes and key points; a near-duplicate note is flagged.
        #expect(throws: ToolError.self) {
            try tools.call("write_batch", arguments: ["entries": [["tool": "add_email", "arguments": [:]]]])
        }
        let again = try tools.call(
            "add_note", arguments: ["text": "Mario preferisce i toni freddi", "item_id": .string(call.id)])
        #expect(again.contains("quasi uguali"))
    }

    @Test func localFilesAreImportedWithTheirOriginal() throws {
        let fixture = try Fixture()
        let (tools, project, _) = try writable(fixture, clock: Clock())
        let folder = fixture.root.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("modulo PX7.txt")
        try Data("Conferimento integrale a Fornitore Test".utf8).write(to: file)

        let preview = try tools.call("import_file", arguments: ["path": .string(file.path)])
        #expect(preview.contains("modulo PX7.txt") && preview.contains("estrae il testo"))
        _ = try write(tools, "import_file", arguments: ["path": .string(file.path)])
        let document = try #require(try fixture.app.summaries(.project(project.id)).first { $0.item.type == .document })
        #expect(document.item.title == "modulo PX7" && document.item.source == .mcp)
        #expect(try fixture.app.search("conferimento", scope: .project(project.id)).count == 1)

        // Outside the allowed folder, or missing: refused with a readable reason.
        #expect(throws: ToolError.self) { try tools.call("import_file", arguments: ["path": "/etc/hosts"]) }
        #expect(throws: ToolError.self) {
            try tools.call(
                "import_file", arguments: ["path": .string(folder.appendingPathComponent("nessuno.pdf").path)])
        }

        // find_file finds it by name; an .eml becomes an email; audio goes to the app's inbox.
        #expect(try tools.call("find_file", arguments: ["name": "px7"]).contains("modulo PX7.txt"))
        let eml = folder.appendingPathComponent("adesione.eml")
        try Data(
            "From: Anna <anna@assicura.example>\r\nSubject: Adesione confermata\r\nMessage-ID: <a1@assicura.example>\r\n\r\nOk."
                .utf8
        )
        .write(to: eml)
        _ = try write(tools, "import_file", arguments: ["path": .string(eml.path)])
        #expect(try fixture.app.summaries(.project(project.id)).contains { $0.item.title == "Adesione confermata" })
        let audio = folder.appendingPathComponent("vocale.m4a")
        try Data("audio".utf8).write(to: audio)
        let handed = try write(tools, "import_file", arguments: ["path": .string(audio.path)])
        #expect(handed.contains("passato a IAGO"))
        let pending = MCPInbox.pending(in: fixture.root.appendingPathComponent("inbox"))
        #expect(pending.count == 1 && pending[0].request.projectID == project.id)

        // An email with an attachment: the file becomes a linked document.
        _ = try write(
            tools, "add_email",
            arguments: [
                "subject": "Invio modulistica", "body": "In allegato.", "direction": "outbound",
                "date": "2026-10-20 12:00",
                "attachment_paths": [.string(file.path)],
            ])
        let email = try #require(
            try fixture.app.summaries(.project(project.id)).first {
                $0.item.type == .email && $0.item.title == "Invio modulistica"
            })
        #expect(try fixture.app.links(itemID: email.id).count == 1)
    }

    @Test func reorderingAChainThroughClaudeCanBeUndone() throws {
        let fixture = try Fixture()
        let clock = Clock()
        let (tools, project, _) = try writable(fixture, clock: clock)
        let app = fixture.app
        let decision = try app.createDecision(
            Decision(text: "Verso 1.5%", decidedAt: clock.now, projectId: project.id, origin: .manual))
        let activity = try app.createDecision(
            Decision(
                text: "Decidere quanto versare", decidedAt: clock.now - 3_600, projectId: project.id,
                supersedesId: decision.id, origin: .manual, kind: .action))
        let preview = try tools.call(
            "update_decision", arguments: ["decision_id": .string(decision.id), "supersedes_id": .string(activity.id)])
        #expect(preview.contains("Cambia l'ordine della catena"))
        _ = try write(
            tools, "update_decision",
            arguments: ["decision_id": .string(decision.id), "supersedes_id": .string(activity.id)])
        #expect(try app.decisionChain(of: decision.id).map(\.id) == [activity.id, decision.id])
        #expect(try app.decision(decision.id)?.status == .active)

        try app.undoMCPChange(try #require(try app.mcpChanges().first?.id))
        #expect(try app.decisionChain(of: decision.id).map(\.id) == [decision.id, activity.id])
        #expect(try app.decision(decision.id)?.status == .superseded)
        #expect(try app.decision(activity.id)?.status == .active)
    }

    @Test func oneEntrySupersedesSeveralThroughClaude() throws {
        let fixture = try Fixture()
        let clock = Clock()
        let (tools, project, _) = try writable(fixture, clock: clock)
        let app = fixture.app
        func make(_ text: String, _ kind: Decision.Kind) throws -> Decision {
            try app.createDecision(
                Decision(text: text, decidedAt: clock.now - 3_600, projectId: project.id, origin: .manual, kind: kind))
        }
        let decision = try make("Aderire al fondo", .decision)
        let activity = try make("Firmare il PX7", .action)
        let milestone = try make("Raccolti i moduli", .milestone)
        let ids: JSON = [.string(decision.id), .string(activity.id), .string(milestone.id)]
        let preview = try tools.call(
            "add_decision", arguments: ["text": "Firmato il PX7", "kind": "milestone", "supersedes_ids": ids])
        #expect(preview.contains("Aderire al fondo") && preview.contains("Raccolti i moduli"))
        let reply = try write(
            tools, "add_decision", arguments: ["text": "Firmato il PX7", "kind": "milestone", "supersedes_ids": ids])
        #expect(reply.contains("3 voci precedenti"))
        for id in [decision.id, activity.id, milestone.id] { #expect(try app.decision(id)?.status == .superseded) }

        // Update replaces the list; undo puts it back.
        let done = try #require(try app.decisions(DecisionQuery()).first { $0.decision.text == "Firmato il PX7" })
        _ = try write(
            tools, "update_decision",
            arguments: ["decision_id": .string(done.id), "supersedes_ids": [.string(decision.id)]])
        #expect(try app.decision(activity.id)?.status == .active)
        try app.undoMCPChange(try #require(try app.mcpChanges().first?.id))
        #expect(Set(try app.supersededIDs(of: done.id)) == [decision.id, activity.id, milestone.id])
        #expect(try app.decision(activity.id)?.status == .superseded)
    }

    @Test func toolsAreMarkedReadOnlyOrWriting() throws {
        let fixture = try Fixture()
        let (tools, _, _) = try writable(fixture, clock: Clock())
        let server = MCPServer(provider: tools, version: "1.0")
        let listed = try decode(server.handle(line: #"{"jsonrpc":"2.0","id":1,"method":"tools/list"}"#))
        let all = try #require(listed["result"]?["tools"]?.array)
        func hints(_ name: String) -> JSON? { all.first { $0["name"]?.string == name }?["annotations"] }
        #expect(hints("search")?["readOnlyHint"] == true)
        #expect(hints("add_note")?["readOnlyHint"] == false)
        #expect(hints("add_note")?["destructiveHint"] == false)
        #expect(all.allSatisfy { $0["annotations"]?["openWorldHint"] == false })
        #expect(tools.instructions.contains("due passi"))
    }
}
