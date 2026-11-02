import IAGOStore
import SwiftUI

/// Vertical timeline (FR-80, brought forward from phase 2 on the user's request): a line with date and
/// time on the left and each item indented by one level, grouped by month, most recent first.
/// Clicking an item opens it in the inspector.
struct ProjectTimeline: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groups, id: \.month) { group in
                        Text(group.month.formatted(.dateTime.month(.wide).year()).capitalized)
                            .font(.title3).bold().padding(.top, 18).padding(.bottom, 6).padding(.leading, 8)
                        ForEach(group.entries) { entry in
                            switch entry {
                            case .item(let summary):
                                TimelineEntry(
                                    model: model, summary: summary, isSelected: model.selectedItemID == summary.id
                                )
                                .id(summary.id)
                                .onTapGesture { model.selectedItemID = summary.id }
                            case .decision(let summary):
                                TimelineDecision(model: model, summary: summary)
                            case .note(let note):
                                TimelineNote(model: model, note: note)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 24)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .overlay {
                if groups.isEmpty {
                    ContentUnavailableView(
                        String(localized: "Nessun elemento in questo progetto"), systemImage: "calendar")
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    ViewModePicker(model: model)
                    if model.shownContent != .keyPoints { FilterBar(model: model) }
                }
                .iagoBar()
            }
        }
    }

    /// The history of «Mostra», grouped by month, most recent first.
    private var groups: [(month: Date, entries: [TimelineRow])] {
        let calendar = Calendar.current
        let rows = TimelineRow.history(model)
        let grouped = Dictionary(grouping: rows) {
            calendar.date(from: calendar.dateComponents([.year, .month], from: $0.date))!
        }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]!) }
    }
}

enum TimelineRow: Identifiable {
    /// Items, key points (FR-154) and notes (FR-175) interleaved by date, most recent first, as «Mostra» wants
    /// (ADR-0075): materials are items and notes. Key points are shown only when no item filter is active, so
    /// filtering by tag or type shows just the matching items.
    @MainActor
    static func history(_ model: AppModel) -> [TimelineRow] {
        let content = model.shownContent
        var rows = content == .keyPoints ? [] : model.summaries.map(TimelineRow.item)
        rows.sort { $0.date > $1.date }
        if content != .materials, !model.filter.isActive || content == .keyPoints {
            // Key points keep their own order (superseded under their successor on the same day) and are
            // merged in by date.
            var merged: [TimelineRow] = []
            var items = rows[...]
            for entry in DecisionOrdering.arrange(model.timelineDecisions) {
                let date =
                    entry.nested
                    ? (merged.last?.date ?? entry.summary.decision.decidedAt) : entry.summary.decision.decidedAt
                while let next = items.first, next.date > date {
                    merged.append(next)
                    items = items.dropFirst()
                }
                merged.append(.decision(entry.summary))
            }
            rows = merged + items
        }
        if content != .keyPoints, !model.filter.isActive, !model.timelineNotes.isEmpty {
            var merged: [TimelineRow] = []
            var notes = model.timelineNotes.sorted { $0.notedAt > $1.notedAt }[...]
            for row in rows {
                while let note = notes.first, note.notedAt > row.date {
                    merged.append(.note(note))
                    notes = notes.dropFirst()
                }
                merged.append(row)
            }
            rows = merged + notes.map(TimelineRow.note)
        }
        return rows
    }

    case item(ItemSummary)
    case decision(DecisionSummary)
    case note(Note)

    var id: String {
        switch self {
        case .item(let summary): "item/\(summary.id)"
        case .decision(let summary): "decision/\(summary.id)"
        case .note(let note): "note/\(note.id)"
        }
    }

    var date: Date {
        switch self {
        case .item(let summary): summary.item.occurredAt
        case .decision(let summary): summary.decision.decidedAt
        case .note(let note): note.notedAt
        }
    }
}

