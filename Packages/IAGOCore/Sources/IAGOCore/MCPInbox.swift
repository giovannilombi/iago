import Foundation

/// Files the MCP server cannot import itself (audio, video, Teams transcripts need the app's conversion and
/// transcription): copied with a request into the app's inbox, which imports them like a drop (ADR-0047, amended
/// 2026-10-20). Plain files under IAGO's own folder; nothing else reads them.
public enum MCPInbox {
    public struct Request: Codable, Sendable, Equatable {
        public var projectID: String
        public var streamID: String?
        public var title: String?
        public var relatedItemIDs: [String]

        public init(projectID: String, streamID: String?, title: String?, relatedItemIDs: [String]) {
            self.projectID = projectID
            self.streamID = streamID
            self.title = title
            self.relatedItemIDs = relatedItemIDs
        }
    }

    public static let requestName = "request.json"

    public static func hand(_ file: URL, request: Request, to inbox: URL) throws {
        let folder = inbox.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: file, to: folder.appendingPathComponent(file.lastPathComponent))
        // The request last: the app takes a folder only once it is complete.
        try JSONEncoder().encode(request).write(to: folder.appendingPathComponent(requestName), options: .atomic)
    }

    /// Complete entries: the file and its request.
    public static func pending(in inbox: URL) -> [(folder: URL, file: URL, request: Request)] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)) ?? []
        return folders.compactMap { folder in
            guard let data = try? Data(contentsOf: folder.appendingPathComponent(requestName)),
                let request = try? JSONDecoder().decode(Request.self, from: data),
                let file = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))?
                    .first(where: { $0.lastPathComponent != requestName })
            else { return nil }
            return (folder, file, request)
        }
    }
}
