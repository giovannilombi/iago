import SwiftUI

/// "Guida di IAGO": the full user guide, full page, from Markdown chapters in the bundle (`Guide/NN-*.md`, images in
/// `Guide/img`). Updated with every change to the app (CLAUDE.md). Search looks through every chapter.
struct HelpView: View {
    let model: AppModel
    let showTour: () -> Void
    @State private var chapter: String? = GuideChapter.all.first?.id
    @State private var query = ""

    var body: some View {
        let chapters = GuideChapter.all.filter { query.isEmpty || $0.text.localizedCaseInsensitiveContains(query) }
        NavigationSplitView {
            List(chapters, selection: $chapter) { chapter in
                Label(chapter.title, systemImage: chapter.symbol).tag(chapter.id)
            }
            .listStyle(.sidebar)
            .searchable(text: $query, placement: .sidebar, prompt: Text(String(localized: "Cerca nella guida")))
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let current = GuideChapter.all.first(where: { $0.id == chapter }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        MarkdownText(markdown: current.text, baseURL: GuideChapter.folder)
                        if current.id.hasPrefix("01") {
                            Button(String(localized: "Rivedi l'introduzione"), action: showTour)
                                .buttonStyle(.borderedProminent)
                        }
                        navigation(current)
                    }
                    .padding(.horizontal, 48).padding(.top, 64).padding(.bottom, 32)
                    .frame(maxWidth: 860, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .id(current.id)
            } else {
                ContentUnavailableView.search(text: query)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        // «come?» in the app: the chapter asked for.
        .onChange(of: model.helpChapter, initial: true) { _, wanted in
            guard let wanted, let found = GuideChapter.all.first(where: { $0.id.hasPrefix(wanted) }) else { return }
            query = ""
            chapter = found.id
            model.helpChapter = nil
        }
    }

    /// "← Precedente · Successivo →" at the end of a chapter.
    private func navigation(_ current: GuideChapter) -> some View {
        let all = GuideChapter.all
        let index = all.firstIndex { $0.id == current.id } ?? 0
        return HStack {
            if index > 0 {
                Button("← \(all[index - 1].title)") { chapter = all[index - 1].id }.buttonStyle(.link)
            }
            Spacer()
            if index + 1 < all.count {
                Button("\(all[index + 1].title) →") { chapter = all[index + 1].id }.buttonStyle(.link)
            }
        }
        .padding(.top, 24)
    }
}

/// A chapter of the guide: `NN-name.md`, first line `# Title`, optionally `<!-- icona: sf.symbol -->`.
struct GuideChapter: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let text: String

    /// The guide in the app's language (ADR-0077): `Guide` in Italian, `Guide/en` in English.
    static let folder: URL? = {
        let italian = Bundle.main.url(forResource: "Guide", withExtension: nil)
        guard AppLanguage.current == .en, let english = italian?.appendingPathComponent("en"),
            FileManager.default.fileExists(atPath: english.path)
        else { return italian }
        return english
    }()

    static let all: [GuideChapter] = {
        guard let folder,
            let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        else { return [] }
        return files.filter { $0.pathExtension == "md" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                let lines = text.components(separatedBy: "\n")
                let title = lines.first { $0.hasPrefix("# ") }.map { String($0.dropFirst(2)) } ?? url.lastPathComponent
                let symbol =
                    lines.lazy.compactMap { $0.firstMatch(of: /<!--\s*icona:\s*([\w.]+)\s*-->/) }.first
                    .map { String($0.1) } ?? "doc.text"
                let body = lines.filter { !$0.hasPrefix("<!--") }.joined(separator: "\n")
                return GuideChapter(
                    id: url.deletingPathExtension().lastPathComponent, title: title, symbol: symbol, text: body)
            }
    }()
}