/// A note on the timeline (FR-175): a project note, or a note of an item shown with the item's title.
private struct TimelineNote: View {
    let model: AppModel
    let note: Note
    @State private var deleting = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(note.notedAt.formatted(.dateTime.day().month(.abbreviated)))
                .font(.caption).foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
                .padding(.top, 9)
            ZStack(alignment: .top) {
                Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 2)
                Image(systemName: note.input == .voice ? "mic.circle.fill" : "note.text")
                    .font(.system(size: 13)).foregroundStyle(.yellow)
                    .background(Circle().fill(Color(nsColor: .windowBackgroundColor)).padding(-2))
                    .padding(.top, 8)
            }
            .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(heading).font(.caption).bold().foregroundStyle(.orange)
                    if note.input == .voice {
                        Image(systemName: "mic.fill").font(.caption2).foregroundStyle(.secondary)
                    }
                    ViaClaudeBadge(model: model, entity: .note, id: note.id, compact: true)
                }
                Text(note.body).font(.callout).lineLimit(3).foregroundStyle(.primary)
                if let streams = try? model.archive.streamIDs(noteID: note.id), !streams.isEmpty {
                    StreamDots(model: model, streamIDs: streams)
                }
                if let decisionID = model.promotedDecision(ofNote: note.id) {
                    Button {
                        model.selectedDecisionID = decisionID
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.seal.fill")
                            Text(String(localized: "Diventata decisione"))
                            Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                        }
                        .font(.caption).foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Apri la decisione e la sua evoluzione"))
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.yellow.opacity(0.08)))
            .overlay(
                RoundedRectangle(cornerRadius: 8).stroke(
                    model.selectedNoteID == note.id ? Color.accentColor : Color.yellow.opacity(0.35),
                    lineWidth: model.selectedNoteID == note.id ? 2 : 1)
            )
            .padding(.vertical, 3)
        }
        .contentShape(Rectangle())
        .onTapGesture { model.selectedNoteID = note.id }
        .contextMenu {
            Button(String(localized: "Modifica…")) { model.editingNote = NoteDraft(note) }
            if let decisionID = model.promotedDecision(ofNote: note.id) {
                Button(String(localized: "Apri la decisione")) { model.selectedDecisionID = decisionID }
            } else {
                Button(String(localized: "Promuovi a decisione")) {
                    model.editingDecision = DecisionDraft(note: note, item: model.item(note.itemId ?? ""))
                }
            }
            Divider()
            Button(String(localized: "Elimina…"), role: .destructive) { deleting = true }
        }
        .confirmationDialog(String(localized: "Eliminare la nota?"), isPresented: $deleting) {
            Button(String(localized: "Elimina"), role: .destructive) {
                model.perform { try model.archive.deleteNote(note.id) }
            }
        }
    }

    private var heading: String {
        if let itemID = note.itemId {
            return String(localized: "Nota su «\(model.item(itemID)?.title ?? "")»")
        }
        return String(localized: "Nota di progetto")
    }
}

/// A key point on the timeline: the kind's sign on the line instead of a dot, and a slim card. Closing an entry
/// changes how it looks, it adds no row (ADR-0074): an entry closed by another one of the same day sits under it,
/// otherwise it says "→ chiusa da …".
private struct TimelineDecision: View {
    let model: AppModel
    let summary: DecisionSummary

