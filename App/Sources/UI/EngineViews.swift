import IAGOEngine
import IAGOIntelligence
import SwiftUI

/// Settings › Motore (ADR-0048): the curated models, their download and the one in use.
struct EnginePane: View {
    let model: AppModel
    @State private var confirmingLowRAM: EngineModel?
    @State private var confirmingDelete: EngineModel?

    private var engine: EngineService { model.engine }

    var body: some View {
        SettingsGroup(
            title: String(localized: "Motore locale"),
            footnote: String(
                localized:
                    "Il motore gira sul Mac, dentro IAGO: i testi non escono mai. Serve per sintesi (almeno il 9B), proposte automatiche, Chiedi a IAGO e «Riordina testo». I titoli proposti restano ad Apple Intelligence. IAGO funziona anche senza motore."
            )
        ) {
            if let active = engine.activeModel {
                Label(String(localized: "In uso: \(active.name)"), systemImage: "cpu.fill").foregroundStyle(.green)
            } else {
                Label(
                    String(
                        localized:
                            "Nessun motore: le funzioni che lo usano ti chiederanno di sceglierne uno. Tutto il resto funziona."
                    ), systemImage: "cpu"
                )
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        SettingsGroup(
            title: String(localized: "Modelli disponibili"),
            footnote: String(
                localized:
                    "Modelli aperti delle famiglie Qwen e Gemma, in versione per Mac. Si scaricano solo quando lo chiedi, da indirizzi fissi, e ogni file viene verificato con un'impronta SHA-256. Il download continua in background e riprende se si interrompe."
            )
        ) {
            ForEach(EngineCatalog.models) { entry in
                row(entry)
                if entry.id != EngineCatalog.models.last?.id { Divider() }
            }
        }
        SettingsGroup(
            title: String(localized: "Ricerca per significato"),
            footnote: String(
                localized:
                    "Un modello piccolo che trova i passaggi che dicono la stessa cosa con altre parole, anche per la chat e i collegamenti. Si scarica insieme al primo motore; i testi restano sul Mac."
            )
        ) {
            row(EngineCatalog.embedding)
            if let indexing = model.intelligence.indexing {
                HStack {
                    ProgressView(value: Double(indexing.done), total: Double(max(indexing.total, 1)))
                        .frame(maxWidth: 260)
                    Text(String(localized: "Indicizzo l'archivio: \(indexing.done) di \(indexing.total)"))
                        .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
            }
        }
        SettingsGroup(
            title: String(localized: "Proposte automatiche"),
            footnote: String(
                localized:
                    "Dopo ogni trascrizione o importazione il motore propone decisioni, attività, nomi degli speaker, tag, progetto e collegamenti. Le trovi nella scheda dell'elemento e in Punti chiave › Da confermare; niente viene applicato senza la tua conferma. Per gli elementi già in archivio usa «Cerca proposte» nella loro scheda."
            )
        ) {
            Toggle(
                String(localized: "Proponi automaticamente"),
                isOn: Binding(get: { model.intelligence.autoSuggest }, set: { model.intelligence.autoSuggest = $0 })
            )
            .disabled(engine.activeModel == nil)
            if let title = model.intelligence.proposingFor {
                Label(String(localized: "Sto preparando le proposte per «\(title)»"), systemImage: "cpu")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .confirmationDialog(
            String(localized: "Il Mac potrebbe non bastare"), isPresented: present($confirmingLowRAM),
            presenting: confirmingLowRAM
        ) { entry in
            Button(String(localized: "Scarica comunque")) { engine.download(entry) }
            Button(String(localized: "Annulla"), role: .cancel) {}
        } message: { entry in
            Text(
                String(
                    localized:
                        "\(entry.name) funziona meglio con almeno \(entry.recommendedRAMGB) GB di RAM; questo Mac ne ha \(EngineService.ramGB). Può essere lento o rallentare le altre app."
                ))
        }
        .confirmationDialog(
            String(localized: "Eliminare il motore?"), isPresented: present($confirmingDelete),
            presenting: confirmingDelete
        ) { entry in
            Button(String(localized: "Elimina \(entry.name)"), role: .destructive) { engine.delete(entry) }
            Button(String(localized: "Annulla"), role: .cancel) {}
        } message: { entry in
            Text(
                entry.id == engine.activeModel?.id
                    ? String(
                        localized:
                            "È il motore in uso: dopo, le funzioni del motore chiederanno di sceglierne un altro. Puoi riscaricarlo quando vuoi."
                    )
                    : String(
                        localized: "Libera \(Format.bytes(engine.diskSize(of: entry))). Puoi riscaricarlo quando vuoi.")
            )
        }
    }

    @ViewBuilder
    private func row(_ entry: EngineModel) -> some View {
        let state = engine.state(of: entry)
        let isActive = engine.activeModel?.id == entry.id
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.name).font(.headline)
                Text(entry.family).foregroundStyle(.secondary)
                if entry.role == .chat, EngineCatalog.recommended(forRAMGB: EngineService.ramGB).id == entry.id {
                    Text(String(localized: "Consigliato per questo Mac")).font(.caption.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                }
                Spacer()
                if isActive {
                    Label(String(localized: "In uso"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            if entry.role == .chat {
                Text(Self.summary(entry)).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            let traits = Self.traits(entry)
            if !traits.pros.isEmpty {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "Punti di forza")).font(.caption.weight(.semibold))
                        ForEach(traits.pros, id: \.self) { Label($0, systemImage: "plus.circle").font(.caption) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "Limiti")).font(.caption.weight(.semibold))
                        ForEach(traits.cons, id: \.self) { Label($0, systemImage: "minus.circle").font(.caption) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            if let expectation = traits.expectation {
                Label(expectation, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Text(String(localized: "Download \(Format.bytes(entry.downloadBytes))"))
                Text(String(localized: "RAM consigliata \(entry.recommendedRAMGB) GB"))
                    .foregroundStyle(EngineService.ramGB < entry.recommendedRAMGB ? .orange : .secondary)
                Link(String(localized: "Licenza \(entry.license)"), destination: entry.licenseURL)
            }
            .font(.caption).foregroundStyle(.secondary)
            if let progress = engine.progress[entry.id] {
                HStack {
                    ProgressView(value: progress.fraction).frame(maxWidth: 260)
                    Text(Self.progressText(progress)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    Spacer()
                    Button(String(localized: "Annulla")) { engine.cancel(entry) }
                }
            } else {
                HStack {
                    switch state {
                    case .missing:
                        Button(String(localized: "Scarica")) { startDownload(entry) }
                    case .partial(let bytes):
                        Text(
                            String(
                                localized:
                                    "Download interrotto: \(Format.bytes(bytes)) di \(Format.bytes(entry.downloadBytes))"
                            )
                        )
                        .font(.caption).foregroundStyle(.secondary)
                        Button(String(localized: "Riprendi")) { startDownload(entry) }
                        Button(String(localized: "Elimina"), role: .destructive) { confirmingDelete = entry }
                            .buttonStyle(.link)
                    case .installed:
                        if !isActive, entry.role == .chat {
                            Button(String(localized: "Usa questo")) { engine.use(entry) }
                        }
                        Text(Format.bytes(engine.diskSize(of: entry))).font(.caption).monospacedDigit()
                            .foregroundStyle(.secondary)
                        Button(String(localized: "Elimina"), role: .destructive) { confirmingDelete = entry }
                            .buttonStyle(.link)
                    }
                    Spacer()
                }
            }
            if let failure = engine.failures[entry.id] {
                Text(String(localized: "Download non riuscito: \(failure)")).font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    private func startDownload(_ entry: EngineModel) {
        if EngineService.ramGB < entry.recommendedRAMGB {
            confirmingLowRAM = entry
        } else {
            engine.download(entry)
        }
    }

    private func present<T>(_ value: Binding<T?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }

    /// Strengths and limits from the trial on a real call (2026-10-16), so nobody expects more than a model gives.
    static func traits(_ entry: EngineModel) -> (pros: [String], cons: [String], expectation: String?) {
        switch entry.id {
        case "qwen3.5-4b":
            (
                [
                    String(localized: "Veloce: una call di 30 minuti in circa un minuto"),
                    String(localized: "Poca memoria (circa 3,5 GB): va su tutti i Mac con 16 GB"),
                ],
                [
                    String(localized: "Coglie meno le sfumature: nella prova circa 1 proposta su 6 era sbagliata"),
                    String(localized: "Testi riordinati meno curati"),
                    String(localized: "Troppo piccolo per le sintesi: per quelle serve almeno il 9B"),
                ],
                String(
                    localized:
                        "Cosa aspettarsi: un aiuto per non perdere decisioni e attività, non un verbale pronto. Le proposte vanno sempre controllate prima di confermarle."
                )
            )
        case "qwen3.5-9b":
            (
                [
                    String(localized: "Scrive in modo più curato del 4B"),
                    String(localized: "Fa le sintesi: circa 1-1,5 minuti per una call di 30 minuti"),
                ],
                [
                    String(localized: "Il doppio della memoria (circa 6 GB) e del tempo del 4B"),
                    String(localized: "Sintesi meno ricche di Gemma"),
                    String(localized: "Con 16 GB lascia poco spazio alle altre app"),
                ],
                nil
            )
        case "gemma-4-12b":
            (
                [
                    String(localized: "Il più preciso: nella prova nessuna proposta sbagliata"),
                    String(localized: "Il miglior riordino del testo"),
                ],
                [
                    String(localized: "Circa 12,5 GB di memoria: solo per Mac con 32 GB o più"),
                    String(localized: "Da 2 a 3 volte più lento del 4B"),
                ],
                nil
            )
        default: ([], [], nil)
        }
    }

    static func summary(_ entry: EngineModel) -> String {
        switch entry.id {
        case "qwen3.5-4b":
            String(localized: "Il più leggero e veloce: va bene anche su Mac con 16 GB di RAM.")
        case "qwen3.5-9b": String(localized: "Il consigliato con 16 GB: il più piccolo che fa anche le sintesi.")
        case "gemma-4-12b": String(localized: "Il più accurato del catalogo, più lento e più pesante.")
        default: String(localized: "\(Int(entry.billions)) miliardi di parametri.")
        }
    }

    static func progressText(_ progress: EngineProgress) -> String {
        let percent = Int(progress.fraction * 100)
        let speed = progress.bytesPerSecond > 0 ? " · \(Format.bytes(Int64(progress.bytesPerSecond)))/s" : ""
        return "\(percent)% · \(Format.bytes(progress.bytes)) di \(Format.bytes(progress.total))\(speed)"
    }
}

/// "Serve un motore locale": a feature of the engine asked for without one (ADR-0048).
struct EngineNeededSheet: View {
    let model: AppModel
    let feature: EngineFeature
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            let tooSmall = model.engine.activeModel != nil && !model.engine.isBigEnough(for: feature)
            Label(
                tooSmall
                    ? String(localized: "Serve un motore più grande") : String(localized: "Serve un motore locale"),
                systemImage: "cpu"
            ).font(.title2).bold()
            Text(feature.title).font(.headline)
            Text(feature.explanation).fixedSize(horizontal: false, vertical: true)
            if tooSmall, let active = model.engine.activeModel {
                Text(
                    String(
                        localized:
                            "Il motore attivo è \(active.name): per questa funzione è troppo piccolo. Serve almeno Qwen 3.5 9B (circa 6 GB di memoria), oppure Gemma 4 12B se il Mac ha 32 GB."
                    )
                )
                .foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            Text(
                String(
                    localized:
                        "Per farlo IAGO usa un motore che scarichi e scegli tu, e che gira sul Mac: i testi non escono mai. Ci sono modelli da circa 3 a 11 GB."
                )
            )
            .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(String(localized: "Non ora"), role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(String(localized: "Scegli e scarica un motore…")) {
                    dismiss()
                    model.settingsPane = .engine
                    model.openSettings?()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22).frame(width: 480)
    }
}

/// "Il motore è pronto": once, after a download (ADR-0048).
struct EngineReadySheet: View {
    let model: AppModel
    let entry: EngineModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(String(localized: "Il motore è pronto"), systemImage: "cpu.fill").font(.title2).bold()
                .foregroundStyle(.green)
            Text(
                model.engine.activeModel?.id == entry.id
                    ? String(
                        localized:
                            "\(entry.name) è scaricato, verificato e in uso. Gira sul Mac: i testi non escono mai.")
                    : String(
                        localized:
                            "\(entry.name) è scaricato e verificato. Per usarlo al posto di quello attuale scegli «Usa questo» in Impostazioni › Motore."
                    )
            )
            .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Cosa puoi fare ora")).font(.headline)
                Label(
                    String(
                        localized:
                            "Riordina testo: nella finestra di una nota, il pulsante «Riordina testo» pulisce un testo dettato. Vedi il risultato prima di sostituirlo."
                    ), systemImage: "text.badge.checkmark"
                )
                .fixedSize(horizontal: false, vertical: true)
                Text(String(localized: "In arrivo")).font(.headline).padding(.top, 4)
                Text(
                    String(
                        localized:
                            "Proposte automatiche di decisioni e attività dalle call, chat con le fonti, ricerca per significato."
                    )
                )
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button(String(localized: "Ho capito")) { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(22).frame(width: 500)
    }
}

/// "Riordina testo" (FR-219): the engine's version next to the original; nothing changes until "Sostituisci".
struct TidyPreviewSheet: View {
    let original: String
    let tidied: String
    let modelName: String
    let onReplace: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "Riordina testo"), systemImage: "cpu").font(.title3).bold()
            HStack(alignment: .top, spacing: 12) {
                column(String(localized: "Prima"), original, secondary: true)
                column(String(localized: "Dopo"), tidied, secondary: false)
            }
            let missing = TextTidier.missingFacts(original: original, tidied: tidied)
            if !missing.isEmpty {
                Label(
                    String(
                        localized:
                            "Nella nuova versione non trovo: \(missing.joined(separator: ", ")). Controlla prima di sostituire."
                    ), systemImage: "exclamationmark.triangle.fill"
                )
                .font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            Text(
                String(
                    localized: "Proposto da \(modelName), sul Mac. Controlla nomi, numeri e date prima di sostituire.")
            )
            .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(String(localized: "Sostituisci")) {
                    onReplace()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 760, height: 520)
    }

    private func column(_ title: String, _ text: String, secondary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            ScrollView {
                Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(secondary ? .secondary : .primary)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
        }
    }
}
