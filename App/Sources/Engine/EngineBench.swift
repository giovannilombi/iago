import AppKit
import IAGOCore
import IAGOEngine
import IAGOExport
import IAGOIntelligence
import IAGOStore
import os

/// The trial of the installed engines on one of the user's calls, to choose the default (ADR-0048). A developer
/// tool: `open /Applications/IAGO.app --args -IAGOEngineBench "Kickoff"` runs every downloaded model on that
/// call with the extraction rules of `KeyPointExtractor` and on three passages for "Riordina testo", then writes to
/// `Application Support/IAGO/bench-out/<date>/`:
/// - `scheda.html`, a blind scorecard (no model names) the user marks in the browser and saves as JSON;
/// - `chiave.json`, which model wrote what;
/// - `rapporto.md`, times, memory and what IAGO discarded.
/// Nothing leaves the Mac; the files contain call text, so they never go in the repository.
enum EngineBench {
    static let key = "IAGOEngineBench"
    /// `-IAGOSummaryBench "Fondo=clientSales|TEAM LEAD"`: the summary of each call (part of its title, optionally
    /// `=template`) with every downloaded model, or only `-IAGOSummaryModel <id>` (ADR-0054), into
    /// `bench-out/<date>/`: `callN-sintesi-<model>.md`, `callN-trascrizione.txt` to check them, `sintesi-rapporto.md`.
    /// Reads the archive, writes nothing in it.
    static let summaryKey = "IAGOSummaryBench"

