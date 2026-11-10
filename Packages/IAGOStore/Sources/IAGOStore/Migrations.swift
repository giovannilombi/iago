import GRDB

/// Schema migrations (spec 8.2, 8.4). Phase 1 creates only the tables it uses; later phases add theirs
/// with new migrations, never by editing a shipped one.
enum Migrations {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1", migrate: v1)
        migrator.registerMigration("v2-discarded") { db in
            // ADR-0032: "Scarta" during a recording; 'discarded' items are deleted for good after 1 hour.
            try db.alter(table: "item") { t in t.add(column: "trash_reason", .text) }
        }
        migrator.registerMigration("v3-project-pin") { db in
            // Pinned projects stay on top; the others are ordered by last use (most recent first).
            try db.alter(table: "project") { t in
                t.add(column: "pinned", .boolean).notNull().defaults(to: false)
                t.add(column: "last_used_at", .datetime)
            }
        }
        migrator.registerMigration("v4-attachments") { db in
            try db.alter(table: "asset") { t in
                t.add(column: "note_id", .text).references("note")
                t.add(column: "original_name", .text)
            }
        }
        migrator.registerMigration("v5-search") { db in
            // ADR-0036: full-text index of transcripts, notes and documents (passage level).
            try db.create(virtualTable: "search_index", using: FTS5()) { t in
                t.tokenizer = .unicode61(diacritics: .remove)
                t.column("item_id").notIndexed()
                t.column("project_id").notIndexed()
                t.column("source").notIndexed()
                t.column("source_id").notIndexed()
                t.column("at_sec").notIndexed()
                t.column("text")
            }
        }
        migrator.registerMigration("v6-decisions") { db in
            // ADR-0037: decision register (FR-150…157) and the people it involves. `entity` is the phase-3
            // table of spec 8.4, created now with only people typed by the user.
            try db.create(table: "entity") { t in
                t.primaryKey("id", .text)
                t.column("type", .text).notNull()  // person | organization | topic
                t.column("name", .text).notNull()
                t.column("normalized", .text).notNull()
                syncColumns(t)
            }
            try db.create(index: "entity_normalized", on: "entity", columns: ["type", "normalized"])
            try db.create(table: "decision") { t in
                t.primaryKey("id", .text)
                t.column("kind", .text).notNull().defaults(to: "decision")
                t.column("text", .text).notNull()
                t.column("decided_at", .datetime).notNull()
                t.column("project_id", .text).references("project")
                t.column("source_item_id", .text).references("item")
                t.column("source_at_sec", .double)
                t.column("source_note_id", .text).references("note")
                t.column("status", .text).notNull().defaults(to: "active")
                t.column("supersedes_id", .text).references("decision")
                t.column("origin", .text).notNull()
                t.column("notes", .text)
                t.column("shared", .boolean).notNull().defaults(to: false)
                syncColumns(t)
            }
            try db.create(index: "decision_project", on: "decision", columns: ["project_id"])
            try db.create(index: "decision_source_item", on: "decision", columns: ["source_item_id"])
            try db.create(table: "decision_entity") { t in
                t.column("decision_id", .text).notNull().references("decision")
                t.column("entity_id", .text).notNull().references("entity")
                t.primaryKey(["decision_id", "entity_id"])
            }
            try db.create(table: "decision_tag") { t in
                t.column("decision_id", .text).notNull().references("decision")
                t.column("tag_id", .text).notNull().references("tag")
                t.primaryKey(["decision_id", "tag_id"])
            }
        }
        migrator.registerMigration("v7-hierarchy") { db in
            // ADR-0038: clients group projects; streams split a project. An item or a decision can be in
            // several streams of its project.
            try db.create(table: "client") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("color", .text)
                t.column("archived", .boolean).notNull().defaults(to: false)
                syncColumns(t)
            }
            try db.alter(table: "project") { t in t.add(column: "client_id", .text).references("client") }
            try db.create(table: "stream") { t in
                t.primaryKey("id", .text)
                t.column("project_id", .text).notNull().references("project")
                t.column("name", .text).notNull()
                t.column("color", .text)
                t.column("sort_order", .integer).notNull().defaults(to: 0)
                t.column("archived", .boolean).notNull().defaults(to: false)
                syncColumns(t)
            }
            try db.create(index: "stream_project", on: "stream", columns: ["project_id"])
            try db.create(table: "item_stream") { t in
                t.column("item_id", .text).notNull().references("item")
                t.column("stream_id", .text).notNull().references("stream")
                t.primaryKey(["item_id", "stream_id"])
            }
            try db.create(table: "decision_stream") { t in
                t.column("decision_id", .text).notNull().references("decision")
                t.column("stream_id", .text).notNull().references("stream")
                t.primaryKey(["decision_id", "stream_id"])
            }
        }
        migrator.registerMigration("v8-asset-owner") { db in
            // ADR-0039: an asset belongs to an item or, for attachments of project notes, to a project.
            // `item_id` stays the owner id but loses its foreign key to `item` (SQLite needs a table rebuild).
            try db.create(table: "asset_v8") { t in
                t.primaryKey("id", .text)
                t.column("item_id", .text).notNull()
                t.column("kind", .text).notNull()
                t.column("rel_path", .text).notNull()
                t.column("size_bytes", .integer)
                t.column("sha256", .text)
                t.column("trashed_at", .datetime)
                syncColumns(t)
                t.column("note_id", .text).references("note")
                t.column("original_name", .text)
            }
            try db.execute(
                sql: """
                    INSERT INTO asset_v8 (id, item_id, kind, rel_path, size_bytes, sha256, trashed_at, created_at,
                        updated_at, deleted_at, version, device_id, note_id, original_name)
                    SELECT id, item_id, kind, rel_path, size_bytes, sha256, trashed_at, created_at, updated_at,
                        deleted_at, version, device_id, note_id, original_name FROM asset
                    """)
            try db.drop(table: "asset")
            try db.rename(table: "asset_v8", to: "asset")
            try db.create(index: "asset_item", on: "asset", columns: ["item_id"])
        }
        migrator.registerMigration("v9-email") { db in
            // ADR-0040: email metadata and threads, links between items, people with a role.
            try db.create(table: "email_meta") { t in
                t.primaryKey("item_id", .text).references("item")
                t.column("direction", .text).notNull()  // inbound | outbound
                t.column("from_addr", .text)
                t.column("from_name", .text)
                t.column("to_addrs", .text)  // JSON array of {name, address}
                t.column("cc_addrs", .text)
                t.column("subject", .text)
                t.column("sent_at", .datetime)
                t.column("message_id", .text)
                t.column("in_reply_to", .text)
                t.column("refs", .text)  // JSON array
                t.column("thread_id", .text)
            }
            try db.create(index: "email_message_id", on: "email_meta", columns: ["message_id"])
            try db.create(index: "email_thread", on: "email_meta", columns: ["thread_id"])
            try db.create(table: "item_link") { t in
                t.primaryKey("id", .text)
                t.column("from_item_id", .text).notNull().references("item")
                t.column("to_item_id", .text).notNull().references("item")
                t.column("kind", .text).notNull()  // follow_up_of | attachment_of | reply_to | related
                t.column("origin", .text).notNull()  // manual | thread | attachment | suggestion
                syncColumns(t)
            }
            try db.create(index: "item_link_from", on: "item_link", columns: ["from_item_id"])
            try db.create(index: "item_link_to", on: "item_link", columns: ["to_item_id"])
            // People of a client or project (or of the user's own organization when both are null).
            try db.create(table: "contact") { t in
                t.primaryKey("id", .text)
                t.column("entity_id", .text).notNull().references("entity")
                t.column("email", .text)
                t.column("role", .text).notNull()  // internal | client | supplier
                t.column("client_id", .text).references("client")
                t.column("project_id", .text).references("project")
                syncColumns(t)
            }
            try db.create(index: "contact_email", on: "contact", columns: ["email"])
        }
        migrator.registerMigration("v10-decision-chain-name") { db in
            // Optional name of a chain of decisions, kept on its first decision (ADR-0037).
            try db.alter(table: "decision") { t in t.add(column: "chain_name", .text) }
        }
        migrator.registerMigration("v11-mcp-write") { db in
            // ADR-0044: Claude may write only where the user allows it; every write can be undone.
            try db.alter(table: "project") { t in
                t.add(column: "claude_writable", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "mcp_change") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("at", .datetime).notNull()
                t.column("entity", .text).notNull()
                t.column("entity_id", .text).notNull()
                t.column("action", .text).notNull()
                t.column("previous", .text)
                t.column("undone_at", .datetime)
            }
            try db.create(index: "mcp_change_entity", on: "mcp_change", columns: ["entity", "entity_id"])
        }
        migrator.registerMigration("v12-note-stream") { db in
            // ADR-0047: a note can belong to streams of its project, like items and decisions.
            try db.create(table: "note_stream") { t in
                t.column("note_id", .text).notNull().references("note")
                t.column("stream_id", .text).notNull().references("stream")
                t.primaryKey(["note_id", "stream_id"])
            }
            try db.create(index: "note_stream_stream", on: "note_stream", columns: ["stream_id"])
        }
        migrator.registerMigration("v13-intelligence") { db in
            // ADR-0049: chunks with their vectors for the search by meaning, and the engine's proposals.
            try db.create(table: "chunk") { t in
                t.primaryKey("id", .text)
                t.column("item_id", .text).references("item")
                t.column("note_id", .text).references("note")
                t.column("source", .text).notNull()
                t.column("start_sec", .double)
                t.column("end_sec", .double)
                t.column("speakers", .text)
                t.column("text", .text).notNull()
                t.column("model", .text).notNull()
                t.column("vector", .blob).notNull()
                t.column("created_at", .datetime).notNull()
            }
            try db.create(index: "chunk_item", on: "chunk", columns: ["item_id"])
            try db.create(index: "chunk_note", on: "chunk", columns: ["note_id"])
            try db.create(table: "suggestion") { t in
                t.primaryKey("id", .text)
                t.column("item_id", .text).notNull().references("item")
                t.column("kind", .text).notNull()
                t.column("payload", .text).notNull()
                t.column("status", .text).notNull().defaults(to: "pending")
                t.column("fingerprint", .text).notNull()
                t.column("model", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }
            try db.create(index: "suggestion_item", on: "suggestion", columns: ["item_id", "status"])
        }
        migrator.registerMigration("v14-conversations") { db in
            // ADR-0049 (amended): "Chiedi" conversations, temporary for 48 hours unless kept or pinned.
            try db.create(table: "conversation") { t in
                t.primaryKey("id", .text)
                t.column("scope_kind", .text).notNull()
                t.column("scope_id", .text)
                t.column("title", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("keep", .boolean).notNull().defaults(to: false)
                t.column("pinned", .boolean).notNull().defaults(to: false)
                t.column("expires_at", .datetime)
            }
            try db.create(table: "conversation_turn") { t in
                t.primaryKey("id", .text)
                t.column("conversation_id", .text).notNull().references("conversation", onDelete: .cascade)
                t.column("question", .text).notNull()
                t.column("answer", .text).notNull()
                t.column("sources", .text).notNull()
                t.column("model", .text).notNull()
                t.column("asked_at", .datetime).notNull()
            }
            try db.create(
                index: "conversation_turn_conversation", on: "conversation_turn", columns: ["conversation_id"])
        }
        migrator.registerMigration("v15-watched-folders") { db in
            // ADR-0050: folders of emails imported by delta, with the user's rules.
            try db.create(table: "watched_folder") { t in
                t.primaryKey("id", .text)
                t.column("path", .text).notNull().unique()
                t.column("enabled", .boolean).notNull().defaults(to: true)
                t.column("move_imported", .boolean).notNull().defaults(to: false)
                t.column("created_at", .datetime).notNull()
                t.column("last_scan_at", .datetime)
            }
            try db.create(table: "watched_file") { t in
                t.primaryKey("path", .text)
                t.column("folder_id", .text).notNull()
                t.column("size", .integer).notNull()
                t.column("modified_at", .datetime).notNull()
                t.column("sha256", .text).notNull()
                t.column("outcome", .text).notNull()
                t.column("reason", .text)
                t.column("subject", .text)
                t.column("item_id", .text)
                t.column("seen_at", .datetime).notNull()
            }
            try db.create(index: "watched_file_sha", on: "watched_file", columns: ["sha256"])
            try db.create(table: "import_rule") { t in
                t.primaryKey("id", .text)
                t.column("position", .integer).notNull()
                t.column("json", .text).notNull()
            }
        }
        migrator.registerMigration("v16-supersede-links") { db in
            // ADR-0052: an entry supersedes any number of entries, of any kind. Today's links are copied.
            try db.create(table: "decision_supersede") { t in
                t.column("newer_id", .text).notNull().references("decision")
                t.column("older_id", .text).notNull().references("decision")
                t.column("created_at", .datetime).notNull()
                t.primaryKey(["newer_id", "older_id"])
            }
            try db.create(index: "decision_supersede_older", on: "decision_supersede", columns: ["older_id"])
            try db.execute(
                sql: """
                    INSERT OR IGNORE INTO decision_supersede (newer_id, older_id, created_at)
                    SELECT id, supersedes_id, updated_at FROM decision
                    WHERE supersedes_id IS NOT NULL AND deleted_at IS NULL
                    """)
        }
        migrator.registerMigration("v17-summaries") { db in
            // ADR-0054: categories in families (main ones have none) with their summary template, and the summaries.
            try db.alter(table: "category") { t in
                t.add(column: "family", .text)
                t.add(column: "template_id", .text)
                t.add(column: "template_json", .text)
            }
            try db.create(table: "summary") { t in
                t.primaryKey("item_id", .text).references("item", onDelete: .cascade)
                t.column("category_id", .text)
                t.column("template_id", .text)
                t.column("markdown", .text).notNull()
                t.column("model", .text)
                t.column("edited", .boolean).notNull().defaults(to: false)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }
        }
        migrator.registerMigration("v18-provenance") { db in
            // ADR-0070: who produced each result. Summaries and proposals come from the local engine or from Claude;
            // a key point confirmed from a proposal keeps the model that proposed it.
            try db.alter(table: "summary") { t in t.add(column: "origin", .text).notNull().defaults(to: "engine") }
            try db.alter(table: "suggestion") { t in t.add(column: "origin", .text).notNull().defaults(to: "engine") }
            try db.alter(table: "decision") { t in t.add(column: "model", .text) }
        }
        migrator.registerMigration("v19-screenshots") { db in
            // ADR-0072: screenshots taken during a call, at their second, with the text read on them.
            try db.alter(table: "asset") { t in
                t.add(column: "at_sec", .double)
                t.add(column: "text", .text)
            }
        }
        migrator.registerMigration("v20-voices") { db in
            // ADR-0073: voice prints, only on this Mac and only when the user turns them on. Not synced, no
            // change log: biometric data never leaves the Mac.
            try db.create(table: "voice") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull().unique(onConflict: .abort).collate(.nocase)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }
            try db.create(table: "item_voice") { t in
                t.column("item_id", .text).notNull().references("item")
                t.column("speaker_id", .text).notNull()
                // The speaker's embedding, sealed with the item's key: it goes with the item (crypto-shredding).
                t.column("embedding", .blob).notNull()
                t.column("seconds", .double).notNull()
                t.column("voice_id", .text).references("voice", onDelete: .setNull)
                t.primaryKey(["item_id", "speaker_id"])
            }
            try db.create(index: "item_voice_voice", on: "item_voice", columns: ["voice_id"])
        }
        migrator.registerMigration("v21-work") { db in
            // ADR-0074: open work. Only additions: kinds and states are text, today's entries stay as they are.
            try db.alter(table: "decision") { t in
                t.add(column: "owner_id", .text)
                t.add(column: "due_at", .datetime)
                t.add(column: "waiting_on_id", .text)
                t.add(column: "waiting_until", .datetime)
                t.add(column: "priority", .integer)
                t.add(column: "starts_at", .datetime)
                t.add(column: "estimate", .text)
                t.add(column: "severity", .text)
                t.add(column: "happened_at", .datetime)
                t.add(column: "outcome", .text)
                t.add(column: "outcome_kind", .text)
                t.add(column: "derived_from_id", .text)
                t.add(column: "recurrence", .text)
                t.add(column: "closed_at", .datetime)
            }
            try db.execute(
                sql: "UPDATE decision SET closed_at = updated_at WHERE status IN ('done', 'superseded', 'cancelled')")
            try db.create(index: "decision_due", on: "decision", columns: ["due_at"])
            try db.create(index: "decision_owner", on: "decision", columns: ["owner_id"])
            // "Dipende da": blocked until the blocker is closed.
            try db.create(table: "decision_dependency") { t in
                t.column("blocked_id", .text).notNull().references("decision")
                t.column("blocker_id", .text).notNull().references("decision")
                t.column("created_at", .datetime).notNull()
                t.primaryKey(["blocked_id", "blocker_id"])
            }
            // Checklists: the sub-items of an activity, or named lists of a project.
            try db.create(table: "checklist") { t in
                t.primaryKey("id", .text)
                t.column("project_id", .text).notNull().references("project")
                t.column("name", .text).notNull()
                t.column("pinned", .boolean).notNull().defaults(to: true)
                t.column("sort_order", .integer).notNull().defaults(to: 0)
                syncColumns(t)
            }
            try db.create(table: "checklist_item") { t in
                t.primaryKey("id", .text)
                t.column("decision_id", .text).references("decision")
                t.column("checklist_id", .text).references("checklist")
                t.column("text", .text).notNull()
                t.column("done", .boolean).notNull().defaults(to: false)
                t.column("sort_order", .integer).notNull().defaults(to: 0)
                syncColumns(t)
                t.check(sql: "decision_id IS NOT NULL OR checklist_id IS NOT NULL")
            }
            try db.create(index: "checklist_item_decision", on: "checklist_item", columns: ["decision_id"])
            try db.create(index: "checklist_item_list", on: "checklist_item", columns: ["checklist_id"])
            // Free columns of a board (a project, a client, a stream, or every project), after the fixed ones.
            try db.create(table: "board_column") { t in
                t.primaryKey("id", .text)
                t.column("scope", .text).notNull()
                t.column("name", .text).notNull()
                t.column("sort_order", .integer).notNull().defaults(to: 0)
                syncColumns(t)
            }
            try db.create(table: "board_place") { t in
                t.column("scope", .text).notNull()
                t.column("decision_id", .text).notNull().references("decision")
                t.column("column_id", .text).notNull().references("board_column")
                t.primaryKey(["scope", "decision_id"])
            }
            // A project kept in "Traccia" while the app is in "Gestisci".
            try db.alter(table: "project") { t in t.add(column: "work_mode", .text) }
        }
        migrator.registerMigration("v22-speaker-names") { db in
            // FR-41: a speaker joined to another of the same call (the same person split in two); nil = on its own.
            try db.alter(table: "item_speaker") { t in t.add(column: "merged_into", .text) }
            // "Lello" is "Antonello": the names the user said are the same person, by their normalized form.
            try db.create(table: "name_alias") { t in
                t.primaryKey("alias", .text)
                t.column("name", .text).notNull()
                t.column("created_at", .datetime).notNull()
            }
        }
        migrator.registerMigration("v23-summary-transcript") { db in
            // ADR-0078: the transcript a summary was written from (`iago` or `teams`), shown when the main one changes.
            try db.alter(table: "summary") { t in t.add(column: "transcript_source", .text) }
        }
        migrator.registerMigration("v24-attendees") { db in
            // ADR-0031: who was at a meeting, said by the user when they want; offered as names for the speakers.
            try db.create(table: "item_attendee") { t in
                t.column("item_id", .text).notNull().references("item", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("position", .integer).notNull()
                t.column("created_at", .datetime).notNull()
                t.primaryKey(["item_id", "name"])
            }
        }
        migrator.registerMigration("v25-project-trash") { db in
            // ADR-0099: a project can go to the trash for 30 days before being deleted for good.
            try db.alter(table: "project") { t in t.add(column: "trashed_at", .datetime) }
        }
        return migrator
    }

    /// Sync columns of every user table (spec 8.1).
    private static func syncColumns(_ t: TableDefinition) {
        t.column("created_at", .datetime).notNull()
        t.column("updated_at", .datetime).notNull()
        t.column("deleted_at", .datetime)
        t.column("version", .integer).notNull().defaults(to: 1)
        t.column("device_id", .text).notNull()
    }

    private static func v1(_ db: Database) throws {
        try db.create(table: "project") { t in
            t.primaryKey("id", .text)
            t.column("name", .text).notNull()
            t.column("color", .text)
            t.column("archived", .boolean).notNull().defaults(to: false)
            t.column("claude_accessible", .boolean).notNull().defaults(to: false)  // FR-131
            t.column("sharing_enabled", .boolean).notNull().defaults(to: false)  // phase 4
            syncColumns(t)
        }
        try db.create(table: "category") { t in
            t.primaryKey("id", .text)
            t.column("name", .text).notNull()
            t.column("color", .text)
            t.column("sort_order", .integer).notNull().defaults(to: 0)
            t.column("is_builtin", .boolean).notNull().defaults(to: false)
            t.column("archived", .boolean).notNull().defaults(to: false)
            syncColumns(t)
        }
        try db.create(table: "tag") { t in
            t.primaryKey("id", .text)
            t.column("name", .text).notNull()
            t.column("normalized", .text).notNull().unique()
            syncColumns(t)
        }
        try db.create(table: "item") { t in
            t.primaryKey("id", .text)
            t.column("type", .text).notNull().defaults(to: "call")  // v1.4: call | email | document
            t.column("title", .text).notNull()
            t.column("occurred_at", .datetime).notNull()
            t.column("duration_sec", .double)
            t.column("source", .text).notNull()
            t.column("status", .text).notNull()
            t.column("project_id", .text).references("project")
            t.column("category_id", .text).references("category")
            t.column("shared", .boolean).notNull().defaults(to: false)  // phase 4
            t.column("capture_meta", .text)
            t.column("trashed_at", .datetime)  // ADR-0030
            syncColumns(t)
        }
        try db.create(index: "item_occurred_at", on: "item", columns: ["occurred_at"])
        try db.create(index: "item_project", on: "item", columns: ["project_id"])
        try db.create(table: "item_tag") { t in
            t.column("item_id", .text).notNull().references("item")
            t.column("tag_id", .text).notNull().references("tag")
            t.column("created_at", .datetime).notNull()
            t.primaryKey(["item_id", "tag_id"])
        }
        try db.create(table: "asset") { t in
            t.primaryKey("id", .text)
            t.column("item_id", .text).notNull().references("item")
            t.column("kind", .text).notNull()
            t.column("rel_path", .text).notNull()
            t.column("size_bytes", .integer)
            t.column("sha256", .text)
            t.column("trashed_at", .datetime)  // ADR-0030
            syncColumns(t)
        }
        try db.create(index: "asset_item", on: "asset", columns: ["item_id"])
        try db.create(table: "item_key") { t in
            t.primaryKey("item_id", .text)
            t.column("wrapped_key", .blob).notNull()
        }
        try db.create(table: "item_speaker") { t in
            t.column("item_id", .text).notNull().references("item")
            t.column("speaker_id", .text).notNull()
            t.column("label", .text).notNull()
            t.column("entity_id", .text)  // phase 3
            t.primaryKey(["item_id", "speaker_id"])
        }
        try db.create(table: "marker") { t in
            t.primaryKey("id", .text)
            t.column("item_id", .text).notNull().references("item")
            t.column("at_sec", .double).notNull()
            t.column("note", .text)
            t.column("status", .text).notNull().defaults(to: "open")
            syncColumns(t)
        }
        try db.create(index: "marker_item", on: "marker", columns: ["item_id"])
        try db.create(table: "note") { t in
            t.primaryKey("id", .text)
            t.column("item_id", .text).references("item")
            t.column("project_id", .text).references("project")
            t.column("kind", .text).notNull().defaults(to: "note")
            t.column("input", .text).notNull().defaults(to: "typed")
            t.column("body", .text).notNull()
            t.column("noted_at", .datetime).notNull()
            t.column("shared", .boolean).notNull().defaults(to: false)
            syncColumns(t)
            t.check(sql: "item_id IS NOT NULL OR project_id IS NOT NULL")
        }
        try db.create(index: "note_item", on: "note", columns: ["item_id"])
        try db.create(index: "note_project", on: "note", columns: ["project_id"])
        try db.create(table: "job") { t in
            t.primaryKey("id", .text)
            t.column("item_id", .text)
            t.column("type", .text).notNull()
            t.column("status", .text).notNull()
            t.column("priority", .integer).notNull().defaults(to: 0)
            t.column("progress", .double).notNull().defaults(to: 0)
            t.column("attempts", .integer).notNull().defaults(to: 0)
            t.column("error", .text)
            t.column("payload", .text)
            t.column("created_at", .datetime).notNull()
            t.column("updated_at", .datetime).notNull()
        }
        try db.create(index: "job_status", on: "job", columns: ["status"])
        try db.create(table: "change_log") { t in
            t.autoIncrementedPrimaryKey("seq")
            t.column("table_name", .text).notNull()
            t.column("row_id", .text).notNull()
            t.column("op", .text).notNull()
            t.column("version", .integer).notNull()
            t.column("at", .datetime).notNull()
        }
        try db.create(table: "audit_log") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("at", .datetime).notNull()
            t.column("actor", .text).notNull()
            t.column("action", .text).notNull()
            t.column("detail", .text)
        }
        try db.create(table: "setting") { t in
            t.primaryKey("key", .text)
            t.column("value", .text).notNull()
        }
    }
}
