import AVFoundation
import AppKit
import EventKit
import IAGOEngine
import ServiceManagement
import SwiftUI
import UserNotifications

/// Everything IAGO needs from macOS and from other apps to work at 100% (user request 2026-10-20). Keep this list
/// up to date: every change that needs a new permission or activation adds a step here (memory
/// `permissions-section-rule`).
struct PermissionStep: Identifiable, Equatable {
    enum Level: Int, Comparable {
        case required, recommended, optional
        static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
    }
    enum State: Equatable { case granted, missing, unknown }
    enum ID: String, CaseIterable {
        case microphone, systemAudio, notifications, transcriptionModels, loginItem, calendar, calendarAccounts,
            engine, searchModel, teamsAccessibility, teamsAPI, screenRecording
    }

    var id: ID
    var title: String
    var why: String
    var icon: String
    var level: Level
    var state: State
    /// What to do next, shown on the button.
    var action: String
}

@MainActor
@Observable
final class PermissionCenter {
    private let model: AppModel
    private(set) var steps: [PermissionStep] = []
    private(set) var notificationsAllowed: Bool?
    private(set) var checkingAudio = false

    static let systemAudioKey = "permissions.systemAudio"

    init(model: AppModel) {
        self.model = model
    }

    func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsAllowed =
            settings.authorizationStatus == .notDetermined
            ? nil : settings.authorizationStatus == .authorized && settings.alertSetting == .enabled
        steps = PermissionStep.ID.allCases.map(step)
    }

    var grantedCount: Int { steps.filter { $0.state == .granted }.count }

    private func step(_ id: PermissionStep.ID) -> PermissionStep {
        switch id {
        case .microphone:
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            return PermissionStep(
                id: id, title: String(localized: "Microfono"),
                why: String(localized: "Per registrare la tua voce nelle call e dettare le note."), icon: "mic",
                level: .required, state: status == .authorized ? .granted : .missing,
                action: status == .notDetermined
                    ? String(localized: "Consenti") : String(localized: "Apri Impostazioni"))
        case .systemAudio:
            let ok = (try? model.archive.setting(Self.systemAudioKey)) == "1"
            return PermissionStep(
                id: id, title: String(localized: "Audio di sistema"),
                why: String(
                    localized:
                        "Per registrare le voci degli altri nella call. macOS non dice se è concesso: IAGO lo verifica con una prova di 5 secondi."
                ), icon: "speaker.wave.2", level: .required, state: ok ? .granted : .unknown,
                action: String(localized: "Fai la prova"))
        case .notifications:
            return PermissionStep(
                id: id, title: String(localized: "Notifiche"),
                why: String(
                    localized:
                        "Per proporti di registrare quando inizia una call, avvisarti a fine call, quando una trascrizione è pronta o ci sono proposte."
                ), icon: "bell", level: .required,
                state: notificationsAllowed == true ? .granted : .missing,
                action: notificationsAllowed == nil
                    ? String(localized: "Consenti") : String(localized: "Apri Impostazioni"))
        case .transcriptionModels:
            let ok = model.transcription.models.missing().isEmpty
            return PermissionStep(
                id: id, title: String(localized: "Modelli di trascrizione"),
                why: String(localized: "Per trascrivere le call sul Mac, senza rete. Si scaricano una volta sola."),
                icon: "text.bubble", level: .required, state: ok ? .granted : .missing,
                action: String(localized: "Scarica"))
        case .loginItem:
            let ok = SMAppService.mainApp.status == .enabled
            return PermissionStep(
                id: id, title: String(localized: "Avvio al login"),
                why: String(localized: "Così IAGO è sempre nella barra dei menu e non perde l'inizio di una call."),
                icon: "power", level: .recommended, state: ok ? .granted : .missing, action: String(localized: "Attiva")
            )
        case .calendar:
            let ok = EKEventStore.authorizationStatus(for: .event) == .fullAccess && model.calls.calendar.enabled
            return PermissionStep(
                id: id, title: String(localized: "Calendario"),
                why: String(
                    localized:
                        "Per dare il titolo della riunione alle registrazioni e ricordarti di registrare all'orario d'inizio."
                ), icon: "calendar", level: .recommended, state: ok ? .granted : .missing,
                action: String(localized: "Consenti"))
        case .calendarAccounts:
            let ok = Self.hasSyncedCalendars
            return PermissionStep(
                id: id, title: String(localized: "Calendari di lavoro e personali sul Mac"),
                why: String(
                    localized:
                        "IAGO legge i calendari dell'app Calendario: aggiungi l'account di lavoro (Microsoft Exchange) e Google in Impostazioni di Sistema › Account Internet, con «Calendari» attivo."
                ), icon: "person.crop.circle.badge.plus", level: .recommended,
                state: ok
                    ? .granted : (EKEventStore.authorizationStatus(for: .event) == .fullAccess ? .missing : .unknown),
                action: String(localized: "Apri Account Internet"))
        case .engine:
            let ok = model.engine.activeModel != nil
            return PermissionStep(
                id: id, title: String(localized: "Motore locale"),
                why: String(localized: "Per proposte automatiche, Chiedi a IAGO e Riordina testo. Gira sul Mac."),
                icon: "cpu", level: .recommended, state: ok ? .granted : .missing,
                action: String(localized: "Scegli e scarica"))
        case .searchModel:
            let ok = model.engine.library.embeddingModel != nil
            return PermissionStep(
                id: id, title: String(localized: "Ricerca per significato"),
                why: String(localized: "Per trovare i passaggi che dicono la stessa cosa con altre parole (0,35 GB)."),
                icon: "magnifyingglass", level: .recommended, state: ok ? .granted : .missing,
                action: String(localized: "Scarica"))
        case .teamsAccessibility:
            let ok = model.calls.teamsAX.enabled && TeamsAccessibility.trusted
            return PermissionStep(
                id: id, title: String(localized: "Mute di Teams (Accessibilità)"),
                why: String(
                    localized:
                        "Per non registrare il tuo microfono quando sei in mute su Teams, se l'API locale di Teams è bloccata: IAGO legge solo il pulsante del microfono."
                ), icon: "mic.slash", level: .recommended, state: ok ? .granted : .missing,
                action: String(localized: "Attiva"))
        case .teamsAPI:
            let ok = model.calls.teams.status == .connected
            return PermissionStep(
                id: id, title: String(localized: "API locale di Teams"),
                why: String(
                    localized:
                        "Per sapere quando sei in riunione e in mute: in mute IAGO non registra il tuo microfono. Si attiva in Teams › Impostazioni › Privacy › API di app di terze parti, poi in una riunione si consente IAGO."
                ), icon: "person.2.wave.2", level: .optional, state: ok ? .granted : .missing,
                action: String(localized: "Collega"))
        case .screenRecording:
            return PermissionStep(
                id: id, title: String(localized: "Registrazione schermo"),
                why: String(
                    localized:
                        "Per «Segna momento con screenshot»: IAGO cattura lo schermo solo quando premi il comando, mai da solo. macOS chiede ogni tanto di confermare il permesso."
                ), icon: "camera.viewfinder", level: .optional,
                state: ScreenshotService.hasPermission ? .granted : .missing, action: String(localized: "Consenti"))
        }
    }

    /// Calendars of an account (Exchange, Google, iCloud…) beyond the local "On My Mac" ones.
    static var hasSyncedCalendars: Bool {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return false }
        return EKEventStore().calendars(for: .event).contains {
            [.exchange, .calDAV].contains($0.source.sourceType)
        }
    }

    // MARK: Activation

    func activate(_ id: PermissionStep.ID) async {
        switch id {
        case .microphone:
            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .audio)
            } else {
                open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
            }
        case .systemAudio:
            guard await model.recorder.snapshot().state == .idle else {
                model.lastError = String(localized: "Ferma la registrazione in corso prima della prova.")
                return
            }
            checkingAudio = true
            let result = await AudioCheck.run(seconds: 5)
            checkingAudio = false
            try? model.archive.setSetting(Self.systemAudioKey, result.system ? "1" : nil)
            if !result.system { open("x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture") }
        case .notifications:
            let center = UNUserNotificationCenter.current()
            if (await center.notificationSettings()).authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
            } else {
                open("x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=com.giovannilombi.iago")
            }
            model.calls.testNotification()
        case .transcriptionModels:
            model.requestModelDownload?()
        case .loginItem:
            try? SMAppService.mainApp.register()
        case .calendar:
            await model.calls.calendar.enable(true)
        case .calendarAccounts:
            open("x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension")
        case .engine, .searchModel:
            model.settingsPane = .engine
        case .teamsAccessibility:
            model.calls.teamsAX.enabled = true
            if TeamsAccessibility.trusted == false {
                open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            }
        case .screenRecording:
            // The first time macOS asks; afterwards it is turned on only in System Settings.
            if !ScreenshotService.requestPermission() { ScreenshotService.openSystemSettings() }
        case .teamsAPI:
            model.calls.teams.enabled = true
            if let teams = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.teams2") {
                NSWorkspace.shared.open(teams)
            }
        }
        await refresh()
    }

    private func open(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}

