import AppKit
import IAGOStore
import SwiftUI

/// «Copia per Claude» (ADR-0071): the item's reference and a ready request, to paste in Claude. Claude opens exactly
/// this item through MCP, instead of searching for it and maybe picking the wrong one. Before copying, IAGO checks
/// that Claude can read (and write) the project, and offers to allow it.
enum ClaudeRequest: CaseIterable {
    case summary, suggestions, reference

    var title: String {
        switch self {
        case .summary: String(localized: "Per la sintesi")
        case .suggestions: String(localized: "Per le proposte (decisioni, attività, tag)")
        case .reference: String(localized: "Solo il riferimento")
        }
    }

    var needsWriting: Bool { self != .reference }

    /// What is copied: the reference IAGO's MCP tools understand, and the request.
    func text(for item: Item, projectName: String?) -> String {
        let kind =
            switch item.type {
            case .call: String(localized: "call")
            case .email: String(localized: "email")
            case .document: String(localized: "documento")
            }
        let date = item.occurredAt.formatted(date: .long, time: .shortened)
        var lines = [
            String(localized: "Elemento di IAGO: «\(item.title)», \(kind) del \(date)")
                + (projectName.map { String(localized: ", progetto \($0)") } ?? ""),
            "item_id: \(item.id)",
        ]
        switch self {
        case .summary:
            lines.append(
                String(
                    localized:
                        "Fai la sintesi di questo elemento con IAGO: summary_template, get_item (e get_screenshots se ci sono schermate), poi set_summary."
                ))
        case .suggestions:
            lines.append(
                String(
                    localized:
                        "Leggi questo elemento con get_item e proponi in IAGO decisioni, attività e tag con propose_suggestions, ciascuna con la citazione esatta."
                ))
        case .reference: break
        }
        return lines.joined(separator: "\n")
    }
}

struct CopyForClaudeLink: View {
    let model: AppModel
    let item: Item
    @State private var choosing = false
    @State private var blocked: ClaudeRequest?
    @State private var copied = false

    private var project: Project? { item.projectId.flatMap { id in model.projects.first { $0.id == id } } }

    var body: some View {
        ActionLink(
            title: copied ? String(localized: "Copiato: incollalo in Claude") : String(localized: "Copia per Claude…"),
            detail: String(localized: "Riferimento e richiesta pronti: Claude lavora proprio su questo elemento")
        ) { choosing = true }
        .confirmationDialog(
            String(localized: "Cosa chiedere a Claude?"), isPresented: $choosing, titleVisibility: .visible
        ) {
            ForEach(ClaudeRequest.allCases, id: \.self) { request in
                Button(request.title) { copy(request) }
            }
        } message: {
            Text(String(localized: "IAGO copia il riferimento all'elemento e la richiesta: incollali in Claude."))
        }
        .alert(
            String(localized: "Claude non può ancora lavorare su questo elemento"), isPresented: present($blocked),
            presenting: blocked
        ) { request in
            if let project {
                Button(
                    request.needsWriting
                        ? String(localized: "Consenti lettura e scrittura e copia")
                        : String(localized: "Consenti la lettura e copia")
                ) {
                    model.perform {
                        try model.archive.setProjectClaudeAccessible(project.id, true)
                        if request.needsWriting { try model.archive.setProjectClaudeWritable(project.id, true) }
                    }
                    ClaudeConnection.provisionServerKey(archive: model.archive)
                    model.reload()
                    put(request)
                }
            }
            Button(String(localized: "Annulla"), role: .cancel) {}
        } message: { request in
            Text(reason(request))
        }
    }

    private func reason(_ request: ClaudeRequest) -> String {
        guard let project else {
            return String(
                localized:
                    "L'elemento non è in un progetto: assegnalo a un progetto, oppure collega Claude con la connessione che include gli elementi da classificare (Impostazioni › Claude). Claude scrive solo nei progetti."
            )
        }
        if !project.claudeAccessible {
            return String(localized: "Il progetto «\(project.name)» non è consultabile da Claude.")
        }
        return String(
            localized:
                "Claude può leggere «\(project.name)» ma non scriverci: per salvare la sintesi o le proposte deve poter scrivere nel progetto."
        )
    }

    private func copy(_ request: ClaudeRequest) {
        let readable = project?.claudeAccessible == true
        let writable = project?.claudeWritable == true
        guard readable, !request.needsWriting || writable else {
            blocked = request
            return
        }
        put(request)
    }

    private func put(_ request: ClaudeRequest) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(request.text(for: item, projectName: project?.name), forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(4))
            copied = false
        }
    }

    private func present<T>(_ value: Binding<T?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }
}
