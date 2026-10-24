import CoreFoundation
import Foundation

/// An address in an email header: `"Mario Rossi" <mario@example.com>`.
public struct EmailAddress: Codable, Sendable, Hashable {
    public var name: String?
    public var address: String

    public init(name: String?, address: String) {
        self.name = name
        self.address = address
    }

    /// Name if known, otherwise the address.
    public var display: String { name.flatMap { $0.isEmpty ? nil : $0 } ?? address }
}

public struct EmailAttachment: Sendable, Equatable {
    public var filename: String
    public var mimeType: String
    public var data: Data
    /// Inline parts (logos and signatures in the HTML) are usually not worth importing (FR-184).
    public var isInline: Bool
}

/// A parsed email (FR-180.2): headers, body as Markdown, attachments.
public struct EmailMessage: Sendable, Equatable {
    public var from: EmailAddress?
    public var to: [EmailAddress] = []
    public var cc: [EmailAddress] = []
    public var subject: String?
    public var date: Date?
    public var messageID: String?
    public var inReplyTo: String?
    public var references: [String] = []
    public var bodyMarkdown = ""
    public var attachments: [EmailAttachment] = []
    /// ADR-0050: an invitation or a reply to a meeting (a `text/calendar` part or an `.ics` file).
    public var isCalendar = false
    /// An automatic reply (`Auto-Submitted`, `X-Autoreply`).
    public var isAutoReply = false
    /// A newsletter or mailing list (`List-Unsubscribe`, `Precedence: bulk/list`).
    public var isBulk = false

    public init() {}
}

public enum EmailParserError: Error, Sendable {
    case notAnEmail
}

