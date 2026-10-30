import Foundation
import GRDB

/// Whether two names may be the same person, before a speaker is named (FR-41): "Marco" and "Marco Rossi", a typo
/// ("Marco Rosi"), a nickname ("Lello" and "Antonello", "Peppe" and "Giuseppe"). Only a question to the user: it never
/// renames anyone by itself.
public enum PersonNameMatcher {
    /// Common Italian nicknames, by the full name (normalized: lowercase, no accents). The ones the user teaches IAGO
    /// are in `name_alias`.
    static let nicknames: [String: [String]] = [
        "alberto": ["albi", "berto"], "alessandra": ["ale", "sandra"], "alessandro": ["ale", "alex", "sandro"],
        "antonella": ["anto", "nella"], "antonello": ["lello", "nello"], "antonio": ["toni", "tonino", "toto"],
        "beatrice": ["bea"], "benedetta": ["bene"], "caterina": ["cate", "rina"], "claudia": ["clau"],
        "claudio": ["clau"], "cristiano": ["cri"], "cristina": ["cri", "cris"], "daniele": ["dani", "lele"],
        "domenico": ["mimmo", "mimi", "nico"], "edoardo": ["edo"], "eleonora": ["ele", "nora"],
        "elisabetta": ["betta", "elisa", "lisa"], "emanuela": ["manu"], "emanuele": ["lele", "manu"],
        "fabrizio": ["fabri", "bicio"], "federica": ["fede"], "federico": ["fede", "chicco"],
        "filippo": ["pippo", "filo"], "francesca": ["franci", "cesca"],
        "francesco": ["ciccio", "checco", "franci", "cesco"], "gabriele": ["lele", "gabri"],
        "gabriella": ["gabri", "ella"], "gianfranco": ["franco"], "giovanna": ["gianna", "vanna"],
        "giovanni": ["gianni", "vanni", "nanni", "gio"], "giuseppe": ["peppe", "beppe", "pino", "peppino", "bepi"],
        "giuseppina": ["pina"], "guglielmo": ["memo"], "leonardo": ["leo"], "lorenzo": ["lollo", "enzo"],
        "luigi": ["gigi", "gino"], "margherita": ["marghe", "rita"], "massimiliano": ["max", "massi"],
        "massimo": ["max"], "matteo": ["teo"], "maurizio": ["mauri"], "michele": ["miki", "michi"],
        "nicola": ["nico", "nick"], "nicoletta": ["nico"], "pasquale": ["lino", "pasqui"],
        "patrizia": ["patty", "pat"], "pierluigi": ["gigi"], "raffaele": ["lello", "raffa"],
        "riccardo": ["ricky", "rick"], "roberta": ["robi"], "roberto": ["robi", "berto", "rob"],
        "rosario": ["saro"], "salvatore": ["toto", "turi", "salva"], "simona": ["simo"], "simone": ["simo"],
        "stefano": ["ste", "stefo"], "teresa": ["tere"], "tommaso": ["tommy", "tom"], "umberto": ["berto"],
        "valentina": ["vale"], "vincenzo": ["enzo", "vince"], "vittoria": ["vicky"],
        "vittorio": ["vitto"],
    ]

    /// Every name a nickname or a full name goes with, both ways.
    static let related: [String: Set<String>] = {
        var map: [String: Set<String>] = [:]
        for (full, short) in nicknames {
            for nick in short {
                map[full, default: []].insert(nick)
                map[nick, default: []].insert(full)
            }
        }
        return map
    }()

    static func words(_ name: String) -> [String] {
        TagNormalizer.normalize(name).map { $0.isLetter ? $0 : " " }.reduce(into: "") { $0.append($1) }
            .split(separator: " ").map(String.init)
    }

    public static func isSimilar(_ a: String, _ b: String) -> Bool {
        let wa = words(a)
        let wb = words(b)
        guard !wa.isEmpty, !wb.isEmpty else { return false }
        let ja = wa.joined(separator: " ")
        let jb = wb.joined(separator: " ")
        if ja == jb { return true }
        // A typo in a long enough name ("Marco Rosi"); in a short one it is another name ("Mario", "Marco").
        if TagNormalizer.editDistance(ja, jb) <= min(ja.count, jb.count) / 6 { return true }
        // One name inside the other ("Marco" / "Marco Rossi").
        if Set(wa).isSubset(of: wb) || Set(wb).isSubset(of: wa) { return true }
        // A word in common alone is not enough: "Anna Rossi" is not "Marco Rossi".
        for x in wa {
            for y in wb where x != y {
                if related[x]?.contains(y) == true { return true }
                // A short form of the same name: "Ale" / "Alessandro", "Sandro" / "Alessandro", "Nello" / "Antonello".
                let (short, long) = x.count < y.count ? (x, y) : (y, x)
                if short.count >= 3, long.hasPrefix(short) { return true }
                if short.count >= 4, long.hasSuffix(short) { return true }
            }
        }
        return false
    }
}

// MARK: - Speakers: names, nicknames, joined speakers

