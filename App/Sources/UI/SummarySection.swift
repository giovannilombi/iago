import IAGOEngine
import IAGOIntelligence
import IAGOStore
import SwiftUI

/// "Sintesi" in the item (ADR-0054): always there. Without a summary it says why and offers the category and
/// "Genera sintesi"; while it is written it shows how far; then the summary, with each minute opening the player.
struct SummarySection: View {
    let model: AppModel
    let item: Item
    /// There is a transcript (calls) or a text (emails, documents) to summarize.
    let hasText: Bool
    let seek: (Double) -> Void
    @State private var summary: ItemSummaryText?
    @State private var editing: String?
    @State private var confirmRegenerate = false

    private var intelligence: IntelligenceService { model.intelligence }

    var body: some View {
        SectionBox(String(localized: "Sintesi"), systemImage: "text.alignleft", tint: .indigo, collapseKey: "summary") {
            if let running = intelligence.summarizing, running.itemID == item.id {
                writing(running.fraction)
            } else if intelligence.isSummaryQueued(item.id) {
                Label(String(localized: "In coda: la sintesi parte appena il motore è libero."), systemImage: "clock")
                    .font(.callout).foregroundStyle(.secondary)
            } else if let summary {
                ready(summary)
            } else {
                missing
            }
        }
        .task(id: "\(model.revision)-\(intelligence.revision)-\(item.id)") {
            summary = try? model.archive.summary(itemID: item.id)
        }
        .sheet(isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            MarkdownEditSheet(text: editing ?? "") { text in
                model.perform { try model.archive.editSummary(itemID: item.id, markdown: text) }
                summary = try? model.archive.summary(itemID: item.id)
            }
        }
        .confirmationDialog(
            summary?.origin == .claude && summary?.edited == false
                ? String(localized: "Sostituire la sintesi di Claude?")
                : String(localized: "Sostituire la sintesi modificata a mano?"), isPresented: $confirmRegenerate,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Rigenera")) { intelligence.summarize(item.id) }
        } message: {
            Text(
                summary?.origin == .claude && summary?.edited == false
                    ? String(localized: "Il motore del Mac scriverà una nuova sintesi al posto di quella di Claude.")
                    : String(localized: "Le tue modifiche andranno perse."))
        }
    }

    // MARK: States

    private func writing(_ fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Sto scrivendo la sintesi con il modello «\(templateName ?? "")»…"))
                .font(.callout)
            HStack {
                ProgressView(value: fraction).frame(maxWidth: 320)
                Text("\(Int(fraction * 100))%").font(.caption).monospacedDigit().foregroundStyle(.secondary)
            }
            Text(String(localized: "Puoi continuare a usare IAGO: la trovi anche in Attività."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var missing: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Sintesi non ancora disponibile."))
                .font(.callout.weight(.medium))
            if let failure = intelligence.summaryFailures[item.id] {
                Label(
                    String(localized: "L'ultimo tentativo non è riuscito: \(failure)"),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            if !hasText {
                Text(
                    item.type == .call
                        ? String(localized: "Serve prima la trascrizione della call.")
                        : String(localized: "Serve prima il testo dell'elemento.")
                )
                .font(.caption).foregroundStyle(.secondary)
            }
            Text(
                String(
                    localized:
                        "La sintesi segue il tipo di riunione: scegli la categoria e genera. Con la categoria già scelta, le prossime call la avranno da sole a fine trascrizione."
                )
            )
            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                CategoryPicker(
                    model: model, selection: item.categoryId, noneLabel: String(localized: "Scegli la categoria")
                ) {
                    value in
                    model.update(item.id) { $0.categoryId = value }
                }
                Button(String(localized: "Genera sintesi")) { intelligence.summarize(item.id) }
                    .buttonStyle(.borderedProminent).tint(.indigo)
                    .disabled(!hasText || templateName == nil)
            }
            if model.engine.activeModel != nil, !model.engine.isBigEnough(for: .summary) {
                Label(
                    String(
                        localized:
                            "Le sintesi richiedono almeno Qwen 3.5 9B: il motore attivo è troppo piccolo per riassumere bene. Scegline uno in Impostazioni › Motore."
                    ), systemImage: "cpu"
                )
                .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            if item.categoryId != nil, templateName == nil {
                Text(String(localized: "Questa categoria è impostata su «Nessuna sintesi» (Impostazioni › Categorie)."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func ready(_ summary: ItemSummaryText) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let current = item.categoryId, current != summary.categoryId, let name = templateName {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(.indigo)
                    Text(String(localized: "La categoria è cambiata."))
                    Button(String(localized: "Rigenera con il modello «\(name)»")) { regenerate(summary) }
                        .buttonStyle(.link)
                    Spacer(minLength: 0)
                }
                .font(.callout)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.indigo.opacity(0.08)))
                .help(String(localized: "Non rigenera da solo: scegli tu."))
            }
            MarkdownText(markdown: summary.markdown)
                .environment(
                    \.openURL,
                    OpenURLAction { url in
                        let prefix = SummaryGenerator.seekScheme
                        guard url.absoluteString.hasPrefix(prefix),
                            let seconds = Double(url.absoluteString.dropFirst(prefix.count))
                        else { return .systemAction }
                        seek(seconds)
                        return .handled
                    })
            HStack(spacing: 12) {
                Text(caption(summary)).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Button(String(localized: "Modifica…")) { editing = summary.markdown }
                Button(String(localized: "Rigenera")) { regenerate(summary) }
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(summary.markdown, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help(String(localized: "Copia la sintesi (Markdown)"))
            }
            .buttonStyle(.link).font(.callout)
        }
    }

    // MARK: Helpers

    private var templateName: String? {
        let category = item.categoryId.flatMap { id in model.categories.first { $0.id == id } }
        return IntelligenceService.template(for: category)?.name
    }

    private func regenerate(_ summary: ItemSummaryText) {
        // A summary edited by hand or written by Claude (ADR-0071) is replaced only after asking.
        if summary.edited || summary.origin == .claude {
            confirmRegenerate = true
        } else {
            intelligence.summarize(item.id)
        }
    }

    private func caption(_ summary: ItemSummaryText) -> String {
        let template = SummaryLibrary.template(summary.templateId)?.name
        var parts: [String] = []
        // Who wrote it (ADR-0070): the model of the Mac, or Claude.
        if let provenance = Provenance.summary(summary) { parts.append(provenance) }
        if let template { parts.append(String(localized: "modello «\(template)»")) }
        parts.append(summary.updatedAt.formatted(date: .abbreviated, time: .shortened))
        if summary.edited { parts.append(String(localized: "modificata a mano")) }
        return parts.joined(separator: " · ")
    }
}