/// Local MIME parser limited to what emails need (RFC 5322, 2045–2047, 2231; ADR-0040): headers with
/// encoded words, multipart, base64 and quoted-printable, charsets, attachments. HTML bodies are converted
/// to Markdown by a small converter that never loads anything: no remote images, no tracking pixels.
public enum EmailParser {
    public static func parse(_ data: Data) throws -> EmailMessage {
        let part = MIMEPart(data)
        guard part.header("from") != nil || part.header("subject") != nil || part.header("message-id") != nil else {
            throw EmailParserError.notAnEmail
        }
        var message = EmailMessage()
        message.from = part.header("from").flatMap { addresses(decodeWords($0)).first }
        message.to = part.header("to").map { addresses(decodeWords($0)) } ?? []
        message.cc = part.header("cc").map { addresses(decodeWords($0)) } ?? []
        message.subject = part.header("subject").map { decodeWords($0).trimmingCharacters(in: .whitespaces) }
        message.date = part.header("date").flatMap(date)
        message.messageID = part.header("message-id").flatMap { messageIDs($0).first }
        message.inReplyTo = part.header("in-reply-to").flatMap { messageIDs($0).first }
        message.references = part.header("references").map(messageIDs) ?? []
        let autoSubmitted = part.header("auto-submitted")?.lowercased()
        message.isAutoReply =
            (autoSubmitted != nil && autoSubmitted != "no") || part.header("x-autoreply") != nil
            || part.header("x-autorespond") != nil
        let precedence = part.header("precedence")?.lowercased() ?? ""
        message.isBulk = part.header("list-unsubscribe") != nil || ["bulk", "list", "junk"].contains(precedence)

        var plain: String?
        var html: String?
        collect(part, plain: &plain, html: &html, attachments: &message.attachments)
        if let plain, !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Outlook's plain text writes mentions and mail links as "Name<mailto:address>": the name is enough.
            let plain = normalizeNewlines(plain).replacingOccurrences(
                of: "<mailto:[^>\\s]+>", with: "", options: .regularExpression)
            message.bodyMarkdown = Bullets.join(plain).trimmingCharacters(
                in: .whitespacesAndNewlines)
        } else if let html {
            message.bodyMarkdown = HTMLToMarkdown.convert(html)
        }
        message.isCalendar = message.attachments.contains {
            $0.mimeType == "text/calendar" || $0.filename.lowercased().hasSuffix(".ics")
        }
        return message
    }

    /// Walks the MIME tree: the first text/plain and text/html bodies, every other leaf as an attachment.
    static func collect(
        _ part: MIMEPart, plain: inout String?, html: inout String?, attachments: inout [EmailAttachment]
    ) {
        if part.mediaType.hasPrefix("multipart/") {
            for child in part.children() { collect(child, plain: &plain, html: &html, attachments: &attachments) }
            return
        }
        if part.mediaType == "message/rfc822", part.disposition != "attachment" {
            // A forwarded message inline: its body is part of the text.
            let inner = MIMEPart(part.decodedBody)
            collect(inner, plain: &plain, html: &html, attachments: &attachments)
            return
        }
        let filename = part.filename
        if filename == nil, part.disposition != "attachment" {
            if part.mediaType == "text/plain", plain == nil {
                plain = part.text
                return
            }
            if part.mediaType == "text/html", html == nil {
                html = part.text
                return
            }
        }
        guard !part.decodedBody.isEmpty else { return }
        let name =
            filename
            ?? (part.mediaType == "message/rfc822"
                ? "messaggio.eml" : "allegato.\(part.mediaType.split(separator: "/").last ?? "bin")")
        attachments.append(
            EmailAttachment(
                filename: name, mimeType: part.mediaType, data: part.decodedBody,
                isInline: part.disposition == "inline" || part.header("content-id") != nil))
    }

    // MARK: Headers

    /// RFC 2047 encoded words (`=?utf-8?Q?Caf=C3=A9?=`); whitespace between two encoded words is dropped.
    public static func decodeWords(_ value: String) -> String {
        let pattern = #"=\?([^?]+)\?([BbQq])\?([^?]*)\?="#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        let collapsed = value.replacingOccurrences(
            of: #"(\?=)\s+(=\?)"#, with: "$1$2", options: .regularExpression)
        var result = ""
        var cursor = collapsed.startIndex
        for match in regex.matches(in: collapsed, range: NSRange(collapsed.startIndex..., in: collapsed)) {
            guard let range = Range(match.range, in: collapsed),
                let charsetRange = Range(match.range(at: 1), in: collapsed),
                let modeRange = Range(match.range(at: 2), in: collapsed),
                let textRange = Range(match.range(at: 3), in: collapsed)
            else { continue }
            result += collapsed[cursor..<range.lowerBound]
            let charset = String(collapsed[charsetRange]).split(separator: "*").first.map(String.init) ?? "utf-8"
            let text = String(collapsed[textRange])
            let bytes: Data? =
                collapsed[modeRange].lowercased() == "b"
                ? Data(base64Encoded: padBase64(text))
                : quotedPrintable(Data(text.replacingOccurrences(of: "_", with: " ").utf8), header: true)
            result += bytes.map { decodeText($0, charset: charset) } ?? String(collapsed[range])
            cursor = range.upperBound
        }
        result += collapsed[cursor...]
        return result
    }

    /// `"Rossi, Mario" <m@x.it>, info@y.it` → two addresses (commas inside quotes or brackets are kept).
    public static func addresses(_ value: String) -> [EmailAddress] {
        var parts: [String] = []
        var current = ""
        var inQuotes = false
        var depth = 0
        for character in value {
            switch character {
            case "\"": inQuotes.toggle()
            case "<": depth += 1
            case ">": depth = max(0, depth - 1)
            case ",", ";":
                if !inQuotes, depth == 0 {
                    parts.append(current)
                    current = ""
                    continue
                }
            default: break
            }
            current.append(character)
        }
        parts.append(current)
        return parts.compactMap { raw in
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            if let open = text.lastIndex(of: "<"), let close = text.lastIndex(of: ">"), open < close {
                let address = text[text.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
                let name = text[..<open].trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'")).trimmingCharacters(in: .whitespaces)
                guard address.contains("@") else { return nil }
                return EmailAddress(name: name.isEmpty ? nil : name, address: address.lowercased())
            }
            let address = text.trimmingCharacters(in: CharacterSet(charactersIn: "<>\" "))
            return address.contains("@") ? EmailAddress(name: nil, address: address.lowercased()) : nil
        }
    }

    static func messageIDs(_ value: String) -> [String] {
        let ids = value.components(separatedBy: "<").dropFirst().compactMap { piece -> String? in
            guard let end = piece.firstIndex(of: ">") else { return nil }
            let id = piece[..<end].trimmingCharacters(in: .whitespaces)
            return id.isEmpty ? nil : id
        }
        if ids.isEmpty {
            let bare = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return bare.isEmpty ? [] : [bare]
        }
        return ids
    }

    /// RFC 5322 dates, with or without the weekday, with or without seconds.
    public static func date(_ value: String) -> Date? {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let comment = text.range(of: " (") { text = String(text[..<comment.lowerBound]) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in [
            "EEE, d MMM yyyy HH:mm:ss Z", "d MMM yyyy HH:mm:ss Z", "EEE, d MMM yyyy HH:mm Z", "d MMM yyyy HH:mm Z",
            "EEE, d MMM yyyy HH:mm:ss zzz", "d MMM yyyy HH:mm:ss zzz",
        ] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    // MARK: Decoding

    static func decodeText(_ data: Data, charset: String?) -> String {
        let name = (charset ?? "utf-8").trimmingCharacters(in: CharacterSet(charactersIn: "\" ")).lowercased()
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
        if cfEncoding != kCFStringEncodingInvalidId {
            let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
            if let text = String(data: data, encoding: encoding) { return text }
        }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252)
            ?? String(decoding: data, as: UTF8.self)
    }

    static func quotedPrintable(_ data: Data, header: Bool = false) -> Data {
        var output = Data()
        let bytes = [UInt8](data)
        var index = 0
        func hex(_ byte: UInt8) -> UInt8? {
            switch byte {
            case 48...57: byte - 48
            case 65...70: byte - 55
            case 97...102: byte - 87
            default: nil
            }
        }
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 61 {  // "="
                if index + 2 < bytes.count, let high = hex(bytes[index + 1]), let low = hex(bytes[index + 2]) {
                    output.append(high << 4 | low)
                    index += 3
                    continue
                }
                // Soft line break: "=\r\n" or "=\n".
                if index + 1 < bytes.count, bytes[index + 1] == 13 || bytes[index + 1] == 10 {
                    index += bytes[index + 1] == 13 && index + 2 < bytes.count && bytes[index + 2] == 10 ? 3 : 2
                    continue
                }
            }
            output.append(byte)
            index += 1
        }
        _ = header
        return output
    }

    static func padBase64(_ text: String) -> String {
        let clean = text.filter { !$0.isWhitespace }
        let remainder = clean.count % 4
        return remainder == 0 ? clean : clean + String(repeating: "=", count: 4 - remainder)
    }

    static func normalizeNewlines(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    // MARK: Screenshots (FR-180.3)

    /// Header lines read by OCR from a screenshot of an email (Italian and English labels), as suggestions.
    public struct GuessedHeaders: Sendable, Equatable {
        public var from: String?
        public var to: String?
        public var cc: String?
        public var subject: String?
        public var date: String?
    }

    public static func guessHeaders(fromOCR text: String) -> GuessedHeaders {
        var result = GuessedHeaders()
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let colon = trimmed.firstIndex(of: ":") else { continue }
            let label = trimmed[..<colon].lowercased().trimmingCharacters(in: .whitespaces)
            let value = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { continue }
            switch label {
            case "da", "from", "mittente": result.from = result.from ?? value
            case "a", "to", "destinatari", "destinatario": result.to = result.to ?? value
            case "cc": result.cc = result.cc ?? value
            case "oggetto", "subject": result.subject = result.subject ?? value
            case "data", "date", "inviato", "sent", "inviato il": result.date = result.date ?? value
            default: continue
            }
        }
        return result
    }
}

