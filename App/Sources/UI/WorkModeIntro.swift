import IAGOStore
import SwiftUI

/// The sheet on a visit to a project, or to a client (ADR-0076): which mode it is in, what each mode gives, and the
/// choice. «OK» keeps the choice and shows the sheet again next time; «Non mostrare più» stops it for this project or
/// client. On a client the choice is for its projects without a mode of their own, and for its new projects.
struct WorkModeIntroSheet: View {
    let model: AppModel
    let intro: AppModel.ModeIntro
    @Environment(\.dismiss) private var dismiss

    private var mode: WorkMode {
        _ = model.revision
        switch intro {
        case .project(let id): return model.workMode(for: id)
        case .client(let id): return model.clientWorkMode(id)
        }
    }

    private var title: String {
        switch intro {
        case .project(let id):
            let name = model.project(id)?.name ?? ""
            return String(localized: "\(name) è in \(WorkModeText.fullTitle(mode))")
        case .client(let id):
            return String(
                localized: "I progetti di \(model.client(id)?.name ?? "") sono in \(WorkModeText.fullTitle(mode))")
        }
    }

    private var message: String {
        switch intro {
        case .project:
            String(
                localized:
                    "Scegli quanto vuoi seguire questo progetto. In Traccia e Gestisci scrivi decisioni, attività, rischi e gli altri punti chiave; Raccogli tiene solo i contenuti. Puoi cambiarla quando vuoi: non si perde niente."
            )
        case .client:
            String(
                localized:
                    "Vale per i progetti nuovi di questo cliente e per quelli a cui non hai scelto una modalità. In Traccia e Gestisci scrivi decisioni, attività, rischi e gli altri punti chiave; Raccogli tiene solo i contenuti."
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title2).bold().fixedSize(horizontal: false, vertical: true)
            Text(message).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 12) {
                ForEach(WorkMode.allCases, id: \.self) { option in
                    Button {
                        choose(option)
                    } label: {
                        card(option)
                    }
                    .buttonStyle(.plain)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Text(String(localized: "La cambi quando vuoi dalla pillola accanto al nome del progetto."))
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Button(String(localized: "Non mostrare più")) {
                    model.dismissModeIntroForever(intro)
                    dismiss()
                }
                Spacer()
                Button(String(localized: "OK")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 760)
    }

    private func card(_ option: WorkMode) -> some View {
        let selected = option == mode
        let tint = WorkModeText.color(option)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: WorkModeText.icon(option))
                Text(WorkModeText.fullTitle(option)).bold()
                Spacer(minLength: 0)
                if selected { Image(systemName: "checkmark.circle.fill") }
            }
            .foregroundStyle(tint)
            Text(Self.subtitle(option))
                .font(.callout.weight(.medium))
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Self.points(option), id: \.self) { point in
                    Label(point, systemImage: "circle.fill").labelStyle(BulletLabelStyle())
                }
            }
            .font(.callout).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10).fill(selected ? tint.opacity(0.08) : Color.clear))
        .overlay(
            RoundedRectangle(cornerRadius: 10).stroke(
                selected ? tint : Color.secondary.opacity(0.3), lineWidth: selected ? 2 : 1)
        )
        .contentShape(Rectangle())
    }

    static func subtitle(_ mode: WorkMode) -> String {
        switch mode {
        case .collect: String(localized: "La più semplice: solo i contenuti")
        case .track: String(localized: "Semplice e veloce")
        case .manage: String(localized: "La completa")
        }
    }

    static func points(_ mode: WorkMode) -> [String] {
        switch mode {
        case .collect:
            [
                String(localized: "Elementi e Timeline"),
                String(localized: "Trascrizioni, segnalibri, schermate, sintesi e proposte"),
                String(localized: "Per interviste, archivi e materiali da interrogare"),
            ]
        case .track:
            [
                String(localized: "Riepilogo breve, Elementi e Timeline"),
                String(localized: "Attività da spuntare, con chi ed entro quando"),
                String(localized: "Per chi vuole ricordare, non pianificare"),
            ]
        case .manage:
            [
                String(localized: "Riepilogo completo, Kanban e Grafo"),
                String(localized: "Stati, priorità, dipendenze, ricorrenze"),
                String(localized: "Per chi segue il progetto ogni giorno"),
            ]
        }
    }

    private func choose(_ option: WorkMode) {
        switch intro {
        case .project(let id): model.chooseProjectWorkMode(id, option)
        case .client(let id): model.setClientWorkMode(id, option)
        }
    }
}

/// A small dot before the text, for short lists.
private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            configuration.icon.font(.system(size: 4)).alignmentGuide(.firstTextBaseline) { $0[.bottom] + 3 }
            configuration.title
        }
    }
}
