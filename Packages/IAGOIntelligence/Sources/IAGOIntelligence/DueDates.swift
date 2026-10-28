import Foundation

/// Italian deadlines as said in a call or an email ("venerdì", "domani", "entro il 10 novembre", "fine mese"),
/// turned into a day relative to the item's date (ADR-0074). Small models are bad at date arithmetic, so the model
/// only copies the words and IAGO does the counting; an expression IAGO cannot read gives no date rather than a guess.
public enum DueDates {
    /// The day `expression` means, said on `reference`, as "yyyy-MM-dd"; nil if it is not a clear deadline.
    public static func resolve(_ expression: String, from reference: Date, calendar: Calendar = .current) -> String? {
        resolveDate(expression, from: reference, calendar: calendar).map { format($0, calendar: calendar) }
    }

    static func resolveDate(_ expression: String, from reference: Date, calendar: Calendar) -> Date? {
        let text = expression.folding(
            options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it"))
        let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let day = calendar.startOfDay(for: reference)
        func plus(_ days: Int) -> Date? { calendar.date(byAdding: .day, value: days, to: day) }

        if let date = explicitDate(text, words, day: day, calendar: calendar) { return date }
        if words.contains("dopodomani") { return plus(2) }
        if words.contains("domani") { return plus(1) }
        if words.contains("oggi") || words.contains("stasera") || text.contains("in giornata") { return plus(0) }
        if let index = words.firstIndex(where: { $0 == "tra" || $0 == "fra" }), index + 2 < words.count,
            let count = number(words[index + 1])
        {
            if words[index + 2].hasPrefix("giorn") { return plus(count) }
            if words[index + 2].hasPrefix("settiman") { return plus(7 * count) }
        }
        let nextWeek =
            text.contains("prossima settimana") || text.contains("settimana prossima")
            || text.contains("settimana che viene")
        if let weekday = weekdays.firstIndex(where: { words.contains($0) }) {
            let today = calendar.component(.weekday, from: day)  // 1 Sunday, 2 Monday…
            let sinceMonday = (today + 5) % 7
            if nextWeek {
                // "venerdì della prossima settimana": that day of next week.
                return plus(7 - sinceMonday + weekday)
            }
            // The next one after the day it was said: "venerdì" said on a Friday is the Friday after.
            var ahead = (weekday - sinceMonday + 7) % 7
            if ahead == 0 { ahead = 7 }
            return plus(ahead)
        }
        if nextWeek { return friday(of: plus(7)!, calendar: calendar) }
        if text.contains("fine settimana") || words.contains("weekend") {
            let friday = friday(of: day, calendar: calendar)
            return friday < day ? plus(7).map { self.friday(of: $0, calendar: calendar) } : friday
        }
        if text.contains("fine anno") || text.contains("fine dell anno") {
            return calendar.date(from: DateComponents(year: calendar.component(.year, from: day), month: 12, day: 31))
        }
        if text.contains("fine mese") || text.contains("fine del mese") {
            return lastDay(ofMonthOf: day, calendar: calendar)
        }
        if let index = words.firstIndex(of: "fine"), index + 1 < words.count,
            let month = months.firstIndex(of: words[index + 1])
        {
            var year = calendar.component(.year, from: day)
            if month + 1 < calendar.component(.month, from: day) { year += 1 }
            guard let first = calendar.date(from: DateComponents(year: year, month: month + 1, day: 1)) else {
                return nil
            }
            return lastDay(ofMonthOf: first, calendar: calendar)
        }
        return nil
    }

    static let weekdays = ["lunedi", "martedi", "mercoledi", "giovedi", "venerdi", "sabato", "domenica"]
    static let months = [
        "gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto", "settembre", "ottobre",
        "novembre", "dicembre",
    ]
    static let numbers = [
        "un": 1, "uno": 1, "una": 1, "due": 2, "tre": 3, "quattro": 4, "cinque": 5, "sei": 6, "sette": 7, "otto": 8,
        "nove": 9, "dieci": 10, "quindici": 15,
    ]

    static func number(_ word: String) -> Int? { Int(word).flatMap { $0 > 0 && $0 < 400 ? $0 : nil } ?? numbers[word] }

    /// "2026-11-06", "6/11", "06/11/2026", "6 novembre", "il 6 novembre 2026". Without a year, the first such day
    /// from the reference on. Not "6.11": it reads like a time or an amount.
    static func explicitDate(_ text: String, _ words: [String], day: Date, calendar: Calendar) -> Date? {
        var components: DateComponents?
        if let match = text.firstMatch(of: /(\d{4})-(\d{1,2})-(\d{1,2})/) {
            components = DateComponents(year: Int(match.1), month: Int(match.2), day: Int(match.3))
        } else if let match = text.firstMatch(of: /(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?/) {
            var year = match.3.flatMap { Int($0) }
            if let short = year, short < 100 { year = 2000 + short }
            components = DateComponents(year: year, month: Int(match.2), day: Int(match.1))
        } else {
            for (index, word) in words.enumerated() {
                guard let month = months.firstIndex(of: word), index > 0, let dayNumber = Int(words[index - 1])
                else { continue }
                let year = words.dropFirst(index + 1).first.flatMap { Int($0) }.flatMap { $0 > 1_900 ? $0 : nil }
                components = DateComponents(year: year, month: month + 1, day: dayNumber)
                break
            }
        }
        guard var wanted = components, let month = wanted.month, let dayNumber = wanted.day, (1...12).contains(month),
            (1...31).contains(dayNumber)
        else { return nil }
        let explicitYear = wanted.year != nil
        if !explicitYear { wanted.year = calendar.component(.year, from: day) }
        guard var date = calendar.date(from: wanted), calendar.component(.day, from: date) == dayNumber else {
            return nil
        }
        if !explicitYear, date < day { date = calendar.date(byAdding: .year, value: 1, to: date) ?? date }
        return date
    }

    static func friday(of date: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: date)  // 1 Sunday … 7 Saturday
        let offset = weekday == 1 ? -2 : 6 - weekday
        return calendar.date(byAdding: .day, value: offset, to: date) ?? date
    }

    static func lastDay(ofMonthOf date: Date, calendar: Calendar) -> Date? {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return nil }
        return calendar.date(byAdding: .day, value: -1, to: interval.end)
    }

    static func format(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
