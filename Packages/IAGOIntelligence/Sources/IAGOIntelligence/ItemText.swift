import Foundation
import IAGOCore
import IAGOStore

extension SuggestionEngine.Input {
    /// The label of the lines that come from a screenshot of the call (ADR-0072).
    public static let screenshotSpeaker = "Schermata"

    /// The text of an item as the engine and Claude read it: a call by turns of speech with names and minutes, plus
    /// the text read on its screenshots at their minute; an email or a document by paragraphs. nil without a text.
    public static func load(_ item: Item, from archive: Archive) throws -> Self? {
        switch item.type {
        case .call:
            guard let asset = try archive.assets(itemID: item.id).first(where: { $0.kind == .transcriptJSON }) else {
                return nil
            }
            let transcript = try Transcript.decode(from: archive.readAssetData(asset))
            let names = Dictionary(uniqueKeysWithValues: transcript.speakers.map { ($0.id, $0.label) })
                .merging(try archive.speakers(itemID: item.id).map { ($0.speakerId, $0.label) }) { $1 }
            var lines = transcript.segments.map {
                KeyPointExtractor.Line(atSec: $0.start, speaker: names[$0.speaker] ?? $0.speaker, text: $0.text)
            }
            lines += try archive.screenshots(itemID: item.id).compactMap { shot in
                guard let text = shot.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty,
                    let at = shot.atSec
                else { return nil }
                return KeyPointExtractor.Line(
                    atSec: at, speaker: screenshotSpeaker, text: text.replacingOccurrences(of: "\n", with: " · "))
            }
            lines.sort { $0.atSec < $1.atSec }
            return .init(
                itemID: item.id, projectID: item.projectId, lines: lines, isCall: true, speakers: names,
                date: item.occurredAt)
        case .email, .document:
            guard let asset = try archive.assets(itemID: item.id).first(where: { $0.kind == .contentMD }) else {
                return nil
            }
            let text = String(decoding: try archive.readAssetData(asset), as: UTF8.self)
            let lines = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { KeyPointExtractor.Line(atSec: 0, speaker: "", text: $0) }
            return .init(
                itemID: item.id, projectID: item.projectId, lines: lines, isCall: false, date: item.occurredAt)
        }
    }
}
