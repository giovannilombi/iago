import Foundation
import Observation

/// The work IAGO does outside the job queue, in one observable place (ADR-0055): imports, backups, exports, model
/// downloads, text tidying. The "Attività" view and the menu bar read it, next to the queue, the recorder and the
/// engine. Titles only, never content.
@MainActor
@Observable
final class ActivityCenter {
    enum Kind: String {
        case importFiles, backup, restore, exportAudio, modelDownload, tidy
        /// «Sintesi di stato» of a project, client or stream (ADR-0074).
        case statusReport
        /// «Condividi…» on an item (ADR-0080): its files decrypted for the Share menu or a folder.
        case share

        var label: String {
            switch self {
            case .importFiles: String(localized: "Importazione")
            case .backup: String(localized: "Backup cifrato")
            case .restore: String(localized: "Ripristino da backup")
            case .exportAudio: String(localized: "Esportazione audio")
            case .modelDownload: String(localized: "Download dei modelli di trascrizione")
            case .tidy: String(localized: "Riordino del testo")
            case .statusReport: String(localized: "Sintesi di stato")
            case .share: String(localized: "Condivisione")
            }
        }

        var symbol: String {
            switch self {
            case .importFiles: "square.and.arrow.down"
            case .backup, .restore: "externaldrive"
            case .exportAudio, .share: "square.and.arrow.up"
            case .modelDownload: "arrow.down.circle"
            case .tidy: "text.badge.checkmark"
            case .statusReport: "doc.text.magnifyingglass"
            }
        }
    }

    struct Work: Identifiable {
        let id = UUID()
        var kind: Kind
        var title: String
        /// 0…1 when known.
        var fraction: Double?
        var startedAt = Date()
    }

    struct Finished: Identifiable {
        let id: UUID
        var kind: Kind
        var title: String
        var failure: String?
        var at: Date
        var itemID: String?
    }

    /// The transcription running in the queue, from its events (the queue's stream has one reader: the menu bar).
    struct RunningJob: Equatable {
        var id: String
        var itemID: String?
        var progress: Double
        var startedAt = Date()
    }

    private(set) var running: [Work] = []
    /// This session's finished work, newest first; kept for 24 hours.
    private(set) var recent: [Finished] = []
    var runningJob: RunningJob?

    @discardableResult
    func begin(_ kind: Kind, _ title: String = "") -> UUID {
        let work = Work(kind: kind, title: title)
        running.append(work)
        return work.id
    }

    func update(_ id: UUID, fraction: Double) {
        guard let index = running.firstIndex(where: { $0.id == id }) else { return }
        running[index].fraction = min(max(fraction, 0), 1)
    }

    func end(_ id: UUID, failure: String? = nil, itemID: String? = nil) {
        guard let index = running.firstIndex(where: { $0.id == id }) else { return }
        let work = running.remove(at: index)
        recent.insert(
            Finished(id: work.id, kind: work.kind, title: work.title, failure: failure, at: Date(), itemID: itemID),
            at: 0)
        let cutoff = Date().addingTimeInterval(-86_400)
        recent.removeAll { $0.at < cutoff }
    }

    func clearRecent() { recent.removeAll() }

    /// Runs `body` as one piece of work: it shows while running and goes to the recent ones at the end.
    func track<T>(_ kind: Kind, _ title: String = "", _ body: (UUID) async throws -> T) async throws -> T {
        let id = begin(kind, title)
        do {
            let value = try await body(id)
            end(id)
            return value
        } catch is CancellationError {
            end(id, failure: String(localized: "Annullato"))
            throw CancellationError()
        } catch {
            end(id, failure: ErrorText.describe(error))
            throw error
        }
    }
}
