import AVFoundation
import IAGOCapture
import IAGOCore
import IAGOTranscription
import SwiftUI
import UserNotifications

/// First launch (spec 14): welcome and privacy, what the Mac needs (nothing to install), the name for
/// "Io", microphone and system audio permissions with a 5-second test, notifications, model download.
struct OnboardingView: View {
    let model: AppModel
    let finish: () -> Void

    enum Step: Int, CaseIterable {
        case welcome, requirements, name, microphone, systemAudio, notifications, models, done
    }
    @State private var step = Step.welcome

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { item in
                    Capsule().fill(item.rawValue <= step.rawValue ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 28).padding(.top, 18)
            Group {
                switch step {
                case .welcome: WelcomeStep(model: model)
                case .requirements: RequirementsStep(model: model)
                case .name: NameStep(model: model)
                case .microphone: MicrophoneStep()
                case .systemAudio: SystemAudioStep(model: model)
                case .notifications: NotificationsStep()
                case .models: ModelsStep(model: model)
                case .done: DoneStep()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(28)
            Divider()
            HStack {
                if step != .welcome {
                    Button(String(localized: "Indietro")) { step = Step(rawValue: step.rawValue - 1)! }
                }
                Spacer()
                Text("Giovanni Lombi · CC BY-NC-SA 4.0").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                if step == .done {
                    Button(String(localized: "Inizia a usare IAGO"), action: finish).keyboardShortcut(.defaultAction)
                } else {
                    Button(String(localized: "Avanti")) { step = Step(rawValue: step.rawValue + 1)! }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
        }
        .frame(width: 640, height: 520)
    }
}

private struct StepHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.system(size: 30)).foregroundStyle(.tint)
            Text(title).font(.title).bold()
            Text(subtitle).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 12)
    }
}

private struct CheckRow: View {
    let ok: Bool?
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: ok == nil ? "circle" : ok! ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok == nil ? Color.secondary : ok! ? Color.green : Color.red)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WelcomeStep: View {
    let model: AppModel
    @State private var restoring = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image("Logo").resizable().scaledToFit().frame(width: 72, height: 72)
                VStack(alignment: .leading) {
                    Text(String(localized: "Benvenuto in IAGO")).font(.largeTitle).bold()
                    Text(String(localized: "Le tue call, trascritte e organizzate. Solo sul tuo Mac.")).foregroundStyle(
                        .secondary)
                }
            }
            PrivacySummary()
            // Moving to a new Mac: the whole archive comes back from an encrypted backup (ADR-0041).
            Button {
                restoring = true
            } label: {
                Label(
                    String(localized: "Arrivi da un altro Mac? Ripristina un backup di IAGO…"),
                    systemImage: "arrow.counterclockwise.circle")
            }
            .buttonStyle(.link)
        }
        .sheet(isPresented: $restoring) { RestoreBackupSheet(model: model) }
    }
}

/// Everything IAGO needs is inside the app: no Homebrew, no Python, no other installs. The only
/// download is the models, one click later on.
private struct RequirementsStep: View {
    let model: AppModel
    private var freeSpace: Int64 {
        (try? model.archiveService.paths.root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage) ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StepHeader(
                icon: "checklist", title: String(localized: "Cosa serve"),
                subtitle: String(
                    localized:
                        "Non devi installare nient'altro: il motore di trascrizione, l'archivio cifrato e la lettura dei documenti sono già dentro IAGO."
                ))
            CheckRow(
                ok: ProcessInfo.processInfo.isOperatingSystemAtLeast(
                    .init(majorVersion: 15, minorVersion: 0, patchVersion: 0)),
                text: String(localized: "macOS 15 o successivo"))
            CheckRow(ok: Self.isAppleSilicon, text: String(localized: "Mac con processore Apple (M1 o successivo)"))
            CheckRow(
                ok: freeSpace > 4_000_000_000,
                text: String(localized: "Almeno 4 GB liberi (\(Format.bytes(freeSpace)) disponibili)"))
            CheckRow(ok: true, text: String(localized: "Niente Homebrew, Python o altre installazioni"))
            CheckRow(
                ok: nil,
                text: String(localized: "Modelli di trascrizione: si scaricano tra poco con un clic (circa 1,6 GB)"))
        }
    }

    static var isAppleSilicon: Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("hw.optional.arm64", &value, &size, nil, 0) == 0 && value == 1
    }
}

