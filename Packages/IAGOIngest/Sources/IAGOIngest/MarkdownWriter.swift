import AppKit
import Foundation

/// Converts rich text (DOCX, RTF, HTML read by `NSAttributedString`) to Markdown: headings from font
/// size, list items, bold, italics and links (spec 7.6).
enum MarkdownWriter {
    static func markdown(from text: NSAttributedString) -> String {
        let string = text.string as NSString
        let bodySize = mostCommonFontSize(text)
        var blocks: [String] = []
        var location = 0
        while location < string.length {
            let range = string.paragraphRange(for: NSRange(location: location, length: 0))
            location = NSMaxRange(range)
            var content = NSRange(location: range.location, length: range.length)
            while content.length > 0, let scalar = Unicode.Scalar(string.character(at: NSMaxRange(content) - 1)),
                CharacterSet.newlines.contains(scalar)
            {
                content.length -= 1
            }
            let plain = string.substring(with: content).trimmingCharacters(in: .whitespaces)
            guard !plain.isEmpty else { continue }
            let attributes = text.attributes(at: content.location, effectiveRange: nil)
            let font = attributes[.font] as? NSFont
            let size = font?.pointSize ?? bodySize
            let bold = font.map { NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } ?? false
            let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle

            if size >= bodySize * 1.6 {
                blocks.append("# \(plain)")
            } else if size >= bodySize * 1.3 {
                blocks.append("## \(plain)")
            } else if size >= bodySize * 1.1, bold || plain.count < 80 {
                blocks.append("### \(plain)")
            } else if let marker = plain.firstMatch(of: /^[•◦▪‣\-–]\s+/) {
                // List markers that survived as text (e.g. DOCX read back without NSTextList).
                blocks.append("- \(inline(text, content).replacingOccurrences(of: String(marker.0), with: ""))")
            } else if let number = plain.firstMatch(of: /^(\d+)[.)]\s+/) {
                blocks.append(
                    "\(number.1). \(inline(text, content).replacingOccurrences(of: String(number.0), with: ""))")
            } else if let list = paragraph?.textLists.last {
                let marker = list.markerFormat.rawValue.contains("decimal") ? "1." : "-"
                let indent = String(repeating: "  ", count: max(0, (paragraph?.textLists.count ?? 1) - 1))
                blocks.append(
                    "\(indent)\(marker) \(inline(text, content).replacingOccurrences(of: #"^\s*[•◦▪\-–\d.\t ]+"#, with: "", options: .regularExpression))"
                )
            } else {
                blocks.append(inline(text, content))
            }
        }
        // List items stay together; other blocks are separated by a blank line.
        var output = ""
        for (index, block) in blocks.enumerated() {
            if index > 0 {
                let isItem = { (s: String) in
                    s.trimmingCharacters(in: .whitespaces).firstMatch(of: #/^(-|\d+\.) /#) != nil
                }
                output += isItem(block) && isItem(blocks[index - 1]) ? "\n" : "\n\n"
            }
            output += block
        }
        return output
    }

    /// Inline styles of a paragraph.
    static func inline(_ text: NSAttributedString, _ range: NSRange) -> String {
        var result = ""
        text.enumerateAttributes(in: range) { attributes, run, _ in
            var piece = (text.string as NSString).substring(with: run)
            let core = piece.trimmingCharacters(in: .whitespaces)
            guard !core.isEmpty else {
                result += piece
                return
            }
            let font = attributes[.font] as? NSFont
            let traits = font.map { NSFontManager.shared.traits(of: $0) } ?? []
            var styled = core
            if traits.contains(.italicFontMask) { styled = "*\(styled)*" }
            if traits.contains(.boldFontMask) { styled = "**\(styled)**" }
            if let link = attributes[.link] {
                let url = (link as? URL)?.absoluteString ?? (link as? String) ?? ""
                if !url.isEmpty { styled = "[\(styled)](\(url))" }
            }
            piece = piece.replacingOccurrences(of: core, with: styled)
            result += piece
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    static func mostCommonFontSize(_ text: NSAttributedString) -> CGFloat {
        var counts: [CGFloat: Int] = [:]
        text.enumerateAttribute(.font, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            if let font = value as? NSFont { counts[font.pointSize, default: 0] += range.length }
        }
        return counts.max { $0.value < $1.value }?.key ?? 12
    }
}
