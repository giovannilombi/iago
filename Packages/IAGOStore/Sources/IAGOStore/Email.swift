import Foundation
import GRDB

/// Email metadata (FR-181), one row per email item.
public struct EmailMeta: Codable, FetchableRecord, PersistableRecord, Sendable, Hashable {
    public enum Direction: String, Codable, Sendable { case inbound, outbound }

    public struct Address: Codable, Sendable, Hashable {
        public var name: String?
        public var address: String

        public init(name: String?, address: String) {
            self.name = name
            self.address = address
        }

        public var display: String { name.flatMap { $0.isEmpty ? nil : $0 } ?? address }
    }

    public static let databaseTableName = "email_meta"
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    public var itemId: String
    public var direction: Direction
    public var fromAddr: String?
    public var fromName: String?
    public var toAddrs: String?
    public var ccAddrs: String?
    public var subject: String?
    public var sentAt: Date?
    public var messageId: String?
    public var inReplyTo: String?
    public var refs: String?
    public var threadId: String?

    public var to: [Address] { Self.decode(toAddrs) }
    public var cc: [Address] { Self.decode(ccAddrs) }
    public var from: Address? { fromAddr.map { Address(name: fromName, address: $0) } }

    static func decode(_ json: String?) -> [Address] {
        json.flatMap { try? JSONDecoder().decode([Address].self, from: Data($0.utf8)) } ?? []
    }

    static func encode(_ addresses: [Address]) -> String? {
        addresses.isEmpty ? nil : (try? JSONEncoder().encode(addresses)).map { String(decoding: $0, as: UTF8.self) }
    }
}

/// What the app hands to the archive for a new email (parsed `.eml`, pasted text or screenshot).
public struct EmailInput: Sendable {
    public var from: EmailMeta.Address?
    public var to: [EmailMeta.Address]
    public var cc: [EmailMeta.Address]
    public var subject: String?
    public var sentAt: Date?
    public var messageID: String?
    public var inReplyTo: String?
    public var references: [String]
    public var bodyMarkdown: String
    /// nil: decided from the user's addresses (FR-182).
    public var direction: EmailMeta.Direction?

    public init(
        from: EmailMeta.Address?, to: [EmailMeta.Address] = [], cc: [EmailMeta.Address] = [], subject: String?,
        sentAt: Date?, messageID: String? = nil, inReplyTo: String? = nil, references: [String] = [],
        bodyMarkdown: String, direction: EmailMeta.Direction? = nil
    ) {
        self.from = from
        self.to = to
        self.cc = cc
        self.subject = subject
        self.sentAt = sentAt
        self.messageID = messageID
        self.inReplyTo = inReplyTo
        self.references = references
        self.bodyMarkdown = bodyMarkdown
        self.direction = direction
    }
}

/// Link between two items (FR-201).
public struct ItemLink: SyncRecord, Identifiable, Hashable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case followUpOf = "follow_up_of"
        case attachmentOf = "attachment_of"
        case replyTo = "reply_to"
        case related
    }
    public enum Origin: String, Codable, Sendable { case manual, thread, attachment, suggestion, mcp }

    public static let databaseTableName = "item_link"
    public var id: String
    public var fromItemId: String
    public var toItemId: String
    public var kind: Kind
    public var origin: Origin
    public var createdAt = Date.distantPast
    public var updatedAt = Date.distantPast
    public var deletedAt: Date?
    public var version = 0
    public var deviceId = ""
}

/// A link as seen from one item: the other item and whether the link starts here.
public struct LinkedItem: Sendable, Hashable, Identifiable {
    public var link: ItemLink
    public var item: Item
    public var outgoing: Bool
    public var id: String { link.id }
}

/// A person with a role for a client, a project or the user's own organization (ADR-0040).
public struct Contact: SyncRecord, Identifiable, Hashable {
    public enum Role: String, Codable, Sendable, CaseIterable { case `internal`, client, supplier }