private struct NameStep: View {
    let model: AppModel
    @State private var name = "Io"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StepHeader(
                icon: "person.crop.circle", title: String(localized: "Come ti chiami nelle trascrizioni?"),
                subtitle: String(
                    localized:
                        "La tua voce, presa dal microfono del Mac, comparirà con questo nome. Puoi cambiarlo nelle Impostazioni."
                ))
            TextField(String(localized: "Io"), text: $name).textFieldStyle(.roundedBorder).frame(width: 280)
                .onChange(of: name) { _, value in
                    let trimmed = value.trimmingCharacters(in: .whitespaces)
                    model.perform {
                        try model.archive.setSetting(TranscriptionService.meLabelKey, trimmed.isEmpty ? nil : trimmed)
                    }
                }
        }
        .onAppear { name = (try? model.archive.setting(TranscriptionService.meLabelKey)) ?? "Io" }
    }
}

private struct MicrophoneStep: View {
    @State private var status = AVCaptureDevice.authorizationStatus(for: .audio)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StepHeader(
                icon: "mic", title: String(localized: "Microfono"),
                subtitle: String(
                    localized:
                        "Serve per registrare la tua voce durante le call. IAGO registra solo quando lo avvii tu."))
            CheckRow(ok: status == .notDetermined ? nil : status == .authorized, text: statusText)
            if status == .notDetermined {
                Button(String(localized: "Consenti l'accesso al microfono")) {
                    Task {
                        _ = await AVCaptureDevice.requestAccess(for: .audio)
                        status = AVCaptureDevice.authorizationStatus(for: .audio)
                    }
                }
            } else if status != .authorized {
                Button(String(localized: "Apri Impostazioni di Sistema")) {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                }
            }
        }
    }

    private var statusText: String {
        switch status {
        case .authorized: String(localized: "Accesso al microfono consentito")
        case .notDetermined: String(localized: "Non ancora richiesto")
        default: String(localized: "Accesso negato: attivalo in Privacy e sicurezza › Microfono")
        }
    }
}

/// Spec 14: system audio permission, verified with a 5-second test on both tracks (there is no public
/// API to read that permission, spec 15).
private struct SystemAudioStep: View {
    let model: AppModel
    @State private var running = false
    @State private var result: AudioCheck.Result?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StepHeader(
                icon: "speaker.wave.2", title: String(localized: "Audio di sistema e prova"),
                subtitle: String(
                    localized:
                        "IAGO registra anche l'audio che esce dal Mac (le voci degli altri nella call). Fai una prova di 5 secondi: IAGO riproduce una frase e tu parla. macOS potrebbe chiederti il permesso."
                ))
            Button(running ? String(localized: "Prova in corso…") : String(localized: "Fai la prova (5 secondi)")) {
                runTest()
            }
            .disabled(running)
            if running { ProgressView().controlSize(.small) }
            if let result {
                CheckRow(
                    ok: result.mic,
                    text: result.mic
                        ? String(localized: "Microfono: segnale ricevuto")
                        : String(localized: "Microfono: nessun segnale. Hai parlato? Controlla il permesso."))
                CheckRow(
                    ok: result.system,
                    text: result.system
                        ? String(localized: "Audio di sistema: segnale ricevuto")
                        : String(
                            localized:
                                "Audio di sistema: nessun segnale. Consenti \"Registrazione audio\" a IAGO in Privacy e sicurezza."
                        ))
                if !result.system {
                    Button(String(localized: "Apri Impostazioni di Sistema")) {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture")!
                        )
                    }
                }
            }
        }
    }

    private func runTest() {
        running = true
        result = nil
        Task {
            if await model.recorder.snapshot().state != .idle {
                model.lastError = String(localized: "Ferma la registrazione in corso prima della prova.")
            } else {
                let check = await AudioCheck.run(seconds: 5)
                result = check
                // Settings › Permessi shows the system audio permission from this test (no public API reads it).
                try? model.archive.setSetting(PermissionCenter.systemAudioKey, check.system ? "1" : nil)
            }
            running = false
        }
    }
}

/// Captures both tracks for a few seconds, speaking a sentence through the speakers, and reports which
/// track had signal. Nothing is saved.
enum AudioCheck {
    struct Result { var mic: Bool; var system: Bool }

