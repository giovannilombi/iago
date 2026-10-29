import Foundation

/// ADR-0066: a new, empty archive starts with a neutral example of the structure (one client, two projects, two
/// streams), so the sidebar shows how work is organised. Created once; deleting it is the user's choice.
public struct StarterExample: Sendable {
    public static let doneKey = "starter_example_done"
    public static let clientName = "Cliente Test"
    public static let projectNames = ["Pj. Test 1", "Pj. Test 2"]
    public static let streamNames = ["Pj1 - Stream 1", "Pj1 - Stream 2"]

    public let clientID: String
    public let projectIDs: [String]
    public let streamIDs: [String]
}

extension Archive {
    /// Creates the example when the archive has never had it and is still empty (no client, project or item);
    /// "Pj. Test 2" is pinned here, the first stream is pinned by the caller (a sidebar setting).
    public func createStarterExampleIfNew() throws -> StarterExample? {
        guard try setting(StarterExample.doneKey) == nil else { return nil }
        try setSetting(StarterExample.doneKey, "1")
        guard try clients(includeArchived: true).isEmpty, try projects(includeArchived: true).isEmpty,
            try items().isEmpty
        else {
            return nil
        }
        let client = try createClient(name: StarterExample.clientName)
        var projects: [String] = []
        for name in StarterExample.projectNames {
            let project = try createProject(name: name)
            try setProjectClient(project.id, client.id)
            projects.append(project.id)
        }
        let streams = try StarterExample.streamNames.map { try createStream(projectID: projects[0], name: $0).id }
        try setProjectPinned(projects[1], true)
        return StarterExample(clientID: client.id, projectIDs: projects, streamIDs: streams)
    }
}

// MARK: - Default names in the app's language (ADR-0077)

extension Archive {
    static let defaultsLanguageKey = "defaults_language"

    /// The names IAGO gives by itself, per language: the starter example and the built-in categories whose names
    /// are Italian. Names already English (Kickoff, Workshop…) are the same in both.
    static let defaultNames: [[String: String]] = [
        ["it": StarterExample.clientName, "en": "Test Client"],
        ["it": "Pj. Test 1", "en": "Test Pj. 1"],
        ["it": "Pj. Test 2", "en": "Test Pj. 2"],
        ["it": "SAL", "en": "Progress review"],
        ["it": "Interna", "en": "Internal"],
        ["it": "Altro", "en": "Other"],
    ]

    /// When the app's language changes, the starter example and the built-in categories still carrying IAGO's name
    /// in the other language take the name in the new one; anything the user renamed is left alone.
    public func relabelDefaults(to language: String) throws {
        let previous = try setting(Self.defaultsLanguageKey) ?? "it"
        guard previous != language else { return }
        let renames = Self.defaultNames.compactMap { names -> (from: String, to: String)? in
            guard let from = names[previous], let to = names[language], from != to else { return nil }
            return (from, to)
        }
        func target(_ name: String) -> String? { renames.first { $0.from == name }?.to }
        for client in try clients(includeArchived: true) {
            if let name = target(client.name) { try updateClient(client.id) { $0.name = name } }
        }
        for project in try projects(includeArchived: true) {
            if let name = target(project.name) { try renameProject(project.id, to: name) }
        }
        for category in try categories(includeArchived: true) where category.isBuiltin {
            if let name = target(category.name) { try updateCategory(category.id) { $0.name = name } }
        }
        try setSetting(Self.defaultsLanguageKey, language)
    }
}