/// One MIME entity: headers and body, with its children if multipart.
struct MIMEPart {
    let headers: [(name: String, value: String)]
    let body: Data

    init(_ data: Data) {
        let bytes = [UInt8](data)
        // Headers end at the first empty line (CRLF CRLF or LF LF).
        var split = bytes.count
        var bodyStart = bytes.count
        var index = 0
        while index < bytes.count {
            if bytes[index] == 10 {
                if index + 1 < bytes.count, bytes[index + 1] == 10 {
                    split = index
                    bodyStart = index + 2
                    break
                }
                if index + 2 < bytes.count, bytes[index + 1] == 13, bytes[index + 2] == 10 {
                    split = index
                    bodyStart = index + 3
                    break
                }
            }
            index += 1
        }
        let headerText = String(decoding: bytes[0..<min(split, bytes.count)], as: UTF8.self)
        var headers: [(String, String)] = []
        for line in EmailParser.normalizeNewlines(headerText).components(separatedBy: "\n") {
            if let first = line.first, first == " " || first == "\t", !headers.isEmpty {
                // Folded header: continuation of the previous one.
                headers[headers.count - 1].1 += " " + line.trimmingCharacters(in: .whitespaces)
            } else if let colon = line.firstIndex(of: ":") {
                headers.append(
                    (
                        String(line[..<colon]).lowercased().trimmingCharacters(in: .whitespaces),
                        String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                    ))
            }
        }
        self.headers = headers
        self.body = bodyStart < bytes.count ? Data(bytes[bodyStart...]) : Data()
    }

