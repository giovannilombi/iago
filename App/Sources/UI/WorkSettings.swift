import IAGOStore
import SwiftUI

/// Impostazioni › Generale, next to the mode: the kanban and the morning notification (ADR-0074).
struct WorkViewsSettings: View {
    let model: AppModel
    @State private var board = true
    @State private var morning = false
    @State private var time = Date()

    var body: some View {
        SettingsGroup(
            title: String(localized: "Lavoro aperto"),
            footnote: String(
                localized:
                    "La kanban c'è solo in Gestisci: spenta, le sue colonne libere e le posizioni delle voci restano salvate. La notifica del mattino arriva nei giorni lavorativi: cosa scade oggi, cosa è in ritardo, le attese scadute; un clic apre «Da fare»."
            )
        ) {
            Toggle(String(localized: "Mostra la kanban"), isOn: $board)
                .disabled(model.workViewsMode != .manage)
                .onChange(of: board) { _, value in
                    guard value != model.boardEnabled else { return }
                    model.perform { try model.archive.setSetting(Archive.boardEnabledKey, value ? nil : "0") }
                    model.reload()
                }
            HStack(spacing: 10) {
                Toggle(String(localized: "Notifica del mattino alle"), isOn: $morning)
                    .onChange(of: morning) { _, value in
                        guard value != WorkReminder.isEnabled(model.archive) else { return }
                        model.perform { try model.archive.setSetting(WorkReminder.enabledKey, value ? "1" : "0") }
                    }
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute).labelsHidden().fixedSize()
                    .disabled(!morning)
                    .onChange(of: time) { _, value in
                        let parts = Calendar.current.dateComponents([.hour, .minute], from: value)
                        let text = String(format: "%02d:%02d", parts.hour ?? 8, parts.minute ?? 30)
                        guard text != ((try? model.archive.setting(WorkReminder.timeKey)) ?? nil) else { return }
                        model.perform { try model.archive.setSetting(WorkReminder.timeKey, text) }
                    }
            }
        }
        .task(id: model.revision) {
            board = model.boardEnabled
            morning = WorkReminder.isEnabled(model.archive)
            let chosen = WorkReminder.time(model.archive)
            time =
                Calendar.current.date(bySettingHour: chosen.hour, minute: chosen.minute, second: 0, of: Date())
                ?? Date()
        }
    }
}