/// Settings › Permessi: the checklist, each item activated with a click, and "Attiva quelli che mancano".
struct PermissionsPane: View {
    let model: AppModel
    @State private var center: PermissionCenter?
    @State private var guiding = false

    var body: some View {
        Group {
            if let center {
                content(center)
            } else {
                ProgressView()
            }
        }
        .task {
            let center = PermissionCenter(model: model)
            self.center = center
            // Settings stay open while the user flips switches elsewhere: keep the list current.
            while !Task.isCancelled {
                await center.refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    @ViewBuilder
    private func content(_ center: PermissionCenter) -> some View {
        let required = center.steps.filter { $0.level == .required }
        SettingsGroup(
            title: String(localized: "Per far funzionare IAGO al 100%"),
            footnote: String(
                localized:
                    "Ogni permesso serve a una cosa precisa e si può cambiare in qualsiasi momento. IAGO non chiede accessi che non usa."
            )
        ) {
            HStack {
                ProgressView(value: Double(center.grantedCount), total: Double(max(center.steps.count, 1)))
                    .frame(maxWidth: 260)
                Text(String(localized: "\(center.grantedCount) di \(center.steps.count) attivi"))
                    .monospacedDigit().foregroundStyle(.secondary)
                Spacer()
                Button(String(localized: "Attiva quelli che mancano")) { guiding = true }
                    .disabled(center.steps.allSatisfy { $0.state == .granted })
                    .buttonStyle(.borderedProminent)
            }
            if required.contains(where: { $0.state != .granted }) {
                Label(
                    String(localized: "Mancano permessi obbligatori: senza, IAGO non registra o non trascrive bene."),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption).foregroundStyle(.orange)
            }
        }
        SettingsGroup(title: String(localized: "Checklist")) {
            ForEach(center.steps) { step in
                PermissionRow(step: step, busy: step.id == .systemAudio && center.checkingAudio) {
                    Task { await center.activate(step.id) }
                }
                if step.id != center.steps.last?.id { Divider() }
            }
        }
        .sheet(isPresented: $guiding) {
            PermissionGuide(center: center)
        }
    }
}

struct PermissionRow: View {
    let step: PermissionStep
    var busy = false
    let activate: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.title3).foregroundStyle(color).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: step.icon).foregroundStyle(.secondary)
                    Text(step.title).fontWeight(.semibold)
                    Text(Self.levelLabel(step.level)).font(.caption2.weight(.semibold))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.12)))
                }
                Text(step.why).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if busy {
                ProgressView().controlSize(.small)
            } else if step.state == .granted {
                Text(String(localized: "Attivo")).font(.caption).foregroundStyle(.green)
            } else {
                Button(step.action, action: activate).controlSize(.small)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if step.state != .granted { activate() } }
    }

    private var icon: String {
        switch step.state {
        case .granted: "checkmark.circle.fill"
        case .missing: step.level == .optional ? "circle" : "exclamationmark.circle.fill"
        case .unknown: "questionmark.circle"
        }
    }

    private var color: Color {
        switch step.state {
        case .granted: .green
        case .missing: step.level == .required ? .orange : .secondary
        case .unknown: .secondary
        }
    }

    static func levelLabel(_ level: PermissionStep.Level) -> String {
        switch level {
        case .required: String(localized: "Obbligatorio")
        case .recommended: String(localized: "Consigliato")
        case .optional: String(localized: "Facoltativo")
        }
    }
}

