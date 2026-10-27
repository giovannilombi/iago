import Foundation

/// A tool the server exposes: name, description for Claude and JSON Schema of its arguments.
public struct ToolDefinition: Sendable {
    public var name: String
    public var description: String
    public var inputSchema: JSON
    /// Shown by clients instead of the name.
    public var title: String?
    /// Standard MCP hints (ADR-0047): nil for a tool without them.
    public var readOnly: Bool?

    public init(name: String, description: String, inputSchema: JSON, title: String? = nil, readOnly: Bool? = nil) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.title = title
        self.readOnly = readOnly
    }

    var json: JSON {
        var object: [String: JSON] = [
            "name": .string(name), "description": .string(description), "inputSchema": inputSchema,
        ]
        if let title { object["title"] = .string(title) }
        if let readOnly {
            // Writes only add or change what the user asked for, and every one can be undone in IAGO.
            var hints: [String: JSON] = ["readOnlyHint": .bool(readOnly), "openWorldHint": .bool(false)]
            if let title { hints["title"] = .string(title) }
            if !readOnly {
                hints["destructiveHint"] = .bool(false)
                hints["idempotentHint"] = .bool(false)
            }
            object["annotations"] = .object(hints)
        }
        return .object(object)
    }
}

/// What the server serves: the tools and how to run them. A thrown `ToolError` becomes a tool error that Claude
/// reads; any other error is reported without details.
public protocol ToolProvider: Sendable {
    var instructions: String { get }
    var tools: [ToolDefinition] { get }
    func call(_ name: String, arguments: JSON) throws -> String
    /// The result as MCP content blocks: text, and images where a tool returns them (ADR-0072).
    func content(_ name: String, arguments: JSON) throws -> [JSON]
    /// The client introduced itself in `initialize` (e.g. "Claude Desktop", ADR-0070).
    func connected(client: String)
}

extension ToolProvider {
    public func content(_ name: String, arguments: JSON) throws -> [JSON] {
        [["type": "text", "text": .string(try call(name, arguments: arguments))]]
    }

    public func connected(client: String) {}
}

public struct ToolError: Error, Sendable, CustomStringConvertible {
    public var message: String
    public init(_ message: String) { self.message = message }
    public var description: String { message }
}

/// The MCP protocol over stdio (ADR-0043): JSON-RPC 2.0, one message per line. Only the server side of
/// `initialize`, `ping`, `tools/list` and `tools/call`; no network, no other capability.
public struct MCPServer: Sendable {
    public static let supportedVersions = ["2024-11-05", "2025-03-26", "2025-06-18", "2025-11-25"]
    let provider: any ToolProvider
    let version: String

    public init(provider: any ToolProvider, version: String) {
        self.provider = provider
        self.version = version
    }

    /// Handles one line; nil when nothing has to be answered (notifications).
    public func handle(line: String) -> String? {
        guard let data = line.data(using: .utf8), let message = try? JSONDecoder().decode(JSON.self, from: data)
        else { return Self.encode(Self.error(id: .null, code: -32700, message: "Parse error")) }
        if let batch = message.array {
            let replies = batch.compactMap { respond(to: $0) }
            return replies.isEmpty ? nil : Self.encode(.array(replies))
        }
        return respond(to: message).map(Self.encode)
    }

    func respond(to message: JSON) -> JSON? {
        guard let method = message["method"]?.string else {
            // A response from the client (we never send requests): ignore.
            return message["id"] == nil ? Self.error(id: .null, code: -32600, message: "Invalid request") : nil
        }
        guard let id = message["id"] else { return nil }  // notification, e.g. notifications/initialized
        let params = message["params"] ?? .object([:])
        switch method {
        case "initialize":
            if let client = params["clientInfo"]?["title"]?.string ?? params["clientInfo"]?["name"]?.string {
                provider.connected(client: client)
            }
            let requested = params["protocolVersion"]?.string ?? ""
            let agreed = Self.supportedVersions.contains(requested) ? requested : Self.supportedVersions.last!
            return Self.result(
                id: id,
                [
                    "protocolVersion": .string(agreed),
                    "capabilities": ["tools": ["listChanged": false]],
                    "serverInfo": ["name": "iago", "title": "IAGO", "version": .string(version)],
                    "instructions": .string(provider.instructions),
                ])
        case "ping":
            return Self.result(id: id, .object([:]))
        case "tools/list":
            return Self.result(id: id, ["tools": .array(provider.tools.map(\.json))])
        case "tools/call":
            guard let name = params["name"]?.string else {
                return Self.error(id: id, code: -32602, message: "Missing tool name")
            }
            guard provider.tools.contains(where: { $0.name == name }) else {
                return Self.error(id: id, code: -32602, message: "Unknown tool: \(name)")
            }
            var content: [JSON]
            var isError = false
            do {
                content = try provider.content(name, arguments: params["arguments"] ?? .object([:]))
            } catch let error as ToolError {
                content = [["type": "text", "text": .string(error.message)]]
                isError = true
            } catch {
                content = [
                    ["type": "text", "text": .string("IAGO non è riuscito a leggere l'archivio (\(type(of: error))).")]
                ]
                isError = true
            }
            return Self.result(id: id, ["content": .array(content), "isError": .bool(isError)])
        default:
            return Self.error(id: id, code: -32601, message: "Method not found: \(method)")
        }
    }

    /// Reads requests from `input` until it closes, writing each answer as one line on `output`.
    public func run(input: FileHandle = .standardInput, output: FileHandle = .standardOutput) {
        var buffer = Data()
        while true {
            let chunk = input.availableData
            if chunk.isEmpty { break }
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer[buffer.startIndex..<newline]
                buffer.removeSubrange(buffer.startIndex...newline)
                guard let line = String(data: lineData, encoding: .utf8),
                    !line.trimmingCharacters(in: .whitespaces).isEmpty
                else { continue }
                if let reply = handle(line: line) { output.write(Data((reply + "\n").utf8)) }
            }
        }
    }

    static func result(id: JSON, _ result: JSON) -> JSON {
        ["jsonrpc": "2.0", "id": id, "result": result]
    }

    static func error(id: JSON, code: Int, message: String) -> JSON {
        ["jsonrpc": "2.0", "id": id, "error": ["code": .number(Double(code)), "message": .string(message)]]
    }

    static func encode(_ json: JSON) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return (try? String(decoding: encoder.encode(json), as: UTF8.self)) ?? "{}"
    }
}
