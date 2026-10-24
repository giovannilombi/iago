import AppKit
import Foundation
import IAGOCore

/// Reads meeting transcripts exported by Microsoft Teams (and other tools using WebVTT) into a
/// `Transcript` with the real speaker names: precious source material, kept as the item's transcript
/// (ADR-0033).
///
/// Supported shapes:
/// - WebVTT: `00:00:03.120 --> 00:00:05.000` then `<v Mario Rossi>testo</v>`;
/// - DOCX, recent Teams: `Mario Rossi   0:03` (or `1:02:03`) then the text on the next lines;
/// - DOCX, older Teams: `0:0:3.120 --> 0:0:5.0`, then the name, then the text.
public enum TeamsTranscript {
    public static func parse(_ url: URL, itemID: String) throws -> Transcript? {
        let text: String
        switch url.pathExtension.lowercased() {
        case "vtt":
            text = try String(contentsOf: url, encoding: .utf8)
        case "docx", "doc", "rtf", "txt":
            text = try NSAttributedString(url: url, options: [:], documentAttributes: nil).string
        default:
            return nil
        }
        let turns = parseVTT(text) ?? parseSpeakerLines(text)
        guard let turns, turns.count >= 2 else { return nil }
        return transcript(turns, itemID: itemID, source: url.pathExtension.lowercased())
    }

    struct Turn: Equatable {
        var speaker: String
        var start: Double
        var end: Double?
        var text: String
    }

    // MARK: WebVTT (also the older DOCX layout)

    static func parseVTT(_ text: String) -> [Turn]? {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var turns: [Turn] = []
        var index = 0
        while index < lines.count {
            guard let cue = lines[index].firstMatch(of: #/^\s*([\d:.,]+)\s*-->\s*([\d:.,]+)/#),
                let start = seconds(String(cue.1)), let end = seconds(String(cue.2))
            else {
                index += 1
                continue
            }
            index += 1
            var body: [String] = []
            while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).isEmpty,
                lines[index].firstMatch(of: #/-->/#) == nil
            {
                body.append(lines[index].trimmingCharacters(in: .whitespaces))
                index += 1
            }
            guard !body.isEmpty else { continue }
            var speaker = ""
            var content = body.joined(separator: " ")
            if let voice = content.firstMatch(of: #/^<v\s+([^>]+)>(.*?)(</v>)?$/#) {
                speaker = String(voice.1).trimmingCharacters(in: .whitespaces)
                content = String(voice.2)
            } else if body.count > 1 {
                // Older DOCX: name on its own line, then the text.
                speaker = body[0]
                content = body.dropFirst().joined(separator: " ")
            }
            content = content.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            guard !content.isEmpty else { continue }
            turns.append(Turn(speaker: speaker.isEmpty ? "Speaker" : speaker, start: start, end: end, text: content))
        }
        return turns.isEmpty ? nil : turns
    }

    // MARK: Recent DOCX ("Name   0:03" then text)

    static func parseSpeakerLines(_ text: String) -> [Turn]? {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        var turns: [Turn] = []
        var current: Turn?
        for line in lines where !line.isEmpty {
            if let header = line.firstMatch(of: #/^(\D.{1,79}?)\s+((?:\d{1,2}:)?\d{1,2}:\d{2})$/#),
                let start = seconds(String(header.2))
            {
                if let current, !current.text.isEmpty { turns.append(current) }
                current = Turn(speaker: String(header.1).trimmingCharacters(in: .whitespaces), start: start, text: "")
            } else if current != nil {
                current!.text += (current!.text.isEmpty ? "" : " ") + line
            }
        }
        if let current, !current.text.isEmpty { turns.append(current) }
        // Lines like "Mario Rossi started transcription" are not turns.
        return turns.filter { !$0.speaker.isEmpty }.isEmpty ? nil : turns
    }

    /// `1:02:03`, `0:03`, `00:00:03.120`, `0:0:3.12` → seconds.
    static func seconds(_ value: String) -> Double? {
        let parts = value.replacingOccurrences(of: ",", with: ".").split(separator: ":").map { Double($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil }) else { return nil }
        return parts.compactMap { $0 }.reduce(0) { $0 * 60 + $1 }
    }

    static func transcript(_ turns: [Turn], itemID: String, source: String) -> Transcript {
        var ids: [String: String] = [:]
        var speakers: [Transcript.Speaker] = []
        for turn in turns where ids[turn.speaker] == nil {
            let id = "t\(speakers.count + 1)"
            ids[turn.speaker] = id
            speakers.append(.init(id: id, label: turn.speaker, source: .import))
        }
        let segments = turns.enumerated().map { index, turn in
            let next = index + 1 < turns.count ? turns[index + 1].start : turn.start + 5
            return Transcript.Segment(
                id: index + 1, speaker: ids[turn.speaker]!, start: turn.start, end: max(turn.start, turn.end ?? next),
                text: turn.text)
        }
        return Transcript(
            itemId: itemID, engine: .init(asr: "teams", model: source), language: nil, speakers: speakers,
            segments: segments)
    }
}
