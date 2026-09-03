//
//  FieldItemParserTests.swift
//  SiteVantageTests
//

import XCTest
@testable import SiteVantage

final class FieldItemParserTests: XCTestCase {
    func testEmptyTranscriptProducesNoSuggestions() {
        let result = FieldItemParser.parse("")
        XCTAssertTrue(result.laborItems.isEmpty)
        XCTAssertTrue(result.equipmentItems.isEmpty)
    }

    func testTextWithNoRecognizedPatternsProducesNoSuggestions() {
        let result = FieldItemParser.parse("The GC asked us to hold off until tomorrow.")
        XCTAssertTrue(result.laborItems.isEmpty)
        XCTAssertTrue(result.equipmentItems.isEmpty)
    }

    func testParsesHeadcountAndNearbyHoursForATradeWord() throws {
        let result = FieldItemParser.parse("We had 2 electricians for 6 hours running conduit on level 3.")

        XCTAssertEqual(result.laborItems.count, 1)
        let item = try XCTUnwrap(result.laborItems.first)
        XCTAssertEqual(item.description, "Electrician")
        XCTAssertEqual(item.headcount, 2)
        XCTAssertEqual(item.hours, 6)
    }

    func testAppliesGlobalHoursFallbackWhenExactlyOneLaborItemHasNoNearbyHours() throws {
        let transcript = "1 electrician showed up to review the punch list items with the site super before wrapping up and logging 5 hours on the ticket for the day."

        let result = FieldItemParser.parse(transcript)

        XCTAssertEqual(result.laborItems.count, 1)
        let item = try XCTUnwrap(result.laborItems.first)
        XCTAssertEqual(item.headcount, 1)
        XCTAssertEqual(item.hours, 5, "a bare 'N hours' mention anywhere in the transcript should still apply when there's exactly one labor item and no nearby hours were found")
    }

    func testParsesEquipmentMentionWithNearbyHours() throws {
        let result = FieldItemParser.parse("Used a scissor lift for 3 hours to access the ceiling grid.")

        XCTAssertEqual(result.equipmentItems.count, 1)
        let item = try XCTUnwrap(result.equipmentItems.first)
        XCTAssertEqual(item.description, "Scissor Lift")
        XCTAssertEqual(item.hoursOperated, 3)
    }

    func testLongerEquipmentPhraseDoesNotAlsoProduceARedundantSubstringMatch() {
        // "mini excavator" contains "excavator" as a substring; the parser
        // must not emit both a "Mini Excavator" and a bare "Excavator"
        // suggestion for the same mention.
        let result = FieldItemParser.parse("Brought in a mini excavator to dig the trench along the north wall.")

        XCTAssertEqual(result.equipmentItems.count, 1)
        XCTAssertEqual(result.equipmentItems.first?.description, "Mini Excavator")
    }

    func testParsesMultipleDistinctLaborMentions() {
        let result = FieldItemParser.parse("3 carpenters and 2 laborers were on site all day.")

        XCTAssertEqual(result.laborItems.count, 2)
        XCTAssertTrue(result.laborItems.contains { $0.description == "Carpenter" && $0.headcount == 3 })
        XCTAssertTrue(result.laborItems.contains { $0.description == "Laborer" && $0.headcount == 2 })
    }
}