/// "Attiva quelli che mancano": one step at a time, explained; the next one comes when this is active or skipped.
struct PermissionGuide: View {
    let center: PermissionCenter
    @Environment(\.dismiss) private var dismiss
    @State private var queue: [PermissionStep.ID] = []
    @State private var index = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let id = queue.indices.contains(index) ? queue[index] : nil,
                let step = center.steps.first(where: { $0.id == id })
            {
                Text(String(localized: "Passo \(index + 1) di \(queue.count)")).font(.caption).foregroundStyle(
                    .secondary)
                HStack(spacing: 12) {
                    Image(systemName: step.icon).font(.system(size: 30)).foregroundStyle(.tint).frame(width: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.title).font(.title2.bold())
                        Text(PermissionRow.levelLabel(step.level)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text(step.why).fixedSize(horizontal: false, vertical: true)
                if step.state == .granted {
                    Label(String(localized: "Fatto"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else if step.id == .systemAudio, center.checkingAudio {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text(String(localized: "Prova in corso: parla, IAGO riproduce una frase…"))
                    }
                } else {
                    Button(step.action) { Task { await center.activate(step.id) } }.buttonStyle(.borderedProminent)
                    Text(
                        String(
                            localized:
                                "Se si apre Impostazioni di Sistema, attiva IAGO lì e torna qui: la voce diventa verde da sola."
                        )
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Button(String(localized: "Chiudi"), role: .cancel) { dismiss() }
                    Spacer()
                    Button(step.state == .granted ? String(localized: "Continua") : String(localized: "Salta")) {
                        next()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            } else {
                Label(String(localized: "Tutto fatto"), systemImage: "checkmark.seal.fill").font(.title2.bold())
                    .foregroundStyle(.green)
                Text(
                    String(
                        localized:
                            "Attivi \(center.grantedCount) di \(center.steps.count). Quello che hai saltato lo trovi nella checklist, quando vuoi."
                    ))
                HStack {
                    Spacer()
                    Button(String(localized: "Chiudi")) { dismiss() }.keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24).frame(width: 520)
        .onAppear {
            queue = center.steps.filter { $0.state != .granted }.sorted { $0.level < $1.level }.map(\.id)
        }
    }

    private func next() { index += 1 }
}