    public static let databaseTableName = "contact"
    public var id: String
    public var entityId: String
    public var email: String?
    public var role: Role
    public var clientId: String?
    public var projectId: String?
    public var createdAt = Date.distantPast
    public var updatedAt = Date.distantPast
    public var deletedAt: Date?
    public var version = 0
    public var deviceId = ""
}

public struct ContactSummary: Sendable, Hashable, Identifiable {
    public var contact: Contact
    public var name: String
    public var id: String { contact.id }
}

/// Proposed filing of an incoming email (bulk import): `confident` proposals can be imported as they are,
/// the others are shown first for a check.
public struct EmailClassification: Sendable, Hashable {
    public enum Reason: Sendable, Hashable {
        case conversation(String)
        case people([String])
        case subject(String)
        case none
    }

    public var projectID: String?
    public var clientID: String?
    public var streamIDs: [String]
    public var reason: Reason
    public var confident: Bool
}

/// Where an email probably belongs, from the people who wrote or received it.
public struct ProjectSuggestion: Sendable, Hashable {
    public var projectID: String?
    public var clientID: String?
    /// Who matched, e.g. "Mario Rossi (cliente)".
    public var people: [String]
}

/// "Everyone @azienda.it is internal": a role for a whole email domain, valid everywhere; a domain
/// of a client also points to that client's projects.
public struct DomainRule: Codable, Sendable, Hashable {
    public var domain: String
    public var role: Contact.Role
    public var clientID: String?

    public init(domain: String, role: Contact.Role, clientID: String? = nil) {
        self.domain = domain
        self.role = role
        self.clientID = clientID
    }

    /// `@Gruppo.Example`, `gruppo.example ` → `gruppo.example`.
    public static func normalize(_ domain: String) -> String {
        domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "@."))
    }

    /// The domain itself or one of its subdomains (`mail.gruppo.example`).
    func matches(_ address: String) -> Bool {
        guard let at = address.lastIndex(of: "@") else { return false }
        let host = address[address.index(after: at)...].lowercased()
        return host == domain || host.hasSuffix("." + domain)
    }
}

/// Who an address is, for badges and suggestions: a known person first, otherwise a domain rule.
public struct AddressRole: Sendable, Hashable {
    public var role: Contact.Role
    public var name: String?
    public var clientID: String?
    public var projectID: String?
    public var byDomain: Bool
}

extension Archive {
    static let userAddressesKey = "user_email_addresses"
    static let domainRulesKey = "email_domain_rules"

    // MARK: Domain rules

    public func domainRules() throws -> [DomainRule] {
        guard let json = try setting(Self.domainRulesKey) else { return [] }
        return (try? JSONDecoder().decode([DomainRule].self, from: Data(json.utf8))) ?? []
    }

    public func setDomainRules(_ rules: [DomainRule]) throws {
        var seen: Set<String> = []
        let clean = rules.compactMap { rule -> DomainRule? in
            let domain = DomainRule.normalize(rule.domain)
            guard domain.contains("."), seen.insert(domain).inserted else { return nil }
            return DomainRule(domain: domain, role: rule.role, clientID: rule.role == .client ? rule.clientID : nil)
        }
        try setSetting(Self.domainRulesKey, String(decoding: try JSONEncoder().encode(clean), as: UTF8.self))
    }

    /// Roles of these addresses: a contact (most specific) or the first matching domain rule.
    public func roles(for addresses: [String]) throws -> [String: AddressRole] {
        let rules = try domainRules()
        let contacts = try contacts(matching: addresses)
        var result: [String: AddressRole] = [:]
        for address in addresses.map({ $0.lowercased() }) {
            if let contact = contacts.first(where: { $0.contact.email == address }) {
                result[address] = AddressRole(
                    role: contact.contact.role, name: contact.name, clientID: contact.contact.clientId,
                    projectID: contact.contact.projectId, byDomain: false)
            } else if let rule = rules.first(where: { $0.matches(address) }) {
                result[address] = AddressRole(
                    role: rule.role, name: nil, clientID: rule.clientID, projectID: nil, byDomain: true)
            }
        }
        return result
    }

