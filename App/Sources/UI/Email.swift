import AppKit
import IAGOIngest
import IAGOStore
import SwiftUI
import UniformTypeIdentifiers

/// An `.eml` waiting for the user's choices before it becomes an item: attachments and project (FR-184).
struct EmailImportDraft: Identifiable {
    let id = UUID()
    var message: EmailMessage
    var original: Data
    var fileName: String
    var suggestions: [ProjectSuggestion]
    /// Indices of the attachments to import: all but images under 20 KB (signatures, logos).
    var selected: Set<Int>
    var projectID: String?
    var streamIDs: [String] = []
    /// nil: from the user's addresses (FR-182).
    var direction: EmailMeta.Direction?
    /// IAGO's proposal for project and streams, with the clue it used.
    var classification: EmailClassification?
    /// Same Message-ID already in the archive: skipped unless the user insists.
    var alreadyImported = false
    /// Bulk import: whether this email is imported.
    var include = true

    init(
        message: EmailMessage, original: Data, fileName: String, suggestions: [ProjectSuggestion],
        classification: EmailClassification? = nil, alreadyImported: Bool = false
    ) {
        self.message = message
        self.original = original
        self.fileName = fileName
        self.suggestions = suggestions
        self.classification = classification
        self.alreadyImported = alreadyImported
        // Pre-selected: emails IAGO could file in a project; duplicates never.
        include = !alreadyImported && classification?.projectID != nil
        streamIDs = classification?.streamIDs ?? []
        selected = Set(
            message.attachments.indices.filter { index in
                let attachment = message.attachments[index]
                return !(attachment.mimeType.hasPrefix("image/") && attachment.data.count < 20_000)
            })
        projectID = classification?.projectID ?? suggestions.first?.projectID
    }
}

/// Confirmation of an imported email: headers, attachments to keep as linked documents, project.
struct EmailImportSheet: View {
    let model: AppModel
    @State var draft: EmailImportDraft
    let done: () -> Void
    @State private var importing = false
    @State private var roles: [String: AddressRole] = [:]
    @State private var confirmingCancel = false

