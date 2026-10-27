import AppKit
import SwiftUI

/// Impostazioni › Generale › Scorciatoie (ADR-0072): the shortcuts that work in any app, to change, reset or turn
/// off, and how «Segna momento con screenshot» captures the screen.
struct ShortcutSettings: View {
    let model: AppModel
    let shortcuts: GlobalShortcuts
    @State private var recording: GlobalShortcuts.Action?
    @State private var monitor: Any?
    @State private var revision = 0
    @State private var allScreens = false
    /// The last combination refused, and why.
    @State private var refused: String?

    var body: some View {
        SettingsGroup(
            title: String(localized: "Scorciatoie in tutte le app"),
            footnote: String(
                localized:
                    "Funzionano anche quando sei in Teams o in un'altra app. Per cambiarne una premi «Cambia…» e poi la nuova combinazione, con ⌃ o ⌥ (anche insieme a ⌘ o ⇧)."
            )
        ) {
            let _ = revision
            if let refused {
                Label(refused, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
            }
            ForEach(GlobalShortcuts.Action.allCases) { action in
                HStack {
                    Text(action.title)
                    Spacer()
                    if recording == action {
                        Text(String(localized: "Premi la combinazione… (Esc per annullare)")).foregroundStyle(.tint)
                    } else if let shortcut = shortcuts.shortcut(action) {
                        Text(shortcut.display).monospaced().padding(.horizontal, 6)
                            .background(RoundedRectangle(cornerRadius: 4).fill(.quaternary))
                        if shortcuts.unavailable.contains(action) {
                            Label(String(localized: "Usata da un'altra app"), systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    } else {
                        Text(String(localized: "Disattivata")).foregroundStyle(.secondary)
                    }
                    Menu(String(localized: "Cambia…")) {
                        Button(String(localized: "Nuova combinazione…")) { record(action) }
                        Button(String(localized: "Predefinita (\(action.defaultShortcut.display))")) {
                            shortcuts.reset(action)
                            revision += 1
                        }
                        Button(String(localized: "Disattiva")) {
                            shortcuts.set(nil, for: action)
                            revision += 1
                        }
                    }
                    .fixedSize()
                }
            }
        }
        SettingsGroup(
            title: String(localized: "Segna momento con screenshot"),
            footnote: String(
                localized:
                    "La schermata entra nella call al minuto in cui la fai, con il testo letto dal Mac. Le finestre di IAGO non compaiono. Serve il permesso Registrazione schermo (Impostazioni › Permessi)."
            )
        ) {
            Toggle(String(localized: "Cattura tutti gli schermi (non solo quello con il puntatore)"), isOn: $allScreens)
                .onChange(of: allScreens) { _, value in
                    model.perform { try model.archive.setSetting(ScreenshotService.allScreensKey, value ? "1" : "0") }
                }
        }
        .onAppear { allScreens = (try? model.archive.setting(ScreenshotService.allScreensKey)) == "1" }
        .onDisappear { stopRecording() }
    }

    private func record(_ action: GlobalShortcuts.Action) {
        stopRecording()
        shortcuts.suspend()
        recording = action
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {  // Esc
                stopRecording()
                return nil
            }
            guard let shortcut = GlobalShortcuts.Shortcut(event: event) else {
                refused = String(
                    localized: "Serve ⌃ o ⌥ nella combinazione: le scorciatoie con solo ⌘ appartengono alle altre app.")
                return nil
            }
            if let other = GlobalShortcuts.Action.allCases.first(where: {
                $0 != action && shortcuts.shortcut($0) == shortcut
            }) {
                refused = String(localized: "\(shortcut.display) è già usata per «\(other.title)».")
                return nil
            }
            refused = nil
            shortcuts.set(shortcut, for: action)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording != nil { shortcuts.start() }
        recording = nil
        revision += 1
    }
}
