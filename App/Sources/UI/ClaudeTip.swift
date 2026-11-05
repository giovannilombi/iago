import AppKit
import IAGOEngine
import IAGOStore
import SwiftUI

/// «Consiglio: fai la sintesi con Claude» (ADR-0071, ADR-0078): on Macs up to 16 GB the engine of the Mac is slow, so
/// the summary and the proposals offer Claude, which does them with IAGO's checks. With more memory the same offer is
/// a quiet «Alternativa», with the same steps. IAGO never enables anything by
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
    /// «Vedi come» on the strip: the whole tip again, until the item changes.
    @State private var expanded = false

    static let declinedKey = "claudeTip.declinedProjects"
    static let claudeBundleID = "com.anthropic.claudefordesktop"

    private var project: Project? { item.projectId.flatMap { id in model.projects.first { $0.id == id } } }
    /// The engine of the Mac is fine here: Claude is an alternative, not advice.
    private var quiet: Bool { EnginePolicy.ramGB > 16 && !model.intelligence.byClaude }
    private var tint: Color { quiet ? .secondary : .orange }

    var body: some View {
        if shows {
            HStack(alignment: compact ? .center : .top, spacing: 12) {
                Image(systemName: "sparkles").font(.system(size: compact ? 13 : 15, weight: .semibold))
                    .foregroundStyle(quiet ? Color.orange : .white)
                    .frame(width: compact ? 26 : 30, height: compact ? 26 : 30)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.orange.opacity(quiet ? 0.15 : 1)))
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
                        if !compact { Text(title).fontWeight(quiet ? .medium : .semibold) }
                        Text(compact ? "\(title) \(detail)" : why)
                            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        if compact {
                            if state != .ready { buttons }
                        } else {
                            steps
                            dismissals
                        }
                    }
                }
                if compact, !copied, state == .ready {
                    Spacer(minLength: 8)
                    Button(String(localized: "Chiedi a Claude")) { ask() }
                        .modifier(ClaudeButtonStyle(quiet: quiet)).controlSize(.small)
                }
            }
            .padding(compact ? 10 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(tint.opacity(quiet ? 0.05 : 0.08)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(tint.opacity(quiet ? 0.18 : 0.3)))
        } else {
            strip
        }
    }

    /// Hidden by the user: one thin line that says Claude is still a way, and opens the whole tip again.
    private var strip: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles").font(.caption).foregroundStyle(.orange)
            Text(
                request == .summary
                    ? String(localized: "Alternativa: puoi fare la sintesi anche con Claude.")
                    : String(localized: "Alternativa: puoi chiedere le proposte anche a Claude.")
            )
            .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button(String(localized: "Vedi come")) { expanded = true }
                .buttonStyle(.link).font(.caption)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.secondary.opacity(0.06)))
        .onChange(of: item.id) { expanded = false }
    }

    // MARK: Steps

    /// Why Claude, in the full tip: the steps below say how.
    private var why: String {
        quiet
            ? String(
                localized:
                    "Il motore del Mac va bene su questo Mac. Se preferisci, Claude scrive la sintesi con lo stesso modello della categoria, e IAGO controlla ogni citazione come fa con il motore del Mac."
            )
            : String(
                localized:
                    "Questo Mac ha \(EnginePolicy.ramGB) GB di memoria: il motore locale ci mette molto e rallenta il resto. Claude scrive la sintesi con lo stesso modello della categoria, e IAGO controlla ogni citazione come fa con il motore del Mac."
            )
    }

    /// How to do it with Claude, step by step: each says whether it is done and, if not, what to press.
    private var steps: some View {
        let hasProject = project != nil
        let connected = hasProject && state != .notConnected && state != .otherConnection
        let allowed = connected && state != .needsConsent
        let name = project?.name ?? ""
        return VStack(alignment: .leading, spacing: 5) {
            Text(String(localized: "Per farla con Claude")).font(.caption.weight(.semibold))
                .foregroundStyle(.secondary).textCase(.uppercase)
            step(
                1, done: hasProject,
                text: hasProject
                    ? String(localized: "Nel progetto «\(name)»")
                    : String(localized: "Metti l'elemento in un progetto: Claude scrive solo lì")
            ) { EmptyView() }
            step(
                2, done: connected,
                text: connected
                    ? String(localized: "Claude è collegato a IAGO")
                    : state == .otherConnection
                        ? String(localized: "Collega Claude anche a «\(name)»")
                        : String(localized: "Collega Claude a IAGO, una volta sola")
            ) {
                if hasProject, !connected {
                    Button(String(localized: "Collega Claude…")) {
                        model.settingsPane = .claude
                        model.openSettings?()
                    }
                    .controlSize(.small)
                }
            }
            step(
                3, done: allowed,
                text: allowed
                    ? String(localized: "«\(name)» è già in Claude (icona di Claude nella barra laterale): a posto")
                    : String(localized: "Consenti «\(name)» a Claude, poi riavvia Claude Desktop o Claude Code")
            ) {
                if connected, !allowed {
                    Button(String(localized: "Consenti")) { consent() }.controlSize(.small)
                }
            }
            step(
                4, done: false,
                text: String(localized: "Chiedi a Claude: incolli la richiesta in Claude e confermi qui il risultato")
            ) {
                if allowed {
                    Button(String(localized: "Chiedi a Claude la sintesi")) { ask() }
                        .modifier(ClaudeButtonStyle(quiet: quiet)).controlSize(.small)
                }
            }
        }
    }

    /// One step: done or its number, the text with «come?» to the guide (chapter Claude), and its button.
    private func step(_ number: Int, done: Bool, text: String, @ViewBuilder action: () -> some View) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(number).circle")
                .foregroundStyle(done ? Color.green : Color.secondary)
            (Text(text).foregroundStyle(done ? .secondary : .primary)
                + Text(verbatim: " ")
                + Text(String(localized: "come?")).foregroundStyle(Color.accentColor))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .onTapGesture {
                    model.helpChapter = ClaudeTip.guideChapter
                    model.openHelp?()
                }
                .help(String(localized: "Apri la guida: Claude"))
            Spacer(minLength: 4)
            action()
        }
    }

    /// The guide's chapter on Claude, where the four steps are explained.
    static let guideChapter = "13"

    /// Not now: on this project, or anywhere on this Mac.
    @ViewBuilder
    private var dismissals: some View {
        if !model.intelligence.byClaude {
            HStack(spacing: 12) {
                Button(String(localized: "Non qui: uso il motore del Mac")) { decline() }
                    .help(String(localized: "Su questo progetto il consiglio non compare più"))
                Button(String(localized: "Non mostrare più")) {
                    hidden = true
                    expanded = false
                }
            }
            .buttonStyle(.link).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func consent() {
        guard let project else { return }
        model.perform {
            try model.archive.setProjectClaudeAccessible(project.id, true)
            if request.needsWriting { try model.archive.setProjectClaudeWritable(project.id, true) }
        }
        ClaudeConnection.projectShared(archive: model.archive, projectName: project.name)
        model.reload()
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
        if model.intelligence.byClaude || expanded { return true }
        guard !hidden else { return false }
        return !(project.map { Self.declined(model.archive).contains($0.id) } ?? false)
    }

    private var title: String {
        if quiet {
            return request == .summary
                ? String(localized: "Alternativa: fai la sintesi con Claude")
                : String(localized: "In alternativa, con Claude:")
        }
        return request == .summary
            ? String(localized: "Consiglio: fai la sintesi con Claude")
            : String(localized: "Più veloce con Claude:")
    }

    private var detail: String {
        switch state {
        case .ready where quiet && request == .summary:
            String(
                localized:
                    "Il motore del Mac va bene su questo Mac. Se preferisci, Claude scrive la sintesi con lo stesso modello della categoria, e IAGO controlla ogni citazione come fa con il motore del Mac."
            )
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
        case .notConnected where quiet:
            String(
                localized:
                    "Se usi Claude, puoi collegarlo a IAGO una volta: poi sintesi e proposte le può fare lui, con i controlli di IAGO."
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
                .modifier(ClaudeButtonStyle(quiet: quiet))
            case .needsConsent:
                Button(String(localized: "Consenti e chiedi a Claude")) {
                    guard let project else { return }
                    model.perform {
                        try model.archive.setProjectClaudeAccessible(project.id, true)
                        if request.needsWriting { try model.archive.setProjectClaudeWritable(project.id, true) }
                    }
                    ClaudeConnection.projectShared(archive: model.archive, projectName: project.name)
                    model.reload()
                    ask()
                }
                .modifier(ClaudeButtonStyle(quiet: quiet))
            case .otherConnection, .notConnected:
                Button(
                    state == .notConnected
                        ? String(localized: "Collega Claude…") : String(localized: "Apri Impostazioni › Claude")
                ) {
                    model.settingsPane = .claude
                    model.openSettings?()
                }
                .modifier(ClaudeButtonStyle(quiet: quiet))
            case .noProject:
                EmptyView()
            }
            if !model.intelligence.byClaude {
                Button(String(localized: "Usa il motore del Mac")) { decline() }
                    .help(String(localized: "Su questo progetto il consiglio non compare più"))
                if !compact {
                    Button(String(localized: "Non mostrare più")) {
                        hidden = true
                        expanded = false
                    }
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
        expanded = false
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

/// The tip's main button: orange and prominent as advice, plain bordered as an alternative.
private struct ClaudeButtonStyle: ViewModifier {
    let quiet: Bool

    func body(content: Content) -> some View {
        if quiet { content.buttonStyle(.bordered) } else { content.buttonStyle(.borderedProminent).tint(.orange) }
    }
}