extension Archive {
    /// The names already given to people: people of the archive and speakers named in the calls.
    public func knownPersonNames() throws -> [String] {
        let labels = try database.writer.read { db in
            try String.fetchAll(db, sql: "SELECT DISTINCT label FROM item_speaker")
        }
        var seen = Set<String>()
        return (try people().map(\.name) + labels.filter(Self.isVoiceName)).filter {
            seen.insert(TagNormalizer.normalize($0)).inserted
        }
    }

    /// The name the user said `name` stands for ("Lello" → "Antonello"); nil if they never did.
    public func nameAlias(_ name: String) throws -> String? {
        try database.writer.read { db in
            try String.fetchOne(
                db, sql: "SELECT name FROM name_alias WHERE alias = ?", arguments: [TagNormalizer.normalize(name)])
        }
    }

    /// The user said `alias` is `name`: the next time "Lello" is typed, IAGO proposes "Antonello" at once.
    public func setNameAlias(_ alias: String, for name: String) throws {
        let key = TagNormalizer.normalize(alias)
        guard !key.isEmpty, key != TagNormalizer.normalize(name) else { return }
        let now = self.now()
        try database.writer.write { db in
            try db.execute(
                sql: "INSERT INTO name_alias (alias, name, created_at) VALUES (?, ?, ?) "
                    + "ON CONFLICT(alias) DO UPDATE SET name = excluded.name",
                arguments: [key, name.trimmingCharacters(in: .whitespaces), now])
        }
    }

    /// Names already known that may be the person typed: the one the user tied to it first, then the similar ones.
    /// Never the name itself.
    public func similarPersonNames(to name: String) throws -> [String] {
        let wanted = TagNormalizer.normalize(name)
        guard !wanted.isEmpty else { return [] }
        if let alias = try nameAlias(name), TagNormalizer.normalize(alias) != wanted { return [alias] }
        return try knownPersonNames().filter {
            TagNormalizer.normalize($0) != wanted && PersonNameMatcher.isSimilar($0, name)
        }
        .prefix(3).map { $0 }
    }

    /// "Unisci": `speakerID` is the same person as `target` in this call. It takes its name and its voice; the
    /// transcript is not rewritten (spec 7.3), and "Separa" undoes it.
    public func mergeSpeaker(_ speakerID: String, into target: String, of itemID: String) throws {
        guard speakerID != target else { return }
        let now = self.now()
        try database.writer.write { db in
            let label =
                try String.fetchOne(
                    db, sql: "SELECT label FROM item_speaker WHERE item_id = ? AND speaker_id = ?",
                    arguments: [itemID, target]) ?? target
            // Speakers already joined to the one being joined follow it to the target.
            try db.execute(
                sql: "UPDATE item_speaker SET merged_into = ?, label = ? WHERE item_id = ? "
                    + "AND (speaker_id = ? OR merged_into = ?)",
                arguments: [target, label, itemID, speakerID, speakerID])
            for joined in try String.fetchAll(
                db, sql: "SELECT speaker_id FROM item_speaker WHERE item_id = ? AND merged_into = ?",
                arguments: [itemID, target])
            {
                try Self.linkVoice(itemID: itemID, speakerID: joined, label: label, now: now, db)
            }
            try ChangeLog.append(
                db, table: "item_speaker", rowID: "\(itemID)/\(speakerID)", op: .update, version: 0, at: now)
        }
    }

    /// "Separa": the speaker is on its own again, with the label it had from the transcription.
    public func separateSpeaker(_ speakerID: String, of itemID: String, label: String) throws {
        let now = self.now()
        try database.writer.write { db in
            try db.execute(
                sql: "UPDATE item_speaker SET merged_into = NULL, label = ? WHERE item_id = ? AND speaker_id = ?",
                arguments: [label, itemID, speakerID])
            try Self.linkVoice(itemID: itemID, speakerID: speakerID, label: label, now: now, db)
            try ChangeLog.append(
                db, table: "item_speaker", rowID: "\(itemID)/\(speakerID)", op: .update, version: 0, at: now)
        }
    }
}

/// «Persone presenti» (ADR-0031): who was at a meeting, in the order the user wrote them. They are offered as names
/// for the speakers, and they are not linked to the voices until the user names a speaker.
extension Archive {
    public func attendees(itemID: String) throws -> [String] {
        try database.writer.read { db in
            try String.fetchAll(
                db, sql: "SELECT name FROM item_attendee WHERE item_id = ? ORDER BY position", arguments: [itemID])
        }
    }

    /// Replaces the list. A name written like one IAGO already knows takes the known spelling; repeats go.
    public func setAttendees(_ names: [String], itemID: String) throws {
        let known = Dictionary(
            try knownPersonNames().map { (TagNormalizer.normalize($0), $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        let cleaned = names.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            .map { known[TagNormalizer.normalize($0)] ?? $0 }
            .filter { seen.insert(TagNormalizer.normalize($0)).inserted }
        let now = self.now()
        try database.writer.write { db in
            try db.execute(sql: "DELETE FROM item_attendee WHERE item_id = ?", arguments: [itemID])
            for (position, name) in cleaned.enumerated() {
                try db.execute(
                    sql: "INSERT INTO item_attendee (item_id, name, position, created_at) VALUES (?, ?, ?, ?)",
                    arguments: [itemID, name, position, now])
            }
        }
    }
}