    func header(_ name: String) -> String? { headers.first { $0.name == name }?.value }

    /// `text/plain; charset="utf-8"` → type and parameters (RFC 2231 `name*=utf-8''…` included).
    static func parse(_ value: String) -> (value: String, parameters: [String: String]) {
        var pieces: [String] = []
        var current = ""
        var inQuotes = false
        for character in value {
            if character == "\"" { inQuotes.toggle() }
            if character == ";", !inQuotes {
                pieces.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        pieces.append(current)
        var parameters: [String: String] = [:]
        var continuations: [String: [(Int, String)]] = [:]
        for piece in pieces.dropFirst() {
            guard let equal = piece.firstIndex(of: "=") else { continue }
            var key = piece[..<equal].trimmingCharacters(in: .whitespaces).lowercased()
            var raw = piece[piece.index(after: equal)...].trimmingCharacters(in: .whitespaces)
            raw = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            // RFC 2231: name*=charset''percent-encoded, possibly split as name*0*, name*1*…
            let extended = key.hasSuffix("*")
            if extended { key.removeLast() }
            if extended {
                let parts = raw.components(separatedBy: "'")
                if parts.count >= 3 {
                    raw = parts[2...].joined(separator: "'")
                }
                raw = raw.removingPercentEncoding ?? raw
            }
            if let star = key.firstIndex(of: "*"), let order = Int(key[key.index(after: star)...]) {
                continuations[String(key[..<star]), default: []].append((order, raw))
            } else {
                parameters[key] = raw
            }
        }
        for (key, parts) in continuations where parameters[key] == nil {
            parameters[key] = parts.sorted { $0.0 < $1.0 }.map(\.1).joined()
        }
        return (pieces[0].trimmingCharacters(in: .whitespaces).lowercased(), parameters)
    }

    var contentType: (value: String, parameters: [String: String]) {
        Self.parse(header("content-type") ?? "text/plain; charset=us-ascii")
    }

    var mediaType: String { contentType.value }

    var disposition: String? {
        header("content-disposition").map { Self.parse($0).value }
    }

    var filename: String? {
        let fromDisposition = header("content-disposition").flatMap { Self.parse($0).parameters["filename"] }
        let name = fromDisposition ?? contentType.parameters["name"]
        return name.map { EmailParser.decodeWords($0) }.flatMap { $0.isEmpty ? nil : $0 }
    }

    var decodedBody: Data {
        switch header("content-transfer-encoding")?.lowercased().trimmingCharacters(in: .whitespaces) {
        case "base64":
            return Data(base64Encoded: EmailParser.padBase64(String(decoding: body, as: UTF8.self))) ?? Data()
        case "quoted-printable":
            return EmailParser.quotedPrintable(body)
        default:
            return body
        }
    }

    var text: String {
        EmailParser.decodeText(decodedBody, charset: contentType.parameters["charset"])
    }

    /// Parts of a multipart body, split at `--boundary` lines.
    func children() -> [MIMEPart] {
        guard let boundary = contentType.parameters["boundary"] else { return [] }
        let text = [UInt8](body)
        let marker = [UInt8](("--" + boundary).utf8)
        var parts: [MIMEPart] = []
        var starts: [Int] = []
        var index = 0
        // Boundary lines start at the beginning of a line.
        while index + marker.count <= text.count {
            if (index == 0 || text[index - 1] == 10), Array(text[index..<index + marker.count]) == marker {
                starts.append(index)
                index += marker.count
            } else {
                index += 1
            }
        }
        for (position, start) in starts.enumerated() {
            var contentStart = start + marker.count
            // The closing boundary is followed by "--".
            if contentStart + 1 < text.count, text[contentStart] == 45, text[contentStart + 1] == 45 { break }
            while contentStart < text.count, text[contentStart] != 10 { contentStart += 1 }
            contentStart += 1
            var end = position + 1 < starts.count ? starts[position + 1] : text.count
            // Drop the line break that belongs to the next boundary.
            if end > contentStart, text[end - 1] == 10 { end -= 1 }
            if end > contentStart, text[end - 1] == 13 { end -= 1 }
            guard contentStart < end else { continue }
            parts.append(MIMEPart(Data(text[contentStart..<end])))
        }
        return parts
    }
}

/// HTML body → Markdown without a web engine (nothing is ever loaded): headings, paragraphs, line breaks,
/// lists, links, bold and italics, quotes; scripts, styles and images are dropped.
enum HTMLToMarkdown {
    static func convert(_ html: String) -> String {
        var text = html
        for tag in ["script", "style", "head", "title"] {
            text = text.replacingOccurrences(
                of: "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>", with: "", options: [.regularExpression, .caseInsensitive])
        }
        text = text.replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: "", options: .regularExpression)
        let rules: [(String, String)] = [
            ("<br\\s*/?>", "\n"),
            ("<h1[^>]*>", "\n\n# "), ("<h2[^>]*>", "\n\n## "), ("<h3[^>]*>", "\n\n### "),
            ("<h[4-6][^>]*>", "\n\n#### "), ("</h[1-6]>", "\n\n"),
            ("<li[^>]*>", "\n- "), ("</li>", ""), ("</?(ul|ol)[^>]*>", "\n"),
            ("<blockquote[^>]*>", "\n\n> "), ("</blockquote>", "\n\n"),
            ("</?(p|div|table|tr|section|article|header|footer)[^>]*>", "\n\n"),
            ("</t[dh]>", " "),
            ("<(b|strong)(\\s[^>]*)?>", "**"), ("</(b|strong)>", "**"),
            ("<(i|em)(\\s[^>]*)?>", "_"), ("</(i|em)>", "_"),
            ("<a\\s[^>]*href=\"(mailto:)?([^\"]*)\"[^>]*>([\\s\\S]*?)</a>", "[$3]($2)"),
            ("<img[^>]*>", ""),
            ("<[^>]+>", ""),
        ]
        for (pattern, replacement) in rules {
            text = text.replacingOccurrences(
                of: pattern, with: replacement, options: [.regularExpression, .caseInsensitive])
        }
        text = decodeEntities(text)
        // Collapse whitespace: spaces inside lines, at most one empty line between paragraphs.
        let lines = text.components(separatedBy: .newlines).map {
            $0.replacingOccurrences(of: "[ \\t\\u{00A0}]+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }
        var output: [String] = []
        for line in lines {
            if line.isEmpty, output.last?.isEmpty ?? true { continue }
            output.append(line)
        }
        return Bullets.join(output.joined(separator: "\n")).replacingOccurrences(of: "****", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeEntities(_ text: String) -> String {
        let named: [String: String] = [
            "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ", "egrave": "è", "eacute": "é",
            "agrave": "à", "ograve": "ò", "ugrave": "ù", "igrave": "ì", "Egrave": "È", "euro": "€", "laquo": "«",
            "raquo": "»", "rsquo": "’", "lsquo": "‘", "rdquo": "”", "ldquo": "“", "ndash": "–", "mdash": "—",
            "hellip": "…", "copy": "©", "deg": "°",
        ]
        guard let regex = try? NSRegularExpression(pattern: "&(#x?[0-9a-fA-F]+|[a-zA-Z]+);") else { return text }
        var result = ""
        var cursor = text.startIndex
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text), let nameRange = Range(match.range(at: 1), in: text) else {
                continue
            }
            result += text[cursor..<range.lowerBound]
            let name = String(text[nameRange])
            var replacement: String?
            if name.hasPrefix("#x") || name.hasPrefix("#X") {
                replacement = UInt32(name.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String($0) }
            } else if name.hasPrefix("#") {
                replacement = UInt32(name.dropFirst()).flatMap(Unicode.Scalar.init).map { String($0) }
            } else {
                replacement = named[name]
            }
            result += replacement ?? String(text[range])
            cursor = range.upperBound
        }
        result += text[cursor...]
        return result
    }
}

/// Bullets on a line of their own. Outlook's plain-text body writes "  *" and the item's text on the next line,
/// Word-style lists use "·", "o", "§"; an HTML `<li>` that wraps a paragraph ends up the same way. Each marker is
/// joined to its text as a Markdown list item, nested by the marker's indentation.
enum Bullets {
    static let markers: Set<String> = ["*", "-", "•", "·", "o", "▪", "§", "◦", "–", "➢", "Ø"]

    static func join(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let levels = Array(Set(lines.filter { kind(of: $0) != nil }.map(indent))).sorted()
        var output: [String] = []
        var lastItem: Int?
        var index = 0
        while index < lines.count {
            let line = lines[index]
            guard let marker = kind(of: line) else {
                output.append(line)
                index += 1
                continue
            }
            var next = index + 1
            while next < lines.count, lines[next].trimmingCharacters(in: .whitespaces).isEmpty { next += 1 }
            if next < lines.count, kind(of: lines[next]) == nil {
                let level = levels.firstIndex(of: indent(line)) ?? 0
                // Consecutive items stay together (an HTML list of paragraphs leaves empty lines between them).
                if lastItem != nil,
                    output[(lastItem! + 1)...].allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty })
                {
                    output.removeSubrange((lastItem! + 1)...)
                }
                lastItem = output.count
                output.append(
                    String(repeating: "  ", count: level) + marker + " "
                        + lines[next].trimmingCharacters(in: .whitespaces))
                index = next + 1
            } else {
                index += 1  // a marker with nothing after it
            }
        }
        return output.joined(separator: "\n")
    }

    /// "- " for bullets, "3." for numbers; nil for any other line.
    private static func kind(of line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if markers.contains(trimmed) { return "-" }
        if trimmed.range(of: "^[0-9]{1,2}[.)]$", options: .regularExpression) != nil {
            return String(trimmed.dropLast()) + "."
        }
        return nil
    }

    private static func indent(_ line: String) -> Int {
        line.prefix { $0 == " " || $0 == "\t" }.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
    }
}