    @MainActor
    static func summaryIfRequested(archive: Archive, engine: EngineService, root: URL, notifier: Notifier) async {
        guard let wanted = UserDefaults.standard.string(forKey: summaryKey), !wanted.isEmpty else { return }
        let logger = Logger(subsystem: "com.giovannilombi.iago", category: "engine")
        let calls = ((try? archive.summaries(.recent)) ?? []).filter { $0.item.type == .call && $0.hasTranscript }
        let folder = root.appendingPathComponent("bench-out/\(Int(Date().timeIntervalSince1970))", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var report = ["# Prova delle sintesi", "", Date().formatted(date: .abbreviated, time: .shortened)]
        let only = UserDefaults.standard.string(forKey: "IAGOSummaryModel").map {
            Set($0.split(separator: ",").map(String.init))
        }
        // "Fondo=clientSales|TEAM LEAD": calls by part of the title, each with an optional template.
        for (index, request) in wanted.split(separator: "|").enumerated() {
            let parts = request.split(separator: "=", maxSplits: 1).map {
                String($0).trimmingCharacters(in: .whitespaces)
            }
            guard let call = calls.first(where: { $0.item.title.localizedCaseInsensitiveContains(parts[0]) }),
                let document = try? ItemDocument.load(call.id, from: archive), let transcript = document.transcript
            else {
                report += ["", "## «\(parts[0])»: nessuna call trascritta con questo titolo"]
                continue
            }
            let category = call.item.categoryId.flatMap { try? archive.category($0) }
            let template =
                SummaryLibrary.template(parts.count > 1 ? parts[1] : nil)
                ?? IntelligenceService.template(for: category) ?? SummaryLibrary.template("standard")!
            let names = Dictionary(uniqueKeysWithValues: transcript.speakers.map { ($0.id, $0.label) })
                .merging(document.speakerLabels) { $1 }
            let lines = transcript.segments.map {
                KeyPointExtractor.Line(atSec: $0.start, speaker: names[$0.speaker] ?? $0.speaker, text: $0.text)
            }
            let participants = Set(names.values).filter(DecisionDraft.isPersonName).sorted()
            let slug = "call\(index + 1)"
            // The transcript next to the summaries, to check every point (local only, never in the repository).
            try? lines.map { "[\(TranscriptRenderer.clock($0.atSec))] \($0.speaker): \($0.text)" }
                .joined(separator: "\n")
                .write(to: folder.appendingPathComponent("\(slug)-trascrizione.txt"), atomically: true, encoding: .utf8)
            report += [
                "", "# \(slug): «\(call.item.title)»", "",
                "Modello di sintesi: \(template.name) · \(lines.count) battute · durata \(Int((call.item.durationSec ?? 0) / 60)) min",
            ]
            for model in EngineCatalog.models
            where engine.library.isInstalled(model) && (only?.contains(model.id) ?? true) {
                let provider = MLXProvider(model: model, folder: engine.library.folder(of: model))
                await provider.resetPeakMemory()
                do {
                    try await provider.warmUp()
                    let started = ContinuousClock.now
                    let result = try await SummaryGenerator.generate(
                        .init(
                            lines: lines, template: template, date: call.item.occurredAt, participants: participants,
                            title: call.item.title), with: provider)
                    let time = started.duration(to: .now).components.seconds
                    let kept = result.sections.reduce(0) { $0 + $1.points.count }
                    try? result.markdown.write(
                        to: folder.appendingPathComponent("\(slug)-sintesi-\(model.id).md"), atomically: true,
                        encoding: .utf8)
                    try? result.answers.enumerated().map { "=== blocco \($0.offset + 1)\n\($0.element)" }
                        .joined(separator: "\n\n")
                        .write(
                            to: folder.appendingPathComponent("\(slug)-risposte-\(model.id).txt"), atomically: true,
                            encoding: .utf8)
                    report += [
                        "", "## \(model.name)", "",
                        "- Tempo: \(time) s; punti tenuti: \(kept); scartati da IAGO: \(result.discarded.count)",
                        "- Memoria GPU di picco: \(ByteCountFormatter.string(fromByteCount: Int64(await provider.memory().peak), countStyle: .memory))",
                    ]
                    report += result.discarded.map { "  - scartato («\($0.reason)»): \($0.point)" }
                } catch {
                    report += ["", "## \(model.name)", "", "- **Errore:** \(error)"]
                }
                await provider.free()
                logger.notice("Summary bench: \(slug, privacy: .public) \(model.id, privacy: .public) done")
            }
        }
        try? report.joined(separator: "\n").write(
            to: folder.appendingPathComponent("sintesi-rapporto.md"), atomically: true, encoding: .utf8)
        notifier.post(
            title: String(localized: "Prova delle sintesi completata"), body: folder.lastPathComponent)
    }

    struct Run {
        var model: EngineModel
        var load: Duration = .zero
        var extraction: Duration = .zero
        var result: KeyPointExtractor.Result?
        var failure: String?
        var tidies: [(text: String, time: Duration, missing: [String])] = []
        var peakBytes = 0
    }

    @MainActor
    static func runIfRequested(archive: Archive, engine: EngineService, root: URL, notifier: Notifier) async {
        guard let wanted = UserDefaults.standard.string(forKey: key), !wanted.isEmpty else { return }
        let logger = Logger(subsystem: "com.giovannilombi.iago", category: "engine")
        let calls = ((try? archive.summaries(.recent)) ?? []).filter { $0.item.type == .call && $0.hasTranscript }
        guard
            let call = calls.first(where: { $0.item.title.localizedCaseInsensitiveContains(wanted) })
                ?? calls.max(by: { $0.item.occurredAt < $1.item.occurredAt }),
            let document = try? ItemDocument.load(call.id, from: archive), let transcript = document.transcript
        else {
            logger.notice("Engine bench: no transcribed call")
            return
        }
        let models = EngineCatalog.models.filter { engine.library.isInstalled($0) }
        guard !models.isEmpty else { return }
        let names = Dictionary(uniqueKeysWithValues: transcript.speakers.map { ($0.id, $0.label) })
            .merging(document.speakerLabels) { $1 }
        let lines = transcript.segments.map {
            KeyPointExtractor.Line(atSec: $0.start, speaker: names[$0.speaker] ?? $0.speaker, text: $0.text)
        }
        let passages = Self.passages(transcript.segments)

        var runs: [Run] = []
        for model in models {
            var run = Run(model: model)
            let provider = MLXProvider(model: model, folder: engine.library.folder(of: model))
            await provider.resetPeakMemory()
            do {
                var started = ContinuousClock.now
                try await provider.warmUp()
                run.load = started.duration(to: .now)
                started = .now
                run.result = try await KeyPointExtractor.extract(lines, with: provider)
                run.extraction = started.duration(to: .now)
                for passage in passages {
                    started = .now
                    let tidied = try await TextTidier.tidy(passage, with: provider)
                    run.tidies.append(
                        (tidied, started.duration(to: .now), TextTidier.missingFacts(original: passage, tidied: tidied))
                    )
                }
            } catch {
                run.failure = "\(error)"
            }
            run.peakBytes = await provider.memory().peak
            await provider.free()
            runs.append(run)
            logger.notice("Engine bench: \(model.id, privacy: .public) done")
        }

        let folder = root.appendingPathComponent("bench-out/\(Int(Date().timeIntervalSince1970))", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let card = Scorecard(call: call.item.title, runs: runs, passages: passages).render()
        try? card.html.write(to: folder.appendingPathComponent("scheda.html"), atomically: true, encoding: .utf8)
        try? card.key.write(to: folder.appendingPathComponent("chiave.json"), atomically: true, encoding: .utf8)
        try? report(call.item.title, runs).write(
            to: folder.appendingPathComponent("rapporto.md"), atomically: true, encoding: .utf8)
        notifier.post(
            title: String(localized: "Prova dei motori completata"),
            body: String(localized: "La scheda da segnare è aperta nel browser."))
        NSWorkspace.shared.open(folder.appendingPathComponent("scheda.html"))
    }

    /// Three passages of about 1,500 characters, from the start, the middle and the end of the call.
    static func passages(_ segments: [Transcript.Segment]) -> [String] {
        guard !segments.isEmpty else { return [] }
        return [0.1, 0.45, 0.8].map { position in
            var text = ""
            for segment in segments[Int(Double(segments.count) * position)...] {
                text += (text.isEmpty ? "" : " ") + segment.text
                if text.count >= 1_500 { break }
            }
            return text
        }
    }

    static func report(_ title: String, _ runs: [Run]) -> String {
        func seconds(_ duration: Duration) -> String { "\(duration.components.seconds) s" }
        var lines = [
            "# Prova dei motori — «\(title)»", "", "\(Date().formatted(date: .abbreviated, time: .shortened))",
        ]
        for run in runs {
            lines += ["", "## \(run.model.name)", ""]
            if let failure = run.failure { lines.append("- **Errore:** \(failure)") }
            let weights = run.model.files.filter { $0.path.hasSuffix(".safetensors") }.reduce(0) { $0 + $1.size }
            lines += [
                "- Caricamento: \(seconds(run.load)); estrazione: \(seconds(run.extraction))",
                "- Riordino dei 3 passaggi: " + run.tidies.map { seconds($0.time) }.joined(separator: ", "),
                "- Memoria GPU di picco: \(ByteCountFormatter.string(fromByteCount: Int64(run.peakBytes), countStyle: .memory)) (pesi \(ByteCountFormatter.string(fromByteCount: weights, countStyle: .file)))",
            ]
            if let result = run.result {
                lines.append("- Proposte tenute: \(result.items.count); scartate da IAGO: \(result.discarded.count)")
                for discarded in result.discarded {
                    lines.append("  - scartata («\(discarded.reason)»): \(discarded.item)")
                }
            }
            for (index, tidy) in run.tidies.enumerated() where !tidy.missing.isEmpty {
                lines.append("- Passaggio \(index + 1), fatti persi: \(tidy.missing.joined(separator: ", "))")
            }
        }
        return lines.joined(separator: "\n")
    }
}

/// The blind scorecard: proposals of every model shuffled and merged when identical, passages tidied by each model as
/// A/B/C. Plain HTML with inline style and script, no network; "Salva risultati" downloads a JSON file.
struct Scorecard {
    let call: String
    let runs: [EngineBench.Run]
    let passages: [String]

    struct Entry {
        var id: String
        var point: ProposedKeyPoint
        var models: [String]
    }

    private var entries: [Entry] {
        var merged: [String: Entry] = [:]
        for run in runs {
            for point in run.result?.items ?? [] {
                let key = point.kind.rawValue + "|" + point.text.lowercased().filter { $0.isLetter || $0.isNumber }
                merged[key, default: Entry(id: "", point: point, models: [])].models.append(run.model.id)
            }
        }
        var list = Array(merged.values).shuffled()
        for index in list.indices { list[index].id = "p\(index + 1)" }
        return list.sorted { $0.point.atSec < $1.point.atSec }
    }

    /// For every passage, which letter is which model, shuffled once.
    private var letters: [[String]] {
        passages.indices.map { _ in runs.map(\.model.id).shuffled() }
    }

    /// Shuffles once: the page and its key must come from the same order.
    func render() -> (html: String, key: String) {
        let entries = entries
        let letters = letters
        var body = ""
        body += "<h1>Prova dei motori</h1><p class=sub>Call «\(escape(call))». I modelli non sono indicati.</p>"
        body += "<h2>1. Decisioni e attività proposte</h2>"
        body +=
            "<p>Per ognuna scegli: <b>Giusta</b>, <b>Giusta ma poco importante</b> oppure <b>Sbagliata o inventata</b>.</p>"
        for entry in entries {
            let point = entry.point
            body += "<div class=card><div class=kind>\(point.kind == .decision ? "Decisione" : "Attività")"
            body += " · \(TranscriptRenderer.clock(point.atSec))</div><div class=text>\(escape(point.text))"
            if let owner = point.owner { body += " <span class=owner>— \(escape(owner))</span>" }
            body += "</div><div class=quote>«\(escape(point.quote))»</div><div class=choices>"
            for (value, label) in [
                ("giusta", "Giusta"), ("minore", "Giusta ma poco importante"), ("sbagliata", "Sbagliata o inventata"),
            ] {
                body += "<label><input type=radio name=\(entry.id) value=\(value)> \(label)</label>"
            }
            body += "</div></div>"
        }
        body +=
            "<h3>Cosa manca?</h3><p>Decisioni o attività importanti della call che nessuno ha trovato, una per riga.</p>"
        body += "<textarea id=missing rows=6></textarea>"
        body +=
            "<h2>2. Riordina testo</h2><p>Per ogni passaggio scegli la versione migliore e segna quelle che hanno cambiato o perso qualcosa.</p>"
        for (index, passage) in passages.enumerated() {
            body +=
                "<h3>Passaggio \(index + 1)</h3><div class=original><b>Originale</b><p>\(escape(passage))</p></div><div class=versions>"
            for (position, modelID) in letters[index].enumerated() {
                let letter = String(UnicodeScalar(65 + position)!)
                guard let run = runs.first(where: { $0.model.id == modelID }), index < run.tidies.count else {
                    continue
                }
                let tidy = run.tidies[index]
                body +=
                    "<div class=version><b>\(letter)</b><p>\(escape(tidy.text).replacingOccurrences(of: "\n", with: "<br>"))</p>"
                if !tidy.missing.isEmpty {
                    body += "<p class=warn>IAGO: mancano \(escape(tidy.missing.joined(separator: ", ")))</p>"
                }
                body += "<label><input type=radio name=best\(index) value=\(letter)> La migliore</label>"
                body +=
                    "<label><input type=checkbox name=flag\(index) value=\(letter)> Ha cambiato o perso qualcosa</label></div>"
            }
            body += "</div>"
        }
        body += "<h3>Note</h3><textarea id=notes rows=4></textarea>"
        body += "<p><button onclick=save()>Salva risultati</button> <span id=saved></span></p>"
        let ids = entries.map { "\"\($0.id)\"" }.joined(separator: ",")
        let script = """
            function save(){
              const r={proposte:{},manca:document.getElementById('missing').value,note:document.getElementById('notes').value,riordino:[]};
              for(const id of [\(ids)]){const c=document.querySelector('input[name='+id+']:checked');r.proposte[id]=c?c.value:null;}
              for(let i=0;i<\(passages.count);i++){const b=document.querySelector('input[name=best'+i+']:checked');
                r.riordino.push({migliore:b?b.value:null,segnalate:[...document.querySelectorAll('input[name=flag'+i+']:checked')].map(x=>x.value)});}
              const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([JSON.stringify(r,null,2)],{type:'application/json'}));
              a.download='iago-prova-risultati.json';a.click();document.getElementById('saved').textContent='Salvato in Download.';
            }
            """
        let style = """
            body{font:15px -apple-system,sans-serif;max-width:900px;margin:24px auto;padding:0 16px;color:#222;background:#fff}
            @media(prefers-color-scheme:dark){body{color:#eee;background:#1e1e1e}.card,.version,.original{background:#2a2a2a!important}}
            .sub{color:#888}.card,.version,.original{background:#f4f4f4;border-radius:8px;padding:10px 12px;margin:10px 0}
            .kind{font-size:12px;color:#888;text-transform:uppercase}.text{font-weight:600;margin:4px 0}.owner{font-weight:400;color:#888}
            .quote{font-style:italic;color:#777;margin-bottom:6px}.choices label,.version label{display:block;margin:2px 0}
            .versions{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:10px}.warn{color:#c60}
            textarea{width:100%;font:inherit}button{font:inherit;padding:6px 14px}
            """
        let html =
            "<!doctype html><html lang=it><meta charset=utf-8><title>Prova dei motori</title><style>\(style)</style><body>\(body)<script>\(script)</script></body></html>"
        var key: [String: Any] = ["proposte": Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0.models) })]
        key["riordino"] = letters.map { order in
            Dictionary(
                uniqueKeysWithValues: order.enumerated().map { (String(UnicodeScalar(65 + $0.offset)!), $0.element) })
        }
        key["modelli"] = runs.map(\.model.id)
        let data = (try? JSONSerialization.data(withJSONObject: key, options: [.prettyPrinted, .sortedKeys])) ?? Data()
        return (html, String(decoding: data, as: UTF8.self))
    }

    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
}