    var body: some View {
        let message = draft.message
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(String(localized: "Importa email"), systemImage: "envelope").font(.title3).bold()
                Spacer()
                if model.pendingEmailsTotal > 1 {
                    Text(
                        String(
                            localized:
                                "\(model.pendingEmailsTotal - model.pendingEmails.count + 1) di \(model.pendingEmailsTotal)"
                        )
                    )
                    .monospacedDigit().foregroundStyle(.secondary)
                }
            }
            if draft.alreadyImported {
                Label(
                    String(localized: "Questa email è già in archivio."), systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange).font(.callout)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.subject ?? String(localized: "(senza oggetto)")).font(.headline)
                if let from = message.from {
                    HStack(spacing: 4) {
                        Text(String(localized: "Da:")).foregroundStyle(.secondary)
                        AddressLabel(model: model, name: from.name, address: from.address, roles: roles)
                    }
                    .font(.callout)
                }
                if !message.to.isEmpty {
                    HStack(alignment: .top, spacing: 4) {
                        Text(String(localized: "A:")).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach(message.to.prefix(4), id: \.self) { entry in
                                AddressLabel(model: model, name: entry.name, address: entry.address, roles: roles)
                            }
                            if message.to.count > 4 {
                                Text(String(localized: "e altri \(message.to.count - 4)")).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .font(.callout)
                }
                if let date = message.date {
                    Text(date.formatted(date: .long, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                }
                Text(message.bodyMarkdown).font(.callout).foregroundStyle(.secondary).lineLimit(4).padding(.top, 4)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
            if !message.attachments.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Allegati da importare come documenti collegati")).font(.caption).bold()
                    ForEach(message.attachments.indices, id: \.self) { index in
                        let attachment = message.attachments[index]
                        Toggle(
                            isOn: Binding(
                                get: { draft.selected.contains(index) },
                                set: { on in
                                    if on { draft.selected.insert(index) } else { draft.selected.remove(index) }
                                })
                        ) {
                            HStack {
                                Image(systemName: attachment.mimeType.hasPrefix("image/") ? "photo" : "doc")
                                Text(attachment.filename)
                                Text(Format.bytes(Int64(attachment.data.count))).foregroundStyle(.secondary)
                                if attachment.isInline {
                                    Text(String(localized: "nel testo")).font(.caption).foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
            HStack {
                Text(String(localized: "Progetto")).foregroundStyle(.secondary)
                Picker("", selection: $draft.projectID) {
                    Text(String(localized: "Da classificare")).tag(String?.none)
                    ForEach(model.projects) { project in Text(projectLabel(project)).tag(Optional(project.id)) }
                }
                .labelsHidden().fixedSize()
            }
            if let projectID = draft.projectID, !model.streams(of: projectID).isEmpty {
                HStack(alignment: .top) {
                    Text(String(localized: "Stream")).foregroundStyle(.secondary)
                    StreamChooser(model: model, projectID: projectID, selection: $draft.streamIDs)
                }
            }
            if let reason = draft.classification.map(EmailClassificationText.reason), !reason.isEmpty {
                Label(reason, systemImage: "sparkles").font(.caption).foregroundStyle(.secondary)
            } else if !draft.suggestions.isEmpty {
                suggestionLine
            }
            HStack {
                Text(String(localized: "Direzione")).foregroundStyle(.secondary)
                Picker("", selection: $draft.direction) {
                    Text(String(localized: "Automatica")).tag(EmailMeta.Direction?.none)
                    Text(String(localized: "Ricevuta")).tag(Optional(EmailMeta.Direction.inbound))
                    Text(String(localized: "Inviata")).tag(Optional(EmailMeta.Direction.outbound))
                }
                .labelsHidden().fixedSize()
            }
            HStack {
                Spacer()
                // No Esc: leaving without a choice would lose emails (ask first).
                if model.pendingEmailsTotal > 1 {
                    Button(String(localized: "Annulla tutte"), role: .cancel) { confirmingCancel = true }
                    Button(String(localized: "Salta"), action: done)
                } else {
                    Button(String(localized: "Non importare"), role: .cancel) { confirmingCancel = true }
                }
                Button(String(localized: "Importa")) {
                    importing = true
                    Task {
                        await model.importEmail(draft)
                        importing = false
                        done()
                    }
                }
                .keyboardShortcut(.defaultAction).disabled(importing)
            }
        }
        .padding(20)
        .frame(width: 560)
        .interactiveDismissDisabled()
        .confirmationDialog(
            model.pendingEmails.count > 1
                ? String(localized: "Non importare le \(model.pendingEmails.count) email rimaste?")
                : String(localized: "Non importare questa email?"),
            isPresented: $confirmingCancel, titleVisibility: .visible
        ) {
            Button(String(localized: "Non importare"), role: .destructive) {
                model.pendingEmails = []
                done()
            }
            Button(String(localized: "Torna all'import"), role: .cancel) {}
        } message: {
            Text(String(localized: "Per importarle più tardi dovrai trascinarle di nuovo."))
        }
        .onAppear {
            let message = draft.message
            let all = ([message.from].compactMap { $0 } + message.to + message.cc).map(\.address)
            roles = (try? model.archive.roles(for: all)) ?? [:]
            // A known person of a client with one project only: that project.
            guard draft.projectID == nil, let clientID = draft.suggestions.first?.clientID else { return }
            let projects = model.projects.filter { $0.clientId == clientID }
            if projects.count == 1 { draft.projectID = projects[0].id }
        }
    }

    private func projectLabel(_ project: Project) -> String {
        model.client(project.clientId).map { "\(project.name) · \($0.name)" } ?? project.name
    }

    /// Why a project is proposed: the known people in the email.
    private var suggestionLine: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(draft.suggestions, id: \.self) { suggestion in
                let target =
                    suggestion.projectID.flatMap { model.project($0)?.name }
                    ?? suggestion.clientID.flatMap { model.client($0).map { client in "cliente \(client.name)" } } ?? ""
                Label(
                    String(localized: "Suggerito: \(target), per \(suggestion.people.joined(separator: ", "))"),
                    systemImage: "sparkles"
                )
                .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// "Nuova email" (FR-180.1/3): fields by hand, or a screenshot read with OCR whose header lines are proposed.
struct NewEmailSheet: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss

    /// From a project's import (ADR-0076) the email starts in that project.
    init(model: AppModel, projectID: String? = nil) {
        self.model = model
        _projectID = State(initialValue: projectID)
    }

    @State private var from = ""
    @State private var to = ""
    @State private var cc = ""
    @State private var subject = ""
    @State private var date = Date()
    @State private var direction: EmailMeta.Direction?
    @State private var bodyText = ""
    @State private var projectID: String?
    @State private var reading = false
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(String(localized: "Nuova email"), systemImage: "envelope.badge").font(.title3).bold()
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                row(String(localized: "Da"), $from, String(localized: "Mario Rossi <mario@cliente.it>"))
                row(String(localized: "A"), $to, String(localized: "indirizzi separati da virgola"))
                row(String(localized: "Cc"), $cc, "")
                row(String(localized: "Oggetto"), $subject, "")
                GridRow {
                    Text(String(localized: "Data")).foregroundStyle(.secondary)
                    HStack {
                        DatePicker("", selection: $date).labelsHidden().fixedSize()
                        Picker("", selection: $direction) {
                            Text(String(localized: "Direzione automatica")).tag(EmailMeta.Direction?.none)
                            Text(String(localized: "Ricevuta")).tag(Optional(EmailMeta.Direction.inbound))
                            Text(String(localized: "Inviata")).tag(Optional(EmailMeta.Direction.outbound))
                        }
                        .labelsHidden().fixedSize()
                    }
                }
                GridRow {
                    Text(String(localized: "Progetto")).foregroundStyle(.secondary)
                    Picker("", selection: $projectID) {
                        Text(String(localized: "Da classificare")).tag(String?.none)
                        ForEach(model.projects) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .labelsHidden().fixedSize()
                }
            }
            TextEditor(text: $bodyText)
                .font(.body).frame(minHeight: 180)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                .overlay(alignment: .topLeading) {
                    if bodyText.isEmpty {
                        Text(String(localized: "Incolla qui il testo della mail"))
                            .foregroundStyle(.tertiary).padding(6).allowsHitTesting(false)
                    }
                }
            HStack {
                Button(String(localized: "Da screenshot negli appunti"), systemImage: "text.viewfinder") {
                    readScreenshot()
                }
                .help(
                    String(localized: "Legge con l'OCR lo screenshot copiato (⌘⇧⌃4) e propone mittente, oggetto e data")
                )
                if reading { ProgressView().controlSize(.small) }
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(String(localized: "Salva")) { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving)
            }
        }
        .padding(20)
        .frame(width: 620)
        .onChange(of: from) { _, value in suggestProject(value) }
    }

    private func row(_ label: String, _ text: Binding<String>, _ prompt: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            TextField(prompt, text: text).textFieldStyle(.roundedBorder)
        }
    }

    private func suggestProject(_ value: String) {
        guard projectID == nil else { return }
        let addresses = EmailParser.addresses(value).map(\.address)
        projectID = (try? model.archive.projectSuggestions(for: addresses))?.first?.projectID
    }

    private func readScreenshot() {
        guard let image = NSImage(pasteboard: .general)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            model.lastError = String(localized: "Negli appunti non c'è un'immagine.")
            return
        }
        reading = true
        Task {
            defer { reading = false }
            guard let text = try? await Task.detached { try ContentExtractor.extract(image: image).markdown }.value
            else {
                model.lastError = String(localized: "Non riesco a leggere il testo dello screenshot.")
                return
            }
            let headers = EmailParser.guessHeaders(fromOCR: text)
            if from.isEmpty, let value = headers.from { from = value }
            if to.isEmpty, let value = headers.to { to = value }
            if cc.isEmpty, let value = headers.cc { cc = value }
            if subject.isEmpty, let value = headers.subject { subject = value }
            bodyText = bodyText.isEmpty ? text : bodyText + "\n\n" + text
        }
    }

    private func save() {
        let fromAddress = EmailParser.addresses(from).first
        let input = EmailInput(
            from: fromAddress.map { EmailMeta.Address(name: $0.name, address: $0.address) }
                ?? (from.isEmpty ? nil : EmailMeta.Address(name: from, address: "")),
            to: EmailParser.addresses(to).map { EmailMeta.Address(name: $0.name, address: $0.address) },
            cc: EmailParser.addresses(cc).map { EmailMeta.Address(name: $0.name, address: $0.address) },
            subject: subject, sentAt: date, bodyMarkdown: bodyText, direction: direction)
        saving = true
        Task {
            await model.createEmail(input, projectID: projectID)
            saving = false
            dismiss()
        }
    }
}

// MARK: - Item view

/// Email header in the item view (FR-203): from, to, cc, date, direction (changeable), thread.
struct EmailHeaderSection: View {
    let model: AppModel
    let itemID: String
    @State private var meta: EmailMeta?
    @State private var thread: [Item] = []
    @State private var roles: [String: AddressRole] = [:]

    var body: some View {
        SectionBox(String(localized: "Email"), systemImage: "envelope", tint: .indigo, collapseKey: "email") {
            if let meta {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                    if let from = meta.from { addresses(String(localized: "Da"), [from]) }
                    if !meta.to.isEmpty { addresses(String(localized: "A"), meta.to) }
                    if !meta.cc.isEmpty { addresses(String(localized: "Cc"), meta.cc) }
                }
                Picker(
                    String(localized: "Direzione"),
                    selection: Binding(
                        get: { meta.direction },
                        set: { value in model.perform { try model.archive.setEmailDirection(itemID, value) } })
                ) {
                    Label(String(localized: "Ricevuta"), systemImage: "arrow.down.left").tag(
                        EmailMeta.Direction.inbound)
                    Label(String(localized: "Inviata"), systemImage: "arrow.up.right").tag(EmailMeta.Direction.outbound)
                }
                .pickerStyle(.segmented).fixedSize()
                if thread.count > 1 {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "Conversazione (\(thread.count) email)")).font(.caption).bold()
                        ForEach(thread) { email in
                            Button {
                                model.selectedItemID = email.id
                            } label: {
                                HStack {
                                    Image(systemName: email.id == itemID ? "largecircle.fill.circle" : "circle")
                                        .font(.caption2)
                                    Text(email.occurredAt.formatted(date: .abbreviated, time: .shortened))
                                        .foregroundStyle(.secondary)
                                    Text(email.title).lineLimit(1)
                                }
                                .font(.callout)
                            }
                            .buttonStyle(.plain)
                            .disabled(email.id == itemID)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .task(id: model.revision) {
            meta = try? model.archive.emailMeta(itemID: itemID)
            thread = (try? model.archive.thread(itemID: itemID)) ?? []
            let all = ([meta?.from].compactMap { $0 } + (meta?.to ?? []) + (meta?.cc ?? [])).map(\.address)
            roles = (try? model.archive.roles(for: all)) ?? [:]
        }
    }

    private func addresses(_ label: String, _ list: [EmailMeta.Address]) -> some View {
        GridRow(alignment: .top) {
            Text(label).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(list, id: \.self) { entry in
                    AddressLabel(model: model, name: entry.name, address: entry.address, roles: roles)
                }
            }
        }
        .font(.callout)
    }
}

/// "Collegamenti" (FR-201): linked items in both directions, "Collega a…" with a search.
struct LinksSection: View {
    let model: AppModel
    let itemID: String
    @State private var links: [LinkedItem] = []
    @State private var picking = false

    var body: some View {
        SectionBox(
            String(localized: "Collegamenti"), systemImage: "link", tint: .mint, collapseKey: "links",
            detail: links.isEmpty ? nil : "\(links.count)",
            emptyText: links.isEmpty ? String(localized: "Nessun collegamento ad altri elementi") : nil,
            emptyAction: (String(localized: "Collega a…"), { picking = true })
        ) {
            ForEach(links) { linked in
                HStack(spacing: 8) {
                    Image(systemName: ItemIcon.name(linked.item)).foregroundStyle(.secondary).frame(width: 16)
                    Text(Self.label(linked)).font(.caption).foregroundStyle(.secondary)
                    Button(linked.item.title) { model.selectedItemID = linked.item.id }.buttonStyle(.link)
                    Text(linked.item.occurredAt.formatted(date: .abbreviated, time: .omitted)).font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button {
                        model.perform { try model.archive.removeLink(linked.link.id) }
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless).help(String(localized: "Togli il collegamento"))
                }
            }
            Button {
                picking = true
            } label: {
                Label(String(localized: "Collega a…"), systemImage: "plus")
            }
        }
        .task(id: model.revision) { links = (try? model.archive.links(itemID: itemID)) ?? [] }
        .sheet(isPresented: $picking) { LinkPicker(model: model, itemID: itemID) }
    }

    static func label(_ linked: LinkedItem) -> String {
        switch (linked.link.kind, linked.outgoing) {
        case (.replyTo, true): String(localized: "risponde a")
        case (.replyTo, false): String(localized: "risposta:")
        case (.attachmentOf, true): String(localized: "allegato di")
        case (.attachmentOf, false): String(localized: "allegato:")
        case (.followUpOf, true): String(localized: "segue")
        case (.followUpOf, false): String(localized: "seguito da")
        case (.related, _): String(localized: "correlato")
        }
    }
}

/// "Collega a…": search an item by title, choose the kind of link.
struct LinkPicker: View {
    let model: AppModel
    let itemID: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var kind = ItemLink.Kind.related
    @State private var items: [Item] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Collega a…")).font(.title3).bold()
            Picker(String(localized: "Tipo"), selection: $kind) {
                Text(String(localized: "Correlato")).tag(ItemLink.Kind.related)
                Text(String(localized: "Segue (è il seguito di)")).tag(ItemLink.Kind.followUpOf)
                Text(String(localized: "Risponde a")).tag(ItemLink.Kind.replyTo)
                Text(String(localized: "È allegato di")).tag(ItemLink.Kind.attachmentOf)
            }
            .fixedSize()
            TextField(String(localized: "Cerca per titolo"), text: $query).textFieldStyle(.roundedBorder)
            List(filtered) { item in
                Button {
                    model.perform { try model.archive.addLink(from: itemID, to: item.id, kind: kind) }
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: ItemIcon.name(item)).foregroundStyle(.secondary)
                        Text(item.title)
                        Spacer()
                        Text(item.occurredAt.formatted(date: .abbreviated, time: .omitted)).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(height: 280)
            HStack {
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 520)
        .task { items = ((try? model.archive.items()) ?? []).filter { $0.id != itemID } }
    }

    private var filtered: [Item] {
        let q = TagNormalizer.normalize(query)
        let list = q.isEmpty ? items : items.filter { TagNormalizer.normalize($0.title).contains(q) }
        return Array(list.prefix(100))
    }
}

/// Icon of an item type, shared by lists, timeline and links (FR-202).
enum ItemIcon {
    static func name(_ item: Item, direction: EmailMeta.Direction? = nil) -> String {
        switch item.type {
        case .email:
            switch direction {
            case .inbound: "envelope.arrow.triangle.branch"
            case .outbound: "paperplane"
            case nil: "envelope"
            }
        case .document: "doc.text"
        case .call: item.source == .import ? "square.and.arrow.down" : "phone"
        }
    }
}

// MARK: - People of a client, a project or the user's organization (ADR-0040)

struct PeopleSheet: View {
    let model: AppModel
    let title: String
    let clientID: String?
    let projectID: String?
    /// Inside the project/client settings panel: no title, no "Fatto", no fixed width.
    var embedded = false
    @Environment(\.dismiss) private var dismiss
    @State private var contacts: [ContactSummary] = []
    @State private var name = ""
    @State private var email = ""
    @State private var role = Contact.Role.client

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !embedded { Text(title).font(.title3).bold() }
            Text(
                String(
                    localized:
                        "Interni, clienti e fornitori con la loro email: IAGO li riconosce nelle email importate e propone il progetto."
                )
            )
            .font(.caption).foregroundStyle(.secondary)
            ForEach(contacts) { entry in
                HStack {
                    Picker(
                        "",
                        selection: Binding(
                            get: { entry.contact.role },
                            set: { value in
                                model.perform {
                                    try model.archive.updateContact(entry.id, name: nil, email: nil, role: value)
                                }
                                reload()
                            })
                    ) {
                        ForEach(Contact.Role.allCases, id: \.self) { Text(Self.label($0)).tag($0) }
                    }
                    .labelsHidden().frame(width: 110)
                    Text(entry.name).bold()
                    Text(entry.contact.email ?? "").foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        model.perform { try model.archive.deleteContact(entry.id) }
                        reload()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
            if contacts.isEmpty {
                Text(String(localized: "Nessuna persona.")).foregroundStyle(.secondary)
            }
            if let clientID {
                Divider()
                Text(String(localized: "Domini del cliente")).font(.caption).bold()
                DomainRulesEditor(model: model, clientID: clientID)
            }
            Divider()
            HStack {
                Picker("", selection: $role) {
                    ForEach(Contact.Role.allCases, id: \.self) { Text(Self.label($0)).tag($0) }
                }
                .labelsHidden().frame(width: 110)
                TextField(String(localized: "Nome e cognome"), text: $name).textFieldStyle(.roundedBorder)
                TextField(String(localized: "email"), text: $email).textFieldStyle(.roundedBorder)
                Button(String(localized: "Aggiungi")) { add() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            let similar = similarPeople
            if !similar.isEmpty {
                Text(String(localized: "Già in archivio: \(similar.joined(separator: ", "))"))
                    .font(.caption).foregroundStyle(.orange)
            }
            if !embedded {
                HStack {
                    Spacer()
                    Button(String(localized: "Fatto")) { dismiss() }.keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(embedded ? 0 : 20)
        .frame(width: embedded ? nil : 620)
        .onAppear {
            role = clientID == nil && projectID == nil ? .internal : .client
            reload()
        }
    }

    /// People with a similar name already known (decisions, other clients): avoids duplicates.
    private var similarPeople: [String] {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return [] }
        return model.people.map(\.name).filter { ProjectNameMatcher.isSimilar(trimmed, $0) }
    }

    private func add() {
        model.perform {
            try model.archive.addContact(
                name: name, email: email, role: role, clientID: clientID, projectID: projectID)
        }
        name = ""
        email = ""
        reload()
    }

    private func reload() {
        contacts = (try? model.archive.contacts(clientID: clientID, projectID: projectID)) ?? []
        model.reload()
    }

    static func label(_ role: Contact.Role) -> String {
        switch role {
        case .internal: String(localized: "Interno")
        case .client: String(localized: "Cliente")
        case .supplier: String(localized: "Fornitore")
        }
    }
}

/// Domain rules: all of them in Settings (`clientID == nil`), or the domains of one client in its "Persone…".
struct DomainRulesEditor: View {
    let model: AppModel
    let clientID: String?
    @State private var rules: [DomainRule] = []
    @State private var domain = ""
    @State private var role = Contact.Role.internal
    @State private var ruleClient: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(visible, id: \.domain) { rule in
                HStack(spacing: 8) {
                    Text("@\(rule.domain)").monospaced()
                    RoleBadge(role: rule.role, clientName: model.client(rule.clientID)?.name)
                    Spacer()
                    Button {
                        save(rules.filter { $0.domain != rule.domain })
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
            if visible.isEmpty {
                Text(
                    clientID == nil
                        ? String(localized: "Nessun dominio. Esempio: @azienda.it → Interno.")
                        : String(localized: "Nessun dominio per questo cliente.")
                )
                .font(.caption).foregroundStyle(.secondary)
            }
            // Wraps on narrow panes: "Aggiungi" never goes out of view.
            FlowLayout(spacing: 8) {
                TextField(String(localized: "@dominio.it"), text: $domain).textFieldStyle(.roundedBorder)
                    .frame(width: 200).onSubmit(add)
                if clientID == nil {
                    Picker("", selection: $role) {
                        ForEach(Contact.Role.allCases, id: \.self) { Text(PeopleSheet.label($0)).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                    if role == .client {
                        Picker("", selection: $ruleClient) {
                            Text(String(localized: "Nessun cliente")).tag(String?.none)
                            ForEach(model.clients) { Text($0.name).tag(Optional($0.id)) }
                        }
                        .labelsHidden().fixedSize()
                    }
                }
                Button(String(localized: "Aggiungi"), action: add)
                    .disabled(!DomainRule.normalize(domain).contains("."))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { rules = (try? model.archive.domainRules()) ?? [] }
    }

    private var visible: [DomainRule] {
        clientID == nil ? rules : rules.filter { $0.clientID == clientID }
    }

    private func add() {
        let normalized = DomainRule.normalize(domain)
        guard normalized.contains(".") else { return }
        let rule =
            clientID != nil
            ? DomainRule(domain: normalized, role: .client, clientID: clientID)
            : DomainRule(domain: normalized, role: role, clientID: role == .client ? ruleClient : nil)
        save(rules.filter { $0.domain != normalized } + [rule])
        domain = ""
    }

    private func save(_ updated: [DomainRule]) {
        model.perform { try model.archive.setDomainRules(updated) }
        rules = (try? model.archive.domainRules()) ?? []
    }
}

/// Interno / Cliente / Fornitore, colored, next to an address or a domain.
struct RoleBadge: View {
    let role: Contact.Role
    var clientName: String?

    var body: some View {
        let color: Color =
            switch role {
            case .internal: .blue
            case .client: .green
            case .supplier: .orange
            }
        Text(clientName.map { "\(PeopleSheet.label(role)) · \($0)" } ?? PeopleSheet.label(role))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }
}

/// An address with its role, if known (person or domain rule).
struct AddressLabel: View {
    let model: AppModel
    let name: String?
    let address: String
    let roles: [String: AddressRole]

    var body: some View {
        HStack(spacing: 4) {
            Text(name.flatMap { $0.isEmpty ? nil : "\($0) <\(address)>" } ?? address).textSelection(.enabled)
            if let role = roles[address.lowercased()] {
                RoleBadge(role: role.role, clientName: model.client(role.clientID)?.name)
            }
        }
    }
}

enum EmailClassificationText {
    static func reason(_ classification: EmailClassification) -> String {
        switch classification.reason {
        case .conversation(let title): String(localized: "Stessa conversazione di «\(title)»")
        case .people(let people): String(localized: "Per \(people.joined(separator: ", "))")
        case .subject(let name): String(localized: "«\(name)» nell'oggetto")
        case .none: ""
        }
    }
}

/// Several emails dropped at once: the stack, then "Una alla volta" or "Tutte insieme" (a table pre-filled with
/// IAGO's proposals; doubtful rows first). The table is also the summary: nothing else to review afterwards.
struct EmailBatchSheet: View {
    let model: AppModel
    @State var drafts: [EmailImportDraft]
    @State private var showsTable = false
    @State private var selection: Set<UUID> = []
    @State private var importing = false
    /// "Verranno importate solo X delle Y email": shown when some new emails are left out.
    @State private var confirmingPartial = false
    @State private var confirmingCancel = false

    init(model: AppModel, drafts: [EmailImportDraft]) {
        self.model = model
        // Doubtful first, then the confident ones, each by date.
        let sorted = drafts.sorted { a, b in
            let doubtA = !(a.classification?.confident ?? false) && !a.alreadyImported
            let doubtB = !(b.classification?.confident ?? false) && !b.alreadyImported
            if doubtA != doubtB { return doubtA }
            return (a.message.date ?? .distantPast) > (b.message.date ?? .distantPast)
        }
        _drafts = State(initialValue: sorted)
        #if DEBUG
            // `-IAGODebugEmailTable YES`: opens straight on the table (layout checks).
            _showsTable = State(initialValue: UserDefaults.standard.bool(forKey: "IAGODebugEmailTable"))
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 18) {
                EmailStack(drafts: drafts)
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "\(drafts.count) email da importare")).font(.title2).bold()
                    let duplicates = drafts.filter(\.alreadyImported).count
                    if duplicates > 0 {
                        Label(
                            String(localized: "\(duplicates) già in archivio: escluse"), systemImage: "checkmark.circle"
                        )
                        .foregroundStyle(.secondary)
                    }
                    let fresh = drafts.filter { !$0.alreadyImported }
                    let filed = fresh.filter { $0.classification?.projectID != nil }.count
                    Text(
                        filed == fresh.count
                            ? String(localized: "IAGO ha trovato il progetto per tutte.")
                            : String(
                                localized:
                                    "IAGO ha trovato il progetto per \(filed) di \(fresh.count): sono già selezionate. Le altre si possono aggiungere e restano da classificare."
                            )
                    )
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
            if showsTable {
                // Above the table, as in Mail and Finder.
                HStack(spacing: 10) {
                    let selectable = drafts.filter { !$0.alreadyImported }
                    let allOn = !selectable.isEmpty && selectable.allSatisfy(\.include)
                    Button(allOn ? String(localized: "Deseleziona tutte") : String(localized: "Seleziona tutte")) {
                        for index in drafts.indices where !drafts[index].alreadyImported {
                            drafts[index].include = !allOn
                        }
                    }
                    Text(String(localized: "\(selectable.filter(\.include).count) di \(selectable.count) selezionate"))
                        .foregroundStyle(.secondary).monospacedDigit()
                    Spacer()
                }
                table
                duplicatesBox
            } else {
                HStack(spacing: 12) {
                    choice(
                        String(localized: "Una alla volta"),
                        String(localized: "Conferma ogni email con i suoi allegati"),
                        "rectangle.stack"
                    ) { model.reviewOneByOne(drafts) }
                    choice(
                        String(localized: "Tutte insieme"),
                        String(localized: "Tabella già compilata da IAGO: controlla i dubbi e importa"), "tablecells"
                    ) { showsTable = true }
                }
            }
            HStack {
                if showsTable, !selection.isEmpty {
                    Menu(String(localized: "Assegna progetto a \(selection.count)…")) {
                        Button(String(localized: "Da classificare")) { assign(nil) }
                        Divider()
                        ForEach(model.projects) { project in Button(project.name) { assign(project.id) } }
                    }
                    .fixedSize()
                }
                Spacer()
                // No Esc: leaving without a choice would lose emails (ask first).
                Button(String(localized: "Non importare"), role: .cancel) { confirmingCancel = true }
                if showsTable {
                    let count = drafts.filter(\.include).count
                    Button(String(localized: "Importa \(count) email")) {
                        let selectable = drafts.filter { !$0.alreadyImported }.count
                        if count < selectable { confirmingPartial = true } else { runImport() }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(count == 0 || importing)
                }
                if importing { ProgressView().controlSize(.small) }
            }
        }
        .padding(20)
        .frame(width: showsTable ? 1180 : 620)
        .frame(minHeight: showsTable ? 520 : 0)
        .interactiveDismissDisabled()
        .confirmationDialog(
            String(localized: "Non importare nessuna delle \(drafts.filter { !$0.alreadyImported }.count) email?"),
            isPresented: $confirmingCancel, titleVisibility: .visible
        ) {
            Button(String(localized: "Non importare"), role: .destructive) { model.emailBatch = nil }
            Button(String(localized: "Torna all'import"), role: .cancel) {}
        } message: {
            Text(String(localized: "Per importarle più tardi dovrai trascinarle di nuovo."))
        }
        .overlay {
            if confirmingPartial {
                let selectable = drafts.filter { !$0.alreadyImported }.count
                PartialImportConfirmation(
                    included: drafts.filter(\.include).count, total: selectable,
                    proceed: {
                        confirmingPartial = false
                        runImport()
                    }, review: { confirmingPartial = false })
            }
        }
    }

    /// Emails already in the archive, apart from the table: shown for completeness, never imported.
    @ViewBuilder
    private var duplicatesBox: some View {
        let duplicates = drafts.filter(\.alreadyImported)
        if !duplicates.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Label(
                    String(localized: "Già in archivio (\(duplicates.count)): non vengono importate"),
                    systemImage: "checkmark.circle"
                )
                .font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(duplicates) { draft in
                    HStack(spacing: 10) {
                        Text(draft.message.subject ?? String(localized: "(senza oggetto)")).lineLimit(1)
                        Text(draft.message.from?.display ?? "").lineLimit(1)
                        Text(draft.message.date?.formatted(.dateTime.day().month(.abbreviated).hour().minute()) ?? "")
                            .monospacedDigit()
                        Spacer()
                    }
                    .font(.caption).foregroundStyle(.tertiary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
            .overlay(
                RoundedRectangle(cornerRadius: 8).strokeBorder(
                    Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4])))
        }
    }

    private func runImport() {
        importing = true
        Task {
            _ = await model.importBatch(drafts)
            importing = false
            model.emailBatch = nil
        }
    }

    private func choice(_ title: String, _ detail: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon).font(.title2).foregroundStyle(.tint)
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 10).fill(IAGOColor.card))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.25)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func binding(_ draft: EmailImportDraft) -> Binding<EmailImportDraft> {
        Binding(
            get: { drafts.first { $0.id == draft.id } ?? draft },
            set: { value in if let index = drafts.firstIndex(where: { $0.id == draft.id }) { drafts[index] = value } })
    }

    private func assign(_ projectID: String?) {
        for index in drafts.indices where selection.contains(drafts[index].id) {
            drafts[index].projectID = projectID
            drafts[index].streamIDs = []
        }
    }

    private var table: some View {
        Table(drafts.filter { !$0.alreadyImported }, selection: $selection) {
            TableColumn("") { draft in
                Toggle("", isOn: binding(draft).include).labelsHidden()
                    .disabled(draft.alreadyImported)
                    .help(draft.alreadyImported ? String(localized: "Già in archivio: non viene importata") : "")
            }
            .width(24)
            TableColumn(String(localized: "Oggetto")) { draft in
                VStack(alignment: .leading, spacing: 1) {
                    Text(draft.message.subject ?? String(localized: "(senza oggetto)")).lineLimit(1)
                }
                .opacity(draft.include ? 1 : 0.5)
            }
            .width(min: 140, ideal: 200)
            TableColumn(String(localized: "Da")) { draft in
                Text(draft.message.from?.display ?? "").lineLimit(1).help(draft.message.from?.address ?? "")
            }
            .width(min: 80, ideal: 110)
            TableColumn(String(localized: "A")) { draft in
                Text(draft.message.to.map(\.display).joined(separator: ", ")).lineLimit(1)
                    .help(draft.message.to.map(\.address).joined(separator: ", "))
            }
            .width(min: 70, ideal: 90)
            TableColumn(String(localized: "Data")) { draft in
                Text(draft.message.date?.formatted(.dateTime.day().month(.abbreviated).hour().minute()) ?? "")
                    .monospacedDigit()
            }
            .width(min: 80, ideal: 105)
            TableColumn(String(localized: "All.")) { draft in
                Text(draft.selected.isEmpty ? "" : "\(draft.selected.count)").foregroundStyle(.secondary)
                    .help(String(localized: "Allegati che diventano documenti collegati"))
            }
            .width(32)
            TableColumn(String(localized: "Progetto")) { draft in
                Picker("", selection: binding(draft).projectID) {
                    Text(String(localized: "Da classificare")).tag(String?.none)
                    ForEach(model.projects) { project in
                        Text(model.client(project.clientId).map { "\(project.name) · \($0.name)" } ?? project.name)
                            .tag(Optional(project.id))
                    }
                }
                .labelsHidden()
                .onChange(of: draft.projectID) { _, _ in binding(draft).wrappedValue.streamIDs = [] }
            }
            .width(min: 130, ideal: 160)
            TableColumn(String(localized: "Stream")) { draft in
                StreamMenu(model: model, projectID: draft.projectID, selection: binding(draft).streamIDs)
            }
            .width(min: 70, ideal: 90)
            TableColumn(String(localized: "Motivo")) { draft in
                let reason = draft.classification.map(EmailClassificationText.reason) ?? ""
                let doubtful = draft.projectID == nil || !(draft.classification?.confident ?? false)
                Text(reason.isEmpty ? String(localized: "nessun indizio") : reason)
                    .font(.caption).lineLimit(2)
                    .foregroundStyle(doubtful && draft.include ? Color.orange : Color.secondary)
                    .help(reason)
            }
            .width(min: 110, ideal: 170)
        }
        .frame(minHeight: 340)
    }
}

/// Streams of a row as a compact menu.
private struct StreamMenu: View {
    let model: AppModel
    let projectID: String?
    @Binding var selection: [String]

    var body: some View {
        let streams = model.streams(of: projectID)
        if streams.isEmpty {
            Text("—").foregroundStyle(.tertiary)
        } else {
            Menu {
                ForEach(streams) { stream in
                    Toggle(
                        stream.name,
                        isOn: Binding(
                            get: { selection.contains(stream.id) },
                            set: { on in
                                if on { selection.append(stream.id) } else { selection.removeAll { $0 == stream.id } }
                            }))
                }
            } label: {
                Text(
                    selection.isEmpty
                        ? String(localized: "Nessuno")
                        : streams.filter { selection.contains($0.id) }.map(\.name).joined(separator: ", ")
                )
                .lineLimit(1)
            }
            .menuStyle(.borderlessButton)
        }
    }
}

/// The dropped emails drawn as a stack of cards, the first one on top.
private struct EmailStack: View {
    let drafts: [EmailImportDraft]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(drafts.prefix(4).enumerated().reversed()), id: \.offset) { index, draft in
                VStack(alignment: .leading, spacing: 3) {
                    Image(systemName: "envelope.fill").foregroundStyle(.indigo)
                    Text(draft.message.subject ?? "").font(.caption).bold().lineLimit(2)
                    Text(draft.message.from?.display ?? "").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                .padding(8)
                .frame(width: 150, height: 86, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .windowBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                .rotationEffect(.degrees(Double(index) * 3))
                .offset(x: CGFloat(index) * 6, y: CGFloat(index) * 5)
                .opacity(index == 0 ? 1 : 0.9)
            }
            Text("\(drafts.count)")
                .font(.caption.bold()).foregroundStyle(.white)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Capsule().fill(Color.red))
                .offset(x: 138, y: -8)
        }
        .frame(width: 180, height: 110, alignment: .topLeading)
    }
}

/// "Verranno importate solo X delle Y email": "Procedi" happens by itself after 10 seconds; the countdown stops
/// while the pointer is on either button, so a hesitating user is never overtaken.
private struct PartialImportConfirmation: View {
    let included: Int
    let total: Int
    let proceed: () -> Void
    let review: () -> Void
    @State private var remaining = 10
    @State private var paused = false
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Label(
                    String(localized: "Verranno importate solo \(included) delle \(total) email"),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.headline).foregroundStyle(.orange)
                Text(
                    String(
                        localized:
                            "Le \(total - included) non selezionate non entrano in IAGO. Puoi rivederle oppure procedere."
                    )
                )
                .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button(String(localized: "Rivedi scelte"), action: review)
                        .keyboardShortcut(.cancelAction)
                        .onHover { paused = $0 }
                    Button {
                        proceed()
                    } label: {
                        Text(
                            paused
                                ? String(localized: "Procedi")
                                : String(localized: "Procedi (\(remaining))")
                        )
                        .monospacedDigit()
                    }
                    .keyboardShortcut(.defaultAction)
                    .onHover { paused = $0 }
                }
            }
            .padding(20)
            .frame(width: 440)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .windowBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.3)))
            .shadow(radius: 20)
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                MainActor.assumeIsolated {
                    guard !paused else { return }
                    remaining -= 1
                    if remaining <= 0 {
                        timer?.invalidate()
                        proceed()
                    }
                }
            }
        }
        .onDisappear { timer?.invalidate() }
    }
}
