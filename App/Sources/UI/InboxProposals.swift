import IAGOStore
import SwiftUI

/// The box of one item in «Proposte da confermare» (ADR-0087): kind, title, date and project, which proposals it has
/// and how many. A click opens them in the detail pane, where they are confirmed or dismissed.
struct ProposalItemCard: View {
    let item: Item
    let suggestions: [Suggestion]
    let projectName: String?
    let selected: Bool
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: Self.icon(item.type)).font(.system(size: 12)).foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.secondary.opacity(0.15)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.callout.weight(.semibold)).lineLimit(1)
                    Text(meta).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Text(kinds).font(.caption).lineLimit(1)
                }
                Spacer(minLength: 8)
                InboxCountBadge(kind: .proposals, count: suggestions.count)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 11).padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8).strokeBorder(selected ? Color.accentColor.opacity(0.7) : .clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
    }

    private var meta: String {
        [
            ItemDetailView.typeName(item.type), item.occurredAt.formatted(.dateTime.day().month(.abbreviated)),
            projectName,
        ].compactMap { $0 }.joined(separator: " · ")
    }

    /// «Attività 2 · Rischio · Decisione», in the order they come.
    private var kinds: String {
        var order: [String] = []
        var counts: [String: Int] = [:]
        for suggestion in suggestions {
            let label = SuggestionRow.kindLabel(suggestion.kind, suggestion.content)
            if counts[label] == nil { order.append(label) }
            counts[label, default: 0] += 1
        }
        return order.map { label in
            let count = counts[label] ?? 0
            return count > 1 ? "\(label) \(count)" : label
        }
        .joined(separator: " · ")
    }

    static func icon(_ type: Item.Kind) -> String {
        switch type {
        case .call: "phone"
        case .email: "envelope"
        case .document: "doc.text"
        }
    }
}

/// The proposals of one item, opened from its box in «Inbox»: each with its sentence and minute, to confirm, edit or
/// dismiss; all together with «Conferma tutte» and «Scarta queste».
struct ItemProposalsPane: View {
    let model: AppModel
    let itemID: String
    @State private var suggestions: [Suggestion] = []
    @State private var loaded = false

    var body: some View {
        Group {
            if let item = model.item(itemID) {
                VStack(alignment: .leading, spacing: 0) {
                    header(item).padding(.horizontal, 24).padding(.vertical, 14)
                    Rectangle().fill(IAGOColor.divider).frame(height: 1)
                    if suggestions.isEmpty {
                        if loaded { done(item) }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(
                                    model.workMode(for: item.projectId).hasKeyPoints
                                        ? String(
                                            localized:
                                                "Diventano punti chiave solo se le confermi. Il minuto apre la trascrizione in quel punto."
                                        )
                                        : String(localized: "Si applicano solo se le confermi.")
                                )
                                .font(.caption).foregroundStyle(.secondary)
                                ForEach(suggestions) { suggestion in
                                    SuggestionRow(model: model, item: item, suggestion: suggestion)
                                        .padding(.horizontal, 13).padding(.vertical, 11)
                                        .background(RoundedRectangle(cornerRadius: 9).fill(IAGOColor.card))
                                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(IAGOColor.divider))
                                }
                            }
                            .padding(.horizontal, 24).padding(.vertical, 14)
                            .frame(maxWidth: 760, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .task(id: "\(model.revision)-\(model.intelligence.revision)") { load() }
    }

    private func header(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: InboxCount.proposals.systemImage).font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(InboxCount.proposals.textColor)
                    .frame(width: 15, height: 15)
                    .background(RoundedRectangle(cornerRadius: 4).fill(InboxCount.proposals.color))
                Text(verbatim: "\(String(localized: "Proposte da confermare").uppercased()) · \(suggestions.count)")
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(item.title).font(.title2.bold()).lineLimit(2)
                Spacer(minLength: 12)
                Button(String(localized: "Apri l'elemento")) { model.selectedItemID = item.id }
                    .buttonStyle(.link)
            }
            HStack(spacing: 10) {
                Text(meta(item)).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 12)
                if !suggestions.isEmpty {
                    Button(String(localized: "Conferma tutte")) {
                        for suggestion in suggestions { model.accept(suggestion) }
                    }
                    Button(String(localized: "Scarta queste")) { model.dismiss(suggestions) }
                        .buttonStyle(.link).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func done(_ item: Item) -> some View {
        ContentUnavailableView {
            Label(String(localized: "Nessuna proposta da confermare"), systemImage: "checkmark.circle")
        } description: {
            Text(String(localized: "Le proposte di questo elemento sono state confermate o scartate."))
        } actions: {
            Button(String(localized: "Apri l'elemento")) { model.selectedItemID = item.id }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func meta(_ item: Item) -> String {
        let project = model.project(item.projectId)
        return [
            ItemDetailView.typeName(item.type), item.occurredAt.formatted(.dateTime.day().month(.abbreviated)),
            [model.client(project?.clientId)?.name, project?.name].compactMap { $0 }.joined(separator: " › "),
        ].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func load() {
        suggestions = ((try? model.archive.pendingInboxSuggestions()) ?? []).filter { $0.itemId == itemID }
        loaded = true
    }
}