    var body: some View {
        let decision = summary.decision
        let mode = model.workMode(for: decision.projectId)
        let look = DecisionRow.look(decision, closedBy: summary.supersededBy?.kind)
        HStack(alignment: .top, spacing: 0) {
            Text(decision.decidedAt.formatted(.dateTime.day().month(.abbreviated)))
                .font(.caption).foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
                .padding(.top, 9)
                .opacity(nested ? 0.6 : 1)
            ZStack(alignment: .top) {
                Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 2)
                Group {
                    // In «Traccia» an activity is a box to tick (ADR-0076).
                    if WorkCheckbox.applies(decision, mode: mode) {
                        WorkCheckbox(model: model, decision: decision)
                    } else {
                        Image(systemName: DecisionRow.icon(summary)).foregroundStyle(DecisionRow.color(summary))
                    }
                }
                .font(.system(size: 14))
                .background(Circle().fill(Color(nsColor: .windowBackgroundColor)).padding(-2))
                .padding(.top, 8)
            }
            .frame(width: 30)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if nested {
                    Image(systemName: "arrow.turn.down.right").font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(DecisionRow.kindLabel(decision.kind)).font(.caption).bold().foregroundStyle(.secondary)
                        if let name = summary.chainName { ChainNameBadge(name: name) }
                        ViaClaudeBadge(model: model, entity: .decision, id: decision.id, compact: true)
                        Text(decision.text).font(.callout).lineLimit(2)
                            .strikethrough(look == .struck, color: .secondary)
                            .foregroundStyle(decision.status.isOpen ? .primary : .secondary)
                        if let description = decision.notes, !description.isEmpty {
                            Image(systemName: "text.alignleft").font(.caption).foregroundStyle(.secondary)
                                .help(String(localized: "Ha una descrizione: clicca per leggerla"))
                        }
                        Spacer(minLength: 4)
                        if let link = linkCaption {
                            Text(link).font(.caption).foregroundStyle(.secondary).fixedSize()
                        }
                        if decision.kind.isWork, !decision.status.isOpen || decision.status == .waiting {
                            Text(DecisionRow.label(summary, mode: mode).lowercased()).font(.caption)
                                .foregroundStyle(look == .done ? Color.green : Color.secondary).fixedSize()
                        }
                    }
                    KeyPointWorkLine(model: model, summary: summary)
                    if let closer = closedElsewhere {
                        Text("→ \(closer)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            // Neutral cards (style A): the kind's colour stays on the rail icon.
            .background(RoundedRectangle(cornerRadius: 8).fill(IAGOColor.card))
            .overlay(
                RoundedRectangle(cornerRadius: 8).stroke(
                    model.selectedDecisionID == decision.id ? Color.accentColor : Color.secondary.opacity(0.2),
                    lineWidth: model.selectedDecisionID == decision.id ? 2 : 1)
            )
            .padding(.leading, nested ? 18 : 0)
            .padding(.vertical, 3)
        }
        .contentShape(Rectangle())
        .onTapGesture { model.selectedDecisionID = summary.decision.id }
        .contextMenu {
            Button(String(localized: "Modifica…")) { model.editingDecision = DecisionDraft(summary) }
            KeyPointActions(model: model, summary: summary)
        }
    }

    /// Closed by an entry of the same day that is on the timeline too: shown right under it (`DecisionOrdering`).
    private var nested: Bool {
        summary.supersededByAll.contains { newer in
            Calendar.current.isDate(newer.decidedAt, inSameDayAs: summary.decision.decidedAt)
                && model.timelineDecisions.contains { $0.id == newer.id }
        }
    }

    /// "risponde a ↓", "completa ↓": the entry closed another one shown under it.
    private var linkCaption: String? {
        guard
            let older = summary.supersedesAll.first(where: { older in
                Calendar.current.isDate(older.decidedAt, inSameDayAs: summary.decision.decidedAt)
                    && model.timelineDecisions.contains { $0.id == older.id }
            })
        else { return nil }
        return "\(DecisionRow.verb(newer: summary.decision.kind, older: older.kind)) ↓"
    }

    /// Closed by an entry of another day: "chiusa da «…»" stays at its own date.
    private var closedElsewhere: String? {
        guard !nested, let newer = summary.supersededBy else { return nil }
        let label = DecisionRow.closedByLabel(older: summary.decision.kind, by: newer.kind).lowercased()
        return "\(label) «\(DecisionRow.clip(newer.text, 60))»"
    }
}

private struct TimelineEntry: View {
    let model: AppModel
    let summary: ItemSummary
    let isSelected: Bool
    @State private var preview: String?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(summary.item.occurredAt.formatted(.dateTime.day().month(.abbreviated))).font(.callout).bold()
                Text(summary.item.occurredAt.formatted(.dateTime.hour().minute())).font(.caption).foregroundStyle(
                    .secondary)
            }
            .frame(width: 70, alignment: .trailing)
            .padding(.top, 12)
            ZStack(alignment: .top) {
                Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 2)
                Circle().fill(Color.accentColor).frame(width: 11, height: 11).padding(.top, 16)
            }
            .frame(width: 30)
            card.padding(.vertical, 6)
        }
        .contentShape(Rectangle())
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: ItemIcon.name(summary.item, direction: summary.email?.direction))
                    .foregroundStyle(summary.item.type == .email ? Color.indigo : Color.secondary)
                Text(summary.item.title).font(.headline).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                SuggestionBadge(count: model.pendingSuggestions[summary.id] ?? 0)
                if summary.hasActiveJob { ProgressView().controlSize(.mini) }
                if let duration = summary.item.durationSec {
                    Text(Format.duration(duration)).font(.caption).foregroundStyle(.secondary).fixedSize()
                }
            }
            // Sender, links and category on their own line, so the title keeps the width.
            let sender = summary.email?.direction == .inbound ? summary.email?.from : nil
            if sender != nil || summary.linkCount > 0 || summary.categoryName != nil {
                HStack(spacing: 8) {
                    if let sender {
                        Text(String(localized: "da \(sender.display)")).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if summary.linkCount > 0 {
                        Label("\(summary.linkCount)", systemImage: "link").font(.caption).foregroundStyle(.secondary)
                            .help(String(localized: "Elementi collegati")).fixedSize()
                    }
                    if let category = summary.categoryName {
                        Text(category).font(.caption).lineLimit(1).padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    }
                }
            }
            if let preview {
                Text(preview).font(.callout).foregroundStyle(.secondary).lineLimit(2)
            } else if !summary.hasTranscript, summary.item.type == .call {
                Text(
                    summary.hasAudio
                        ? String(localized: "Solo audio, non trascritta") : String(localized: "Nessun contenuto")
                )
                .font(.callout).foregroundStyle(.tertiary)
            }
            StreamDots(model: model, streamIDs: summary.streamIDs)
            if !summary.tags.isEmpty {
                Text(summary.tags.map { "#\($0)" }.joined(separator: " ")).font(.caption).foregroundStyle(.tint)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(
                isSelected ? Color.accentColor.opacity(0.12) : IAGOColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
        )
        .task(id: summary.hasTranscript) {
            preview = summary.hasTranscript || summary.item.type != .call ? await model.preview(summary.id) : nil
        }
    }
}
