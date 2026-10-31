import Foundation

/// ADR-0066: the names of the structure example of 1.0–1.2.9 (one client, two projects, two streams). New archives get
/// the example projects of `ExampleArchive` instead; the names stay for the archives that still have them.
public enum StarterExample {
    public static let doneKey = "starter_example_done"
    public static let clientName = "Cliente Test"
    public static let projectNames = ["Pj. Test 1", "Pj. Test 2"]
}

extension Archive {
    /// Creates the example projects once, when the archive has never had them and is still empty (no client, project
    /// or item), in the app's language.
    public func createStarterExampleIfNew(language: String) throws -> ExampleArchive.Created? {
        guard try setting(StarterExample.doneKey) == nil else { return nil }
        try setSetting(StarterExample.doneKey, "1")
        guard try clients(includeArchived: true).isEmpty, try projects(includeArchived: true).isEmpty,
            try items().isEmpty
        else {
            return nil
        }
        return try createExample(language: language)
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