    // MARK: User's own addresses (FR-182)

    public func userEmailAddresses() throws -> [String] {
        guard let json = try setting(Self.userAddressesKey) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: Data(json.utf8))) ?? []
    }

    public func setUserEmailAddresses(_ addresses: [String]) throws {
        let clean = Array(
            Set(addresses.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { $0.contains("@") })
        ).sorted()
        try setSetting(Self.userAddressesKey, String(decoding: try JSONEncoder().encode(clean), as: UTF8.self))
    }

    // MARK: Emails (FR-180…185)

    /// Creates an email item: original kept encrypted, body as Markdown, metadata, thread and reply links.
    @discardableResult
    public func importEmail(_ input: EmailInput, original: Data?) throws -> Item {
        // The same message twice (two drops, two clicks) is refused: the archive is the only guard that holds.
        if let messageID = input.messageID, try emailExists(messageID: messageID) {
            throw ArchiveError.duplicateEmail(messageID)
        }
        let occurredAt = input.sentAt ?? now()
        let subject = input.subject?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title =
            subject.flatMap { $0.isEmpty ? nil : $0 }
            ?? "Email · \(Self.titleDate.string(from: occurredAt))"
        let mine = Set(try userEmailAddresses())
        let direction =
            input.direction
            ?? ((input.from.map { mine.contains($0.address.lowercased()) } ?? false) ? .outbound : .inbound)
        let item = try createItem(type: .email, title: title, occurredAt: occurredAt, source: .import, status: .ready)
        do {
            if let original {
                try storeAsset(original, itemID: item.id, kind: .originalEmail, fileName: "original.eml")
            }
            let markdown = Self.markdown(input, title: title)
            try storeAsset(Data(markdown.utf8), itemID: item.id, kind: .contentMD, fileName: "content.md")
            try indexDocument(markdown, itemID: item.id)
            let writer = self.writer
            try database.writer.write { db in
                var meta = EmailMeta(
                    itemId: item.id, direction: direction, fromAddr: input.from?.address.lowercased(),
                    fromName: input.from?.name, toAddrs: EmailMeta.encode(input.to),
                    ccAddrs: EmailMeta.encode(input.cc),
                    subject: subject, sentAt: input.sentAt, messageId: input.messageID, inReplyTo: input.inReplyTo,
                    refs: input.references.isEmpty
                        ? nil : String(decoding: try JSONEncoder().encode(input.references), as: UTF8.self),
                    threadId: nil)
                meta.threadId = try thread(for: meta, references: input.references, writer: writer, db)
                try meta.insert(db)
            }
        } catch {
            try? purgeItem(item.id)
            throw error
        }
        return item
    }

    /// Joins the thread of the message this one answers (or of any referenced one) and links the reply; emails
    /// already in the archive that answer this one join its thread (FR-183).
    private func thread(for meta: EmailMeta, references: [String], writer: SyncWriter, _ db: Database) throws
        -> String
    {
        let candidates = ([meta.inReplyTo] + references.reversed()).compactMap { $0 }
        var threadID = meta.messageId ?? meta.itemId
        for id in candidates {
            if let parent = try EmailMeta.filter(Column("message_id") == id).fetchOne(db),
                try Item.filter(key: parent.itemId).filter(Column("deleted_at") == nil).fetchCount(db) > 0
            {
                threadID = parent.threadId ?? parent.messageId ?? parent.itemId
                try link(meta.itemId, to: parent.itemId, kind: .replyTo, origin: .thread, writer: writer, db)
                break
            }
        }
        if let messageID = meta.messageId {
            for var child in try EmailMeta.filter(Column("in_reply_to") == messageID).fetchAll(db) {
                let oldThread = child.threadId
                try link(child.itemId, to: meta.itemId, kind: .replyTo, origin: .thread, writer: writer, db)
                // The whole thread the reply started moves into this one.
                if let oldThread {
                    try db.execute(
                        sql: "UPDATE email_meta SET thread_id = ? WHERE thread_id = ?",
                        arguments: [threadID, oldThread])
                }
                child.threadId = threadID
                try child.update(db)
            }
        }
        return threadID
    }

    public func emailMeta(itemID: String) throws -> EmailMeta? {
        try database.writer.read { db in try EmailMeta.fetchOne(db, key: itemID) }
    }

    public func setEmailDirection(_ itemID: String, _ direction: EmailMeta.Direction) throws {
        try database.writer.write { db in
            try db.execute(
                sql: "UPDATE email_meta SET direction = ? WHERE item_id = ?", arguments: [direction.rawValue, itemID])
        }
    }

    /// Emails of the same conversation, oldest first (the item itself included).
    public func thread(itemID: String) throws -> [Item] {
        try database.writer.read { db in
            guard let threadID = try EmailMeta.fetchOne(db, key: itemID)?.threadId else { return [] }
            return try Item.fetchAll(
                db,
                sql: """
                    SELECT item.* FROM item JOIN email_meta ON email_meta.item_id = item.id
                    WHERE email_meta.thread_id = ? AND item.deleted_at IS NULL AND item.trashed_at IS NULL
                    ORDER BY item.occurred_at
                    """, arguments: [threadID])
        }
    }

    /// Email metadata of many items at once (list and timeline rows).
    public func emailMetas(itemIDs: [String]) throws -> [String: EmailMeta] {
        try database.writer.read { db in
            Dictionary(
                uniqueKeysWithValues: try EmailMeta.filter(itemIDs.contains(Column("item_id"))).fetchAll(db).map {
                    ($0.itemId, $0)
                })
        }
    }

    static let titleDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    /// The Markdown kept for an email: headers, then the body.
    /// A better conversion of the body of an email already in the archive: the header lines stay, the body is
    /// replaced and indexed again. Emails whose text the user corrected (FR-191) are left alone.
    @discardableResult
    public func refreshEmailBody(itemID: String, body: String) throws -> Bool {
        let assets = try assets(itemID: itemID)
        guard !assets.contains(where: { $0.kind == .contentMDAuto }),
            let asset = assets.first(where: { $0.kind == .contentMD })
        else { return false }
        let current = String(decoding: try readAssetData(asset), as: UTF8.self)
        let lines = current.components(separatedBy: "\n")
        let headers = ["**Da:**", "**A:**", "**Cc:**", "**Data:**"]
        var end = 1
        while end < lines.count, lines[end].isEmpty || headers.contains(where: lines[end].hasPrefix) { end += 1 }
        let updated = (lines[..<min(end, lines.count)] + [body]).joined(separator: "\n")
        guard updated != current else { return false }
        try storeAsset(Data(updated.utf8), itemID: itemID, kind: .contentMD, fileName: "content.md")
        try indexDocument(updated, itemID: itemID)
        return true
    }

    static func markdown(_ input: EmailInput, title: String) -> String {
        func list(_ addresses: [EmailMeta.Address]) -> String {
            addresses.map { entry in entry.name.map { "\($0) <\(entry.address)>" } ?? entry.address }
                .joined(separator: ", ")
        }
        var lines = ["# \(title)", ""]
        if let from = input.from { lines.append("**Da:** \(list([from]))  ") }
        if !input.to.isEmpty { lines.append("**A:** \(list(input.to))  ") }
        if !input.cc.isEmpty { lines.append("**Cc:** \(list(input.cc))  ") }
        if let sent = input.sentAt { lines.append("**Data:** \(titleDate.string(from: sent))  ") }
        lines.append("")
        lines.append(input.bodyMarkdown)
        return lines.joined(separator: "\n")
    }

    // MARK: Classification of incoming emails

    /// True if an email with this Message-ID is already in the archive (a second import is skipped).
    public func emailExists(messageID: String) throws -> Bool {
        try database.writer.read { db in
            try Int.fetchOne(
                db,
                sql: """
                    SELECT count(*) FROM email_meta JOIN item ON item.id = email_meta.item_id
                    WHERE email_meta.message_id = ? AND item.deleted_at IS NULL
                    """, arguments: [messageID]) ?? 0 > 0
        }
    }

    /// Project and streams proposed for an email, from local clues only, strongest first: the conversation
    /// it belongs to, a known person, a client's domain, the name of a project or client in the subject.
    public func classifyEmail(
        addresses: [String], subject: String?, inReplyTo: String?, references: [String]
    ) throws -> EmailClassification {
        // 1. Same conversation as an email already filed.
        let ids = ([inReplyTo] + references.reversed()).compactMap { $0 }
        if !ids.isEmpty {
            let parent = try database.writer.read { db -> (Item, [String])? in
                for id in ids {
                    guard let meta = try EmailMeta.filter(Column("message_id") == id).fetchOne(db),
                        let item = try Item.filter(key: meta.itemId)
                            .filter(Column("deleted_at") == nil && Column("project_id") != nil).fetchOne(db)
                    else { continue }
                    let streams = try String.fetchAll(
                        db, sql: "SELECT stream_id FROM item_stream WHERE item_id = ?", arguments: [item.id])
                    return (item, streams)
                }
                return nil
            }
            if let (item, streams) = parent {
                return EmailClassification(
                    projectID: item.projectId, clientID: nil, streamIDs: streams,
                    reason: .conversation(item.title), confident: true)
            }
        }
        let projects = try projects()
        func projectsOf(_ clientID: String) -> [Project] { projects.filter { $0.clientId == clientID } }
        // 2–3. Known people and client domains.
        if let suggestion = try projectSuggestions(for: addresses).first {
            let reason = EmailClassification.Reason.people(suggestion.people)
            if let projectID = suggestion.projectID {
                return EmailClassification(
                    projectID: projectID, clientID: nil, streamIDs: [], reason: reason, confident: true)
            }
            if let clientID = suggestion.clientID {
                let candidates = projectsOf(clientID)
                if candidates.count == 1 {
                    return EmailClassification(
                        projectID: candidates[0].id, clientID: clientID, streamIDs: [], reason: reason, confident: true)
                }
                // Several projects: the subject may tell which one.
                if let byName = Self.projectNamed(in: subject, among: candidates) {
                    return EmailClassification(
                        projectID: byName.id, clientID: clientID, streamIDs: [], reason: reason, confident: true)
                }
                return EmailClassification(
                    projectID: nil, clientID: clientID, streamIDs: [], reason: reason, confident: false)
            }
        }
        // 4. A project or client named in the subject.
        if let project = Self.projectNamed(in: subject, among: projects) {
            return EmailClassification(
                projectID: project.id, clientID: project.clientId, streamIDs: [], reason: .subject(project.name),
                confident: false)
        }
        if let subject {
            let normalized = TagNormalizer.normalize(subject)
            for client in try clients() where client.name.count >= 3 {
                if normalized.contains(TagNormalizer.normalize(client.name)) {
                    let candidates = projectsOf(client.id)
                    return EmailClassification(
                        projectID: candidates.count == 1 ? candidates[0].id : nil, clientID: client.id, streamIDs: [],
                        reason: .subject(client.name), confident: false)
                }
            }
        }
        return EmailClassification(projectID: nil, clientID: nil, streamIDs: [], reason: .none, confident: false)
    }

    /// The project whose whole name appears in the subject (the longest one if several do).
    static func projectNamed(in subject: String?, among projects: [Project]) -> Project? {
        guard let subject else { return nil }
        let normalized = " " + TagNormalizer.normalize(subject) + " "
        return projects.filter { $0.name.count >= 3 }
            .filter { normalized.contains(TagNormalizer.normalize($0.name)) }
            .max { $0.name.count < $1.name.count }
    }

    // MARK: Links (FR-201)

    @discardableResult
    public func addLink(from: String, to: String, kind: ItemLink.Kind, origin: ItemLink.Origin = .manual) throws
        -> ItemLink?
    {
        let writer = self.writer
        return try database.writer.write { db in
            try link(from, to: to, kind: kind, origin: origin, writer: writer, db)
        }
    }

    @discardableResult
    private func link(
        _ from: String, to: String, kind: ItemLink.Kind, origin: ItemLink.Origin, writer: SyncWriter, _ db: Database
    ) throws -> ItemLink? {
        guard from != to else { return nil }
        let existing = try ItemLink.filter(
            Column("deleted_at") == nil
                && ((Column("from_item_id") == from && Column("to_item_id") == to)
                    || (Column("from_item_id") == to && Column("to_item_id") == from))
        ).fetchOne(db)
        if let existing { return existing }
        var link = ItemLink(id: newID(at: writer.now), fromItemId: from, toItemId: to, kind: kind, origin: origin)
        try writer.save(&link, db)
        return link
    }

    public func removeLink(_ id: String) throws {
        let writer = self.writer
        try database.writer.write { db in
            var link = try Self.require(ItemLink.fetchOne(db, key: id), id)
            try writer.tombstone(&link, db)
        }
    }

    /// Links of an item in both directions, to items still alive.
    public func links(itemID: String) throws -> [LinkedItem] {
        try database.writer.read { db in
            let links = try ItemLink.filter(
                Column("deleted_at") == nil && (Column("from_item_id") == itemID || Column("to_item_id") == itemID)
            ).fetchAll(db)
            return try links.compactMap { link in
                let outgoing = link.fromItemId == itemID
                let otherID = outgoing ? link.toItemId : link.fromItemId
                guard
                    let other = try Item.filter(key: otherID)
                        .filter(Column("deleted_at") == nil && Column("trashed_at") == nil).fetchOne(db)
                else { return nil }
                return LinkedItem(link: link, item: other, outgoing: outgoing)
            }
            .sorted { $0.item.occurredAt < $1.item.occurredAt }
        }
    }

    /// Links are removed with the item when it is deleted for good.
    func removeLinks(itemID: String, writer: SyncWriter, _ db: Database) throws {
        for var link in try ItemLink.filter(
            Column("deleted_at") == nil && (Column("from_item_id") == itemID || Column("to_item_id") == itemID)
        ).fetchAll(db) {
            try writer.tombstone(&link, db)
        }
        try db.execute(sql: "DELETE FROM email_meta WHERE item_id = ?", arguments: [itemID])
    }

    // MARK: People with a role (ADR-0040)

    /// Contacts of a client or a project; both nil: the user's own organization.
    public func contacts(clientID: String? = nil, projectID: String? = nil) throws -> [ContactSummary] {
        try database.writer.read { db in
            var request = Contact.filter(Column("deleted_at") == nil)
            request = request.filter(clientID == nil ? Column("client_id") == nil : Column("client_id") == clientID)
            request = request.filter(projectID == nil ? Column("project_id") == nil : Column("project_id") == projectID)
            return try request.fetchAll(db).compactMap { try summarize($0, db) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    /// Adds a person; the name becomes (or reuses) a person entity, so it is suggested on decisions too.
    @discardableResult
    public func addContact(
        name: String, email: String?, role: Contact.Role, clientID: String? = nil, projectID: String? = nil
    ) throws -> Contact {
        let writer = self.writer
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = TagNormalizer.normalize(trimmed)
        return try database.writer.write { db in
            var entity: Entity
            if let existing = try Entity.filter(
                Column("type") == Entity.Kind.person.rawValue && Column("normalized") == normalized
            ).fetchOne(db) {
                entity = existing
                if entity.deletedAt != nil {
                    entity.deletedAt = nil
                    try writer.save(&entity, db)
                }
            } else {
                entity = Entity(id: newID(at: writer.now), type: .person, name: trimmed, normalized: normalized)
                try writer.save(&entity, db)
            }
            var contact = Contact(
                id: newID(at: writer.now), entityId: entity.id,
                email: email.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.flatMap {
                    $0.isEmpty ? nil : $0
                }, role: role, clientId: clientID, projectId: projectID)
            try writer.save(&contact, db)
            return contact
        }
    }

    public func updateContact(_ id: String, name: String?, email: String?, role: Contact.Role?) throws {
        let writer = self.writer
        try database.writer.write { db in
            var contact = try Self.require(Contact.fetchOne(db, key: id), id)
            if let email { contact.email = email.isEmpty ? nil : email.lowercased() }
            if let role { contact.role = role }
            try writer.save(&contact, db)
            if let name, var entity = try Entity.fetchOne(db, key: contact.entityId) {
                entity.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                entity.normalized = TagNormalizer.normalize(entity.name)
                try writer.save(&entity, db)
            }
        }
    }

    public func deleteContact(_ id: String) throws {
        let writer = self.writer
        try database.writer.write { db in
            var contact = try Self.require(Contact.fetchOne(db, key: id), id)
            contact.email = nil
            try writer.tombstone(&contact, db)
        }
    }

    /// Known people among these addresses, with where they belong.
    public func contacts(matching addresses: [String]) throws -> [ContactSummary] {
        let wanted = addresses.map { $0.lowercased() }
        return try database.writer.read { db in
            try Contact.filter(Column("deleted_at") == nil && wanted.contains(Column("email"))).fetchAll(db)
                .compactMap { try summarize($0, db) }
        }
    }

    /// Projects (or clients) the people of an email belong to, best first: clients and suppliers count,
    /// the user's colleagues do not tell which project it is.
    public func projectSuggestions(for addresses: [String]) throws -> [ProjectSuggestion] {
        let matches = try contacts(matching: addresses).filter { $0.contact.role != .internal }
        var byTarget: [String: ProjectSuggestion] = [:]
        // Addresses of a client's domain point to the client, unless the person is known by name.
        let named = Set(matches.compactMap(\.contact.email))
        for rule in try domainRules() where rule.role == .client && rule.clientID != nil {
            let hits = addresses.map { $0.lowercased() }.filter { !named.contains($0) && rule.matches($0) }
            guard !hits.isEmpty, let clientID = rule.clientID else { continue }
            var suggestion =
                byTarget["c:\(clientID)"] ?? ProjectSuggestion(projectID: nil, clientID: clientID, people: [])
            suggestion.people += hits.filter { !suggestion.people.contains($0) }
            byTarget["c:\(clientID)"] = suggestion
        }
        for match in matches {
            let key = match.contact.projectId.map { "p:\($0)" } ?? match.contact.clientId.map { "c:\($0)" }
            guard let key else { continue }
            var suggestion =
                byTarget[key]
                ?? ProjectSuggestion(projectID: match.contact.projectId, clientID: match.contact.clientId, people: [])
            if !suggestion.people.contains(match.name) { suggestion.people.append(match.name) }
            byTarget[key] = suggestion
        }
        return byTarget.values.sorted { $0.people.count > $1.people.count }
    }

    private func summarize(_ contact: Contact, _ db: Database) throws -> ContactSummary? {
        guard let entity = try Entity.fetchOne(db, key: contact.entityId) else { return nil }
        return ContactSummary(contact: contact, name: entity.name)
    }
}
