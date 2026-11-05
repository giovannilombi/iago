import IAGOStore
import SwiftUI

/// Impostazioni › Voci (ADR-0073): turning voice prints on and off, and the voices IAGO knows, to forget one by one
/// or all together.
struct VoicesPane: View {
    let model: AppModel
    @State private var enabled = false
    @State private var voices: [VoicePrint] = []
    @State private var forgetting: VoicePrint?
    /// Forgetting every voice: 1 what is lost, 2 type DELETE, 3 last warning.
    @State private var step = 0
    @State private var typed = ""

    var body: some View {
        MyNameGroup(model: model)
        SettingsGroup(
            title: String(localized: "Riconoscimento delle voci"),
            footnote: String(
                localized:
                    "L'impronta di una voce è un dato biometrico: resta solo su questo Mac, cifrata con la call da cui viene, e non va mai a Claude, negli export o nella condivisione. Vale per le call trascritte dopo l'attivazione; per una call già trascritta usa Ritrascrivi."
            )
        ) {
            Toggle(String(localized: "Riconosci le voci tra una call e l'altra"), isOn: $enabled)
                .onChange(of: enabled) { _, value in
                    guard value != model.archive.voicesEnabled() else { return }
                    model.perform { try model.archive.setVoicesEnabled(value) }
                }
            Text(
                String(
                    localized:
                        "Quando dai un nome a uno speaker, IAGO ricorda la sua voce. Nelle call successive propone il nome («Speaker 2 sembra Marco») e tu confermi: non lo assegna mai da solo."
                )
            )
            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !enabled && !voices.isEmpty {
                Text(
                    String(
                        localized:
                            "Disattivato: IAGO non impara né riconosce voci, ma quelle già salvate restano finché non le elimini."
                    )
                )
                .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }
        SettingsGroup(
            title: String(localized: "Voci conosciute (\(voices.count))"),
            footnote: String(
                localized:
                    "Eliminare una voce cancella la sua impronta e quelle delle call da cui veniva; i nomi degli speaker nelle trascrizioni restano. Eliminando una call, la sua parte dell'impronta se ne va con lei."
            )
        ) {
            if voices.isEmpty {
                Text(String(localized: "Nessuna voce salvata.")).foregroundStyle(.secondary)
            }
            ForEach(voices) { voice in
                HStack {
                    Image(systemName: "person.wave.2").foregroundStyle(.secondary)
                    Text(voice.name)
                    Spacer()
                    Text(detail(voice)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    Button(String(localized: "Elimina…"), role: .destructive) { forgetting = voice }
                        .buttonStyle(.link)
                }
            }
            if !voices.isEmpty {
                HStack {
                    Spacer()
                    Button(String(localized: "Elimina tutte le voci…"), role: .destructive) { step = 1 }
                }
            }
        }
        .onAppear(perform: reload)
        .onChange(of: model.revision) { _, _ in reload() }
        .alert(
            String(localized: "Eliminare la voce di «\(forgetting?.name ?? "")»?"),
            isPresented: Binding(get: { forgetting != nil }, set: { if !$0 { forgetting = nil } }),
            presenting: forgetting
        ) { voice in
            Button(String(localized: "Elimina"), role: .destructive) {
                model.perform { try model.archive.forgetVoice(voice.id) }
                reload()
            }
            Button(String(localized: "Annulla"), role: .cancel) {}
        } message: { voice in
            Text(
                String(
                    localized:
                        "IAGO non riconoscerà più \(voice.name) nelle prossime call. Per insegnargli di nuovo la voce basta dare il nome a uno speaker."
                ))
        }
        // Step 1: what is lost.
        .alert(
            String(localized: "Eliminare tutte le voci?"),
            isPresented: Binding(get: { step == 1 }, set: { if !$0 && step == 1 { cancel() } })
        ) {
            Button(String(localized: "Continua"), role: .destructive) { step = 2 }
            Button(String(localized: "Annulla"), role: .cancel) { cancel() }
        } message: {
            Text(
                String(
                    localized:
                        "Perderai le impronte di \(voices.count) persone e quelle degli speaker non ancora nominati. Non si potranno recuperare."
                ))
        }
        // Step 2: type DELETE.
        .sheet(isPresented: Binding(get: { step == 2 }, set: { if !$0 && step == 2 { cancel() } })) {
            VStack(alignment: .leading, spacing: 12) {
                Label(String(localized: "Conferma l'eliminazione"), systemImage: "exclamationmark.triangle.fill")
                    .font(.title3).bold().foregroundStyle(.red)
                Text(String(localized: "Per eliminare tutte le voci scrivi DELETE qui sotto."))
                TextField("DELETE", text: $typed).textFieldStyle(.roundedBorder).font(.title2.monospaced()).frame(
                    width: 220)
                HStack {
                    Spacer()
                    Button(String(localized: "Annulla"), role: .cancel) { cancel() }.keyboardShortcut(.cancelAction)
                    Button(String(localized: "OK")) { step = 3 }.disabled(typed != "DELETE")
                }
            }
            .padding(20).frame(width: 420)
        }
        // Step 3: final warning.
        .alert(
            String(localized: "Ultima conferma"),
            isPresented: Binding(get: { step == 3 }, set: { if !$0 && step == 3 { cancel() } })
        ) {
            Button(String(localized: "Elimina definitivamente"), role: .destructive) {
                model.perform { try model.archive.forgetAllVoices() }
                cancel()
                reload()
            }
            Button(String(localized: "Annulla"), role: .cancel) { cancel() }
        } message: {
            Text(
                String(localized: "Tutte le impronte delle voci verranno distrutte. L'operazione non si può annullare.")
            )
        }
    }

    private func detail(_ voice: VoicePrint) -> String {
        let minutes = max(1, Int((voice.seconds / 60).rounded()))
        return String(localized: "\(voice.calls) call · \(minutes) min di parlato")
    }

    private func reload() {
        enabled = model.archive.voicesEnabled()
        voices = (try? model.archive.voicePrints()) ?? []
    }

    private func cancel() {
        step = 0
        typed = ""
    }
}

/// «Il tuo nome» (Generale and Voci): how the user's voice, the Mac's microphone, is named in the transcripts. It
/// applies with Return, the button or by leaving the field, and the calls that still have the old name take the new one.
struct MyNameGroup: View {
    let model: AppModel
    @State private var name = ""
    @State private var saved = ""
    @State private var changed: Int?
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var pending: Bool { trimmed != saved && !trimmed.isEmpty }

    var body: some View {
        SettingsGroup(
            title: String(localized: "Il tuo nome"),
            footnote: String(
                localized:
                    "Nelle trascrizioni la tua voce (il microfono del Mac) compare con questo nome. Cambiandolo, lo prendono anche le call già trascritte con il nome di prima."
            )
        ) {
            HStack {
                TextField(MeLabel.defaultName, text: $name).textFieldStyle(.roundedBorder).frame(maxWidth: 260)
                    .focused($focused)
                    .onSubmit(save)
                if pending {
                    Button(String(localized: "Salva"), action: save).keyboardShortcut(.defaultAction)
                }
            }
            if let changed, changed > 0 {
                Text(
                    changed == 1
                        ? String(localized: "Aggiornata 1 call.") : String(localized: "Aggiornate \(changed) call.")
                )
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear {
            saved = model.meName
            name = saved
        }
        .onChange(of: focused) { _, now in if !now, pending { save() } }
    }

    private func save() {
        guard pending else { return }
        let old = saved
        let value = trimmed
        model.perform { try model.archive.setSetting(TranscriptionService.meLabelKey, value) }
        let items = (try? model.archive.renameMe(from: old, to: value)) ?? []
        for item in items { model.refreshTextAssets(item) }
        saved = value
        changed = items.count
        model.reload()
    }
}
