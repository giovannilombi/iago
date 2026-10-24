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
