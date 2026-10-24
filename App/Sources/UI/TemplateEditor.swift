import AppKit
import IAGOIntelligence
import IAGOStore
import SwiftUI
import UniformTypeIdentifiers

/// The summary template of a category (ADR-0054): sections, what the engine must look for, table columns. Saved as
/// the category's own version; "Ripristina l'originale" goes back to the library. Import and export in Meetily's JSON.
struct TemplateEditor: View {
    let model: AppModel
    let category: IAGOStore.Category
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var sections: [EditableSection] = []
    @State private var name = ""
    @State private var description = ""

    struct EditableSection: Identifiable {
        let id = UUID()
        var title: String
        var instruction: String
        var format: SummaryTemplate.Section.Format
        var columns: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "Modello di sintesi di «\(category.name)»")).font(.title3.bold())
            Text(
                String(
                    localized:
                        "Ogni sezione dice al motore cosa cercare nella call. Con le colonne, i punti diventano una tabella (es. Chi, Cosa, Entro). IAGO aggiunge sempre «In breve», data, partecipanti e il minuto di ogni punto."
                )
            )
            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach($sections) { $section in
                        sectionCard($section)
                    }
                    Button {
                        sections.append(.init(title: "", instruction: "", format: .list, columns: ""))
                    } label: {
                        Label(String(localized: "Aggiungi sezione"), systemImage: "plus.circle")
                    }
                    .buttonStyle(.link)
                }
            }
            .frame(minHeight: 360)
            HStack {
                Button(String(localized: "Ripristina l'originale")) {
                    model.perform {
                        try model.archive.setCategoryTemplate(
                            category.id, templateID: category.templateId, customJSON: nil)
                    }
                    onSave()
                    dismiss()
                }
                .disabled(category.templateJson == nil)
                Menu(String(localized: "Altro")) {
                    Button(String(localized: "Esporta (formato Meetily)…"), action: export)
                    Button(String(localized: "Importa un modello…"), action: importFile)
                }
                .fixedSize()
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(String(localized: "Salva")) { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(sections.allSatisfy { $0.title.trimmingCharacters(in: .whitespaces).isEmpty })
            }
        }
        .padding(20)
        .frame(width: 640, height: 620)
        .onAppear(perform: load)
    }

    private func sectionCard(_ section: Binding<EditableSection>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField(String(localized: "Titolo della sezione"), text: section.title)
                    .textFieldStyle(.roundedBorder).font(.headline)
                Picker("", selection: section.format) {
                    Text(String(localized: "Elenco")).tag(SummaryTemplate.Section.Format.list)
                    Text(String(localized: "Paragrafo")).tag(SummaryTemplate.Section.Format.paragraph)
                    Text(String(localized: "Testo breve")).tag(SummaryTemplate.Section.Format.string)
                }
                .labelsHidden().fixedSize()
                Button {
                    move(section.wrappedValue.id, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                Button {
                    move(section.wrappedValue.id, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                Button {
                    sections.removeAll { $0.id == section.wrappedValue.id }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            TextField(
                String(localized: "Cosa cercare (es. «Le decisioni prese e il motivo.»)"), text: section.instruction,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder).lineLimit(1...3)
            TextField(
                String(localized: "Colonne della tabella, separate da virgole (facoltative)"), text: section.columns
            )
            .textFieldStyle(.roundedBorder).font(.callout)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.07)))
    }

    private func load() {
        guard let template = IntelligenceService.template(for: category) else { return }
        apply(template)
    }

    private func apply(_ template: SummaryTemplate) {
        name = template.name
        description = template.description
        sections = template.sections.map {
            .init(
                title: $0.title, instruction: $0.instruction, format: $0.format,
                columns: $0.columns.joined(separator: ", "))
        }
    }

    private var template: SummaryTemplate {
        SummaryTemplate(
            id: category.templateId ?? "", name: name.isEmpty ? category.name : name, description: description,
            basedOn: "",
            sections: sections.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }.map { section in
                let columns = section.columns.split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
                .filter { !$0.isEmpty }
                return .init(
                    section.title.trimmingCharacters(in: .whitespaces),
                    section.instruction.trimmingCharacters(in: .whitespacesAndNewlines),
                    section.format, columns: columns.isEmpty ? nil : columns)
            })
    }

    private func save() {
        let json = template.json()
        model.perform {
            try model.archive.setCategoryTemplate(category.id, templateID: category.templateId, customJSON: json)
        }
        onSave()
        dismiss()
    }

    private func move(_ id: UUID, by offset: Int) {
        guard let index = sections.firstIndex(where: { $0.id == id }), sections.indices.contains(index + offset)
        else { return }
        sections.swapAt(index, index + offset)
    }

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(category.name).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.perform { try Data(template.json().utf8).write(to: url) }
    }

    private func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url,
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return }
        guard let imported = SummaryTemplate.parse(text) else {
            model.lastError = String(localized: "Il file non è un modello di sintesi valido (formato Meetily).")
            return
        }
        apply(imported)
    }
}
