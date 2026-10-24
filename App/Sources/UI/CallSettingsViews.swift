import SwiftUI

/// Settings › Audio › Riunioni (ADR-0051): what to do when a call starts, Teams' local API, the Calendar.
struct CallSettings: View {
    let model: AppModel
    @State private var calendarOn = false
    @State private var persistent = true
    @State private var axEnabled = false
    @State private var mutedLabels = ""
    @State private var unmutedLabels = ""

    private var detector: CallDetector { model.calls }

    var body: some View {
        SettingsGroup(
            title: String(localized: "Riunioni"),
            footnote: String(
                localized:
                    "IAGO si accorge di una call quando Teams, Zoom, Webex, FaceTime o Slack usano il microfono, oppure dall'API locale di Teams. Il titolo provvisorio viene dal Calendario del Mac, se attivo."
            )
        ) {
            Picker(
                String(localized: "Quando inizia una call"),
                selection: Binding(get: { detector.behaviour }, set: { detector.behaviour = $0 })
            ) {
                Text(String(localized: "Chiedi se registrare")).tag(CallDetector.Behaviour.ask)
                Text(String(localized: "Registra automaticamente")).tag(CallDetector.Behaviour.record)
                Text(String(localized: "Non fare nulla")).tag(CallDetector.Behaviour.nothing)
            }
            .frame(maxWidth: 420)
            VStack(alignment: .leading, spacing: 3) {
                Label(detector.liveStatus, systemImage: "waveform").font(.caption).foregroundStyle(.secondary)
                if let last = detector.lastEvent {
                    Label(last, systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                }
                if detector.notificationsAllowed == false {
                    Label(
                        String(
                            localized:
                                "Le notifiche di IAGO sono spente: le proposte di registrazione compaiono comunque nei pannelli di IAGO; le altre notifiche no. Attivale in Impostazioni di Sistema › Notifiche › IAGO."
                        ), systemImage: "bell.slash"
                    )
                    .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
                Button(String(localized: "Invia una notifica di prova")) { detector.testNotification() }
                    .controlSize(.small)
            }
            Toggle(
                String(localized: "Le proposte di registrazione restano finché non rispondi (al massimo 5 minuti)"),
                isOn: Binding(
                    get: { persistent },
                    set: { value in
                        persistent = value
                        detector.prompts.persistent = value
                    }))
            Text(
                String(
                    localized:
                        "Spento: la proposta sparisce da sola dopo 30 secondi. Con riunioni sovrapposte compare una proposta per ciascuna."
                )
            )
            .font(.caption).foregroundStyle(.secondary)
            Button(String(localized: "Mostra un esempio di proposta")) { detector.showExamplePrompt() }
                .controlSize(.small)
            Toggle(
                String(localized: "Usa il Calendario del Mac per titolo e orario delle riunioni"),
                isOn: Binding(
                    get: { calendarOn },
                    set: { value in
                        Task {
                            await detector.calendar.enable(value)
                            calendarOn = detector.calendar.enabled
                        }
                    })
            )
            if calendarOn == false, detector.calendar.authorized == false {
                Text(
                    String(
                        localized:
                            "Funziona se il calendario di lavoro è sincronizzato nell'app Calendario del Mac (Impostazioni di Sistema › Account Internet)."
                    )
                )
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            calendarOn = detector.calendar.enabled
            persistent = detector.prompts.persistent
        }
        SettingsGroup(
            title: String(localized: "Microfono spento in Teams (Accessibilità)"),
            footnote: String(
                localized:
                    "Quando l'API locale di Teams non è disponibile (spesso la blocca l'IT), IAGO può leggere il pulsante del microfono nella finestra della riunione: quando sei in mute registra silenzio sulla tua traccia. Serve il permesso Accessibilità. IAGO legge solo il testo del pulsante. Se Teams cambia le parole del pulsante, aggiornale qui sotto."
            )
        ) {
            Toggle(
                String(localized: "Segui il mute di Teams con l'Accessibilità di macOS"),
                isOn: Binding(
                    get: { axEnabled },
                    set: { value in
                        axEnabled = value
                        detector.teamsAX.enabled = value
                    }))
            if axEnabled {
                if !TeamsAccessibility.trusted {
                    HStack {
                        Label(
                            String(localized: "Manca il permesso Accessibilità per IAGO."),
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.orange)
                        Button(String(localized: "Consenti…")) { detector.teamsAX.requestPermission() }
                            .controlSize(.small)
                    }
                    .font(.caption)
                } else if detector.teamsAX.buttonFound {
                    Label(
                        detector.teamsAX.isMuted == true
                            ? String(localized: "Pulsante del microfono trovato: sei in mute")
                            : String(localized: "Pulsante del microfono trovato: microfono attivo"),
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption).foregroundStyle(.green)
                    if let label = detector.teamsAX.lastLabel {
                        Text(String(localized: "Testo letto: «\(label)»")).font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text(String(localized: "Pulsante del microfono non trovato: entra in una riunione di Teams."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                DisclosureGroup(String(localized: "Testi del pulsante (avanzato)")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "Quando sei in mute il pulsante dice (separati da virgole):")).font(
                            .caption)
                        TextField("", text: $mutedLabels).textFieldStyle(.roundedBorder)
                            .onSubmit { detector.teamsAX.mutedLabels = mutedLabels }
                        Text(String(localized: "Quando parli il pulsante dice:")).font(.caption)
                        TextField("", text: $unmutedLabels).textFieldStyle(.roundedBorder)
                            .onSubmit { detector.teamsAX.unmutedLabels = unmutedLabels }
                        HStack {
                            Button(String(localized: "Salva")) {
                                detector.teamsAX.mutedLabels = mutedLabels
                                detector.teamsAX.unmutedLabels = unmutedLabels
                                detector.teamsAX.reset()
                            }
                            Button(String(localized: "Ripristina")) {
                                mutedLabels = TeamsAccessibility.defaultMuted
                                unmutedLabels = TeamsAccessibility.defaultUnmuted
                                detector.teamsAX.mutedLabels = mutedLabels
                                detector.teamsAX.unmutedLabels = unmutedLabels
                                detector.teamsAX.reset()
                            }
                        }
                        .controlSize(.small)
                    }
                    .padding(.top, 4)
                }
                .font(.callout)
            }
        }
        .onAppear {
            axEnabled = detector.teamsAX.enabled
            mutedLabels = detector.teamsAX.mutedLabels
            unmutedLabels = detector.teamsAX.unmutedLabels
        }
        SettingsGroup(
            title: String(localized: "API locale di Teams"),
            footnote: String(
                localized:
                    "Con l'API locale IAGO sa quando sei in una riunione Teams e quando hai il microfono spento: in quei momenti registra silenzio sulla tua traccia. La connessione resta sul Mac (127.0.0.1). Per attivarla: in Teams apri Impostazioni › Privacy › API di app di terze parti e attivala; poi entra in una riunione e, quando Teams lo chiede, consenti IAGO."
            )
        ) {
            Toggle(
                String(localized: "Collega l'API locale di Teams"),
                isOn: Binding(get: { detector.teams.enabled }, set: { detector.teams.enabled = $0 }))
            if detector.teams.enabled {
                Label(statusText, systemImage: statusIcon).font(.callout)
                    .foregroundStyle(detector.teams.status == .connected ? Color.green : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if detector.teams.status == .connected {
                    Button(String(localized: "Dimentica l'abbinamento")) { detector.teams.forgetPairing() }
                        .buttonStyle(.link)
                }
            } else {
                Text(
                    String(
                        localized:
                            "Facoltativa: se nella tua azienda è bloccata, usa l'Accessibilità qui sopra per il mute."
                    )
                )
                .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var statusText: String {
        switch detector.teams.status {
        case .off: String(localized: "Spenta")
        case .unreachable:
            String(localized: "Teams non risponde: controlla che l'API sia attiva in Teams e che Teams sia aperto.")
        case .waitingForPairing:
            String(localized: "Collegata, da abbinare: entra in una riunione e consenti IAGO quando Teams lo chiede.")
        case .connected:
            detector.teams.isInMeeting
                ? (detector.teams.isMuted
                    ? String(localized: "Collegata · in riunione · microfono spento")
                    : String(localized: "Collegata · in riunione"))
                : String(localized: "Collegata")
        case .refused(let message): String(localized: "Teams ha rifiutato la richiesta: \(message)")
        }
    }

    private var statusIcon: String {
        detector.teams.status == .connected ? "checkmark.circle.fill" : "exclamationmark.circle"
    }
}
