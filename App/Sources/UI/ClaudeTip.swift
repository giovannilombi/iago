import AppKit
import IAGOEngine
import IAGOStore
import SwiftUI

/// «Consiglio: fai la sintesi con Claude» (ADR-0071, ADR-0078): on Macs up to 16 GB the engine of the Mac is slow, so
/// the summary and the proposals offer Claude, which does them with IAGO's checks. IAGO never enables anything by
/// itself: the connection, the project's consent and every write are the user's (preview and OK).
/// - It copies the request and opens Claude: IAGO cannot hand Claude a job (MCP is always called by Claude).
/// - «Usa il motore del Mac» on a project hides it there for good; «Non mostrare più» everywhere on this Mac.
struct ClaudeTip: View {
    let model: AppModel
    let item: Item
    let request: ClaudeRequest
    /// One line, for the proposals.
    var compact = false
    @State private var copied = false
    @AppStorage("claudeTip.hidden") private var hidden = false

    static let declinedKey = "claudeTip.declinedProjects"
    static let claudeBundleID = "com.anthropic.claudefordesktop"

    private var project: Project? { item.projectId.flatMap { id in model.projects.first { $0.id == id } } }

    var body: some View {
        if shows {
            HStack(alignment: compact ? .center : .top, spacing: 12) {
                Image(systemName: "sparkles").font(.system(size: compact ? 13 : 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: compact ? 26 : 30, height: compact ? 26 : 30)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.orange))
                VStack(alignment: .leading, spacing: 8) {
                    if copied {
                        Text(String(localized: "Richiesta copiata, Claude è aperto")).fontWeight(.semibold)
                        Text(
                            String(
                                localized:
                                    "Incollala nella chat di Claude con ⌘V. Quando Claude ha finito, controlli il risultato nell'anteprima e, con il tuo OK, compare qui."
                            )
                        )
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Button(String(localized: "Copia di nuovo")) { ask() }.buttonStyle(.link).font(.caption)
                    } else {
                        if !compact { Text(title).fontWeight(.semibold) }
                        Text(compact ? "\(title) \(detail)" : detail)
                            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        if !compact || state != .ready { buttons }
                    }
                }
                if compact, !copied, state == .ready {
                    Spacer(minLength: 8)
                    Button(String(localized: "Chiedi a Claude")) { ask() }
                        .buttonStyle(.borderedProminent).tint(.orange).controlSize(.small)
                }
            }
            .padding(compact ? 10 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3)))
        }
    }

    // MARK: State

    enum State { case ready, noProject, needsConsent, otherConnection, notConnected }

    private var state: State {
        guard let project else { return .noProject }
        let connections = ClaudeConnection.desktopScopes()
        if connections.isEmpty { return .notConnected }
        if !connections.contains(where: { ClaudeConnection.covers($0, project: project) }) { return .otherConnection }
        if !project.claudeAccessible || (request.needsWriting && !project.claudeWritable) { return .needsConsent }
        return .ready
    }

    private var shows: Bool {
        if model.intelligence.byClaude { return true }
        guard EnginePolicy.ramGB <= 16, !hidden else { return false }
        return !(project.map { Self.declined(model.archive).contains($0.id) } ?? false)
    }

    private var title: String {
        request == .summary
            ? String(localized: "Consiglio: fai la sintesi con Claude")
            : String(localized: "Più veloce con Claude:")
    }

    private var detail: String {
        switch state {
        case .ready:
            request == .summary
                ? String(
                    localized:
                        "Questo Mac ha \(EnginePolicy.ramGB) GB di memoria: il motore locale ci mette molto e rallenta il resto. Claude scrive la sintesi con lo stesso modello della categoria, e IAGO controlla ogni citazione come fa con il motore del Mac."
                )
                : String(
                    localized:
                        "decisioni, attività e tag proposti da Claude, con la frase da cui vengono. Restano da confermare."
                )
        case .noProject:
            String(localized: "Claude scrive solo nei progetti: assegna prima questo elemento a un progetto.")
        case .needsConsent:
            String(
                localized:
                    "Per farlo, Claude deve poter leggere e scrivere il progetto «\(project?.name ?? "")». Lo consenti solo per questo progetto, e puoi toglierlo in Impostazioni › Claude."
            )
        case .otherConnection:
            String(
                localized:
                    "Il collegamento di Claude con IAGO è limitato ad altri progetti: da lì Claude non vede «\(project?.name ?? "")». Aggiungi un collegamento che lo includa in Impostazioni › Claude."
            )
        case .notConnected:
            String(
                localized:
                    "Su questo Mac il motore locale è lento. Se usi Claude, collegalo a IAGO una volta: poi sintesi e proposte le fa lui, con i controlli di IAGO."
            )
        }
    }

    @ViewBuilder
    private var buttons: some View {
        HStack(spacing: 10) {
            switch state {
            case .ready:
                Button(
                    request == .summary
                        ? String(localized: "Chiedi a Claude la sintesi") : String(localized: "Chiedi a Claude")
                ) { ask() }
                .buttonStyle(.borderedProminent).tint(.orange)
            case .needsConsent:
                Button(String(localized: "Consenti e chiedi a Claude")) {
                    guard let project else { return }
                    model.perform {
                        try model.archive.setProjectClaudeAccessible(project.id, true)
                        if request.needsWriting { try model.archive.setProjectClaudeWritable(project.id, true) }
                    }
                    ClaudeConnection.provisionServerKey(archive: model.archive)
                    model.reload()
                    ask()
                }
                .buttonStyle(.borderedProminent).tint(.orange)
            case .otherConnection, .notConnected:
                Button(
                    state == .notConnected
                        ? String(localized: "Collega Claude…") : String(localized: "Apri Impostazioni › Claude")
                ) {
                    model.settingsPane = .claude
                    model.openSettings?()
                }
                .buttonStyle(.borderedProminent).tint(.orange)
            case .noProject:
                EmptyView()
            }
            if !model.intelligence.byClaude {
                Button(String(localized: "Usa il motore del Mac")) { decline() }
                    .help(String(localized: "Su questo progetto il consiglio non compare più"))
                if !compact {
                    Button(String(localized: "Non mostrare più")) { hidden = true }
                        .buttonStyle(.link).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Actions

    /// Copies the reference and the request, and opens Claude: the user pastes it there.
    private func ask() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(request.text(for: item, projectName: project?.name), forType: .string)
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.claudeBundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        copied = true
    }

    private func decline() {
        guard let project else {
            hidden = true
            return
        }
        let ids = Self.declined(model.archive).union([project.id])
        model.perform { try model.archive.setSetting(Self.declinedKey, ids.sorted().joined(separator: ",")) }
        model.reload()
    }

    /// Projects where the user chose the engine of the Mac: no tip there.
    static func declined(_ archive: Archive) -> Set<String> {
        Set(((try? archive.setting(declinedKey)) ?? nil)?.split(separator: ",").map(String.init) ?? [])
    }
}