    private final class Peaks: @unchecked Sendable {
        let lock = NSLock()
        var mic: Float = 0
        var system: Float = 0
        func add(_ buffer: CapturedBuffer) {
            let peak = buffer.samples.reduce(0) { max($0, abs($1)) }
            lock.withLock {
                if buffer.track == .mic { mic = max(mic, peak) } else { system = max(system, peak) }
            }
        }
    }

    @MainActor
    static func run(seconds: Double) async -> Result {
        let peaks = Peaks()
        let engine = CaptureEngine(onBuffer: { peaks.add($0) }, onEvent: { _ in })
        do { try engine.start() } catch { return Result(mic: false, system: false) }
        // Spoken by a separate process: the system tap excludes IAGO's own audio (spec 6.1), so a sound
        // played by IAGO itself would never reach the system track.
        let voice = Process()
        voice.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        voice.arguments = [String(localized: "Prova audio di IAGO. Ora parla anche tu.")]
        try? voice.run()
        try? await Task.sleep(for: .seconds(seconds))
        engine.stop()
        // -50 dBFS: well above silence, below any voice.
        let threshold: Float = 0.003
        return peaks.lock.withLock { Result(mic: peaks.mic > threshold, system: peaks.system > threshold) }
    }
}

private struct NotificationsStep: View {
    @State private var granted: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StepHeader(
                icon: "bell.badge", title: String(localized: "Notifiche"),
                subtitle: String(
                    localized:
                        "Per avvisarti quando una trascrizione è pronta o una registrazione interrotta è stata recuperata. Facoltative."
                ))
            if let granted {
                CheckRow(
                    ok: granted,
                    text: granted
                        ? String(localized: "Notifiche attive")
                        : String(localized: "Notifiche disattivate: gli avvisi importanti compariranno in una finestra")
                )
            } else {
                Button(String(localized: "Attiva le notifiche")) {
                    Task {
                        granted =
                            (try? await UNUserNotificationCenter.current().requestAuthorization(options: [
                                .alert, .sound,
                            ])) ?? false
                    }
                }
            }
        }
    }
}

private struct ModelsStep: View {
    let model: AppModel
    @State private var progress: Double?
    @State private var done = false
    @State private var error: String?

    var body: some View {
        let missing = model.transcription.models.missing()
        VStack(alignment: .leading, spacing: 12) {
            StepHeader(
                icon: "arrow.down.circle", title: String(localized: "Modelli di trascrizione"),
                subtitle: String(
                    localized:
                        "Per trascrivere senza internet IAGO usa modelli che restano sul Mac. Si scaricano una volta sola da indirizzi fissi e vengono verificati; il download è registrato nel registro accessi."
                ))
            if missing.isEmpty || done {
                CheckRow(ok: true, text: String(localized: "Modelli presenti e verificati"))
            } else if let progress {
                ProgressView(value: progress) { Text(String(localized: "Download in corso… \(Int(progress * 100))%")) }
            } else {
                ForEach(missing) { CheckRow(ok: nil, text: "\($0.displayName) · \(Format.bytes($0.approximateBytes))") }
                Button(String(localized: "Scarica i modelli")) { download() }
                Text(String(localized: "Puoi anche farlo più tardi da Impostazioni › Spazio.")).font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let error { Text(error).foregroundStyle(.red).font(.caption) }
        }
    }

    private func download() {
        progress = 0
        error = nil
        Task {
            do {
                try await model.transcription.downloadMissingModels { value in Task { @MainActor in progress = value } }
                done = true
            } catch {
                self.error = String(localized: "Download non riuscito: \(ErrorText.describe(error))")
            }
            progress = nil
        }
    }
}

private struct DoneStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StepHeader(
                icon: "checkmark.seal", title: String(localized: "Tutto pronto"),
                subtitle: String(localized: "IAGO vive nella barra dei menu, in alto a destra."))
            CheckRow(
                ok: true,
                text: String(localized: "Clic destro sull'icona: avvia, metti in pausa e riprendi la registrazione"))
            CheckRow(
                ok: true,
                text: String(localized: "Clic sinistro: menu con Stop, Segna momento, Apri IAGO e Impostazioni"))
            CheckRow(
                ok: true,
                text: String(localized: "Dopo lo Stop scegli se trascrivere: tutto resta cifrato su questo Mac"))
        }
    }
}
