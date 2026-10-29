import Testing

@testable import IAGOIntelligence

/// ADR-0077: the English library mirrors the Italian one, so a category keeps its template in both languages.
@Suite struct EnglishTemplatesTests {
    @Test func sameTemplatesSectionsAndColumns() {
        let italian = SummaryLibrary.italianLibrary
        let english = SummaryLibrary.englishLibrary
        #expect(italian.map(\.id) == english.map(\.id))
        for (it, en) in zip(italian, english) {
            #expect(it.sections.count == en.sections.count, "\(it.id)")
            #expect(it.sections.map(\.format) == en.sections.map(\.format), "\(it.id)")
            #expect(it.sections.map(\.columns.count) == en.sections.map(\.columns.count), "\(it.id)")
            #expect(Set(en.sections.map(\.title)).count == en.sections.count, "\(it.id): titles must be distinct")
        }
    }

    @Test func statusReportHeadingsInBothLanguages() {
        #expect(StatusReport.headings(.en).count == StatusReport.headings(.it).count)
    }
}
