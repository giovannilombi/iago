import Foundation

/// Finds existing projects whose name looks like a new one, to avoid duplicates such as "Ospedalia",
/// "Ospdalia" and "Ospedalia-Nord". The user can still create the project, but only explicitly.
public enum ProjectNameMatcher {
    /// Normalized words: lowercase, no accents, separators (`-`, `_`, `.`, `/`) as spaces.
    static func words(_ name: String) -> [String] {
        TagNormalizer.normalize(name)
            .map { $0.isLetter || $0.isNumber ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
            .split(separator: " ").map(String.init)
    }

    public static func isSimilar(_ a: String, _ b: String) -> Bool {
        let wa = words(a)
        let wb = words(b)
        guard !wa.isEmpty, !wb.isEmpty else { return false }
        let ja = wa.joined()
        let jb = wb.joined()
        if ja == jb { return true }
        // Typos: small edit distance relative to the length.
        let distance = TagNormalizer.editDistance(ja, jb)
        if distance <= max(1, min(ja.count, jb.count) / 4) { return true }
        // One name extends the other ("ospedalia" / "ospedalia nord").
        if wa.allSatisfy({ wb.contains($0) }) || wb.allSatisfy({ wa.contains($0) }) { return true }
        // A shared significant word, allowing a typo in it ("ospdalia" / "ospedalia nord").
        for x in wa where x.count >= 4 {
            for y in wb where y.count >= 4 && TagNormalizer.editDistance(x, y) <= max(1, min(x.count, y.count) / 4) {
                return true
            }
        }
        return false
    }

    public static func similar(to name: String, among projects: [Project]) -> [Project] {
        projects.filter { isSimilar(name, $0.name) }
    }
}
