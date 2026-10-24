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
                if model.summaries.isEmpty && model.timelineDecisions.isEmpty {
                    ContentUnavailableView(
                        String(localized: "Nessun elemento in questo progetto"), systemImage: "calendar")
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    ViewModePicker(model: model)
                    FilterBar(model: model)
                }
                .background(.bar)
            }
        }
    }

    /// Items and decisions (FR-154) interleaved by date, most recent first. Decisions are shown only when no
    /// item filter is active, so filtering by tag or type shows just the matching items.
    private var groups: [(month: Date, entries: [TimelineRow])] {
        let calendar = Calendar.current
        var rows = model.summaries.map(TimelineRow.item)
        rows.sort { $0.date > $1.date }
        if !model.filter.isActive {
            // Decisions keep their own order (superseded under their successor on the same day) and are
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
        if !model.filter.isActive, !model.timelineNotes.isEmpty {
            // Notes at their own date (FR-175).
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
        let grouped = Dictionary(grouping: rows) {
            calendar.date(from: calendar.dateComponents([.year, .month], from: $0.date))!
        }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]!) }
    }
}

enum TimelineRow: Identifiable {
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

/// A decision on the timeline: a green seal on the line instead of a dot, and a slim card.
private struct TimelineDecision: View {
    let model: AppModel
    let summary: DecisionSummary

    var body: some View {
        let decision = summary.decision
        HStack(alignment: .top, spacing: 0) {
            Text(decision.decidedAt.formatted(.dateTime.day().month(.abbreviated)))
                .font(.caption).foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
                .padding(.top, 9)
            ZStack(alignment: .top) {
                Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 2)
                Image(systemName: DecisionRow.icon(decision))
                    .font(.system(size: 14))
                    .foregroundStyle(DecisionRow.color(decision))
                    .background(Circle().fill(Color(nsColor: .windowBackgroundColor)).padding(-2))
                    .padding(.top, 8)
            }
            .frame(width: 30)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(DecisionRow.kindLabel(decision.kind)).font(.caption).bold().foregroundStyle(
                    DecisionRow.tint(decision.kind))
                if let name = summary.chainName { ChainNameBadge(name: name) }
                ViaClaudeBadge(model: model, entity: .decision, id: decision.id, compact: true)
                Text(decision.text).font(.callout).lineLimit(2)
                    .strikethrough(decision.status != .active, color: .secondary)
                    .foregroundStyle(decision.status == .active ? .primary : .secondary)
                if let description = decision.notes, !description.isEmpty {
                    Image(systemName: "text.alignleft").font(.caption).foregroundStyle(.secondary)
                        .help(String(localized: "Ha una descrizione: clicca per leggerla"))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.08)))
            .overlay(
                RoundedRectangle(cornerRadius: 8).stroke(
                    model.selectedDecisionID == decision.id ? Color.accentColor : Color.green.opacity(0.35),
                    lineWidth: model.selectedDecisionID == decision.id ? 2 : 1)
            )
            .padding(.vertical, 3)
        }
        .contentShape(Rectangle())
        .onTapGesture { model.selectedDecisionID = summary.decision.id }
        .contextMenu {
            Button(String(localized: "Modifica…")) { model.editingDecision = DecisionDraft(summary) }
        }
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
                isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
        )
        .task(id: summary.hasTranscript) {
            preview = summary.hasTranscript || summary.item.type != .call ? await model.preview(summary.id) : nil
        }
    }
}
