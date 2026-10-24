import Testing

@testable import IAGOExport

@Suite struct SummaryExportTests {
    @Test func summariesLoseTheAppLinksAndGoOneLevelDown() {
        let markdown =
            "## Decisioni\n\n- Logo blu [01:05](iago://seek/65)\n\n| Chi | Minuto |\n| --- | --- |\n| Mario | [12:00](iago://seek/720) |"
        let plain = ItemDocument.plainSummary(markdown, headingLevel: 4)
        #expect(plain.contains("#### Decisioni"))
        #expect(plain.contains("- Logo blu [01:05]"))
        #expect(plain.contains("| Mario | [12:00] |"))
        #expect(!plain.contains("iago://"))
    }
}
