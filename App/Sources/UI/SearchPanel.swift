import SwiftUI

/// «Ricerca semplice» in the right pane (ADR-0092), where «Chiedi a IAGO» also opens: what it does and when to use it,
/// the field, the results (they open in the detail and stay here), and the way to IAGO for answers.
struct SearchPanel: View {
    @Bindable var model: AppModel
    @FocusState private var focused: Bool

    private var hasText: Bool { !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty }
    private var suggests: Bool {
        let text = model.searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return text.hasPrefix("#") || text.hasPrefix("categoria:") || text.hasPrefix("category:")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 10) {
                Text(
                    model.engine.embedder == nil
                        ? String(
                            localized:
                                "Trova i passaggi con le parole che scrivi in trascrizioni, note, email, documenti e punti chiave, con il minuto della call. Usala quando sai cosa cercare: un nome, una sigla, un numero, una frase detta. Accetta anche #tag e categoria:."
                        )
                        : String(
                            localized:
                                "Trova i passaggi con le parole che scrivi, e quelli che dicono la stessa cosa con altre parole, in trascrizioni, note, email, documenti e punti chiave, con il minuto della call. Usala quando sai cosa cercare: un nome, una sigla, un numero, una frase detta. Accetta anche #tag e categoria:."
                        )
                )
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(
                        String(
                            localized: "Cerca nell'archivio  ·  #tag  ·  categoria:",
                            comment: "In English the prefix is «category:»"),
                        text: $model.searchText
                    )
                    .textFieldStyle(.plain).focused($focused)
                    if hasText {
                        Button {
                            model.searchText = ""
                            focused = true
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain).help(String(localized: "Cancella la ricerca"))
                    }
                }
                .padding(.horizontal, 9).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8).strokeBorder(
                        focused ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: focused ? 2 : 1))
                if suggests {
                    VStack(alignment: .leading, spacing: 4) { LabelSuggestions(model: model) }
                        .buttonStyle(.plain).foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 14).padding(.bottom, 8)
            if hasText, !suggests {
                SearchResultsView(model: model)
            } else {
                Spacer(minLength: 0)
            }
            askIAGO
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { focused = true }
        .onChange(of: model.searchFocusRequest) { focused = true }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
            Text(String(localized: "Ricerca semplice")).font(.headline)
            Spacer()
            Button {
                model.showsSearch = false
            } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                    .frame(width: 26, height: 26).contentShape(Rectangle())
            }
            .buttonStyle(.plain).keyboardShortcut(.cancelAction)
            .help(String(localized: "Chiudi la ricerca"))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    /// The simple search finds words; answers come from IAGO.
    private var askIAGO: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                String(
                    localized:
                        "Ti serve una risposta, un riassunto o un confronto? La ricerca semplice non usa l'AI: trova i passaggi. Per le risposte con le fonti chiedi a IAGO."
                )
            )
            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button {
                model.showsChat = true
            } label: {
                HStack(spacing: 7) {
                    IAGOMark(size: 20)
                    Text(String(localized: "Chiedi a IAGO")).font(.callout.weight(.medium))
                }
                .padding(.leading, 4).padding(.trailing, 10).padding(.vertical, 4)
                .background(Capsule().fill(.regularMaterial))
                .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.2)))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.16)))
        .padding(14)
    }
}
