//
//  TicketSerialGeneratorTests.swift
//  SiteVantageTests
//

import XCTest
@testable import SiteVantage

@MainActor
final class TicketSerialGeneratorTests: XCTestCase {
    func testFirstSerialForAProjectIsSequenceOne() {
        let context = TestSupport.makeInMemoryContext()
        let project = TestSupport.makeProject(in: context, code: "RVF")

        let serial = TicketSerialGenerator.nextSerial(for: project, year: 2026)

        XCTAssertEqual(serial, "TKT-RVF-2026-0001")
    }

    func testSerialIncrementsPastExistingTickets() {
        let context = TestSupport.makeInMemoryContext()
        let project = TestSupport.makeProject(in: context, code: "RVF")
        _ = TestSupport.makeTicket(in: context, project: project, serial: "TKT-RVF-2026-0001")
        _ = TestSupport.makeTicket(in: context, project: project, serial: "TKT-RVF-2026-0002")

        let serial = TicketSerialGenerator.nextSerial(for: project, year: 2026)

        XCTAssertEqual(serial, "TKT-RVF-2026-0003")
    }

    func testSerialIgnoresGapsAndUsesTheHighestExistingSequence() {
        let context = TestSupport.makeInMemoryContext()
        let project = TestSupport.makeProject(in: context, code: "RVF")
        _ = TestSupport.makeTicket(in: context, project: project, serial: "TKT-RVF-2026-0001")
        _ = TestSupport.makeTicket(in: context, project: project, serial: "TKT-RVF-2026-0007")

        let serial = TicketSerialGenerator.nextSerial(for: project, year: 2026)

        XCTAssertEqual(serial, "TKT-RVF-2026-0008")
    }

    func testSerialSequenceIsIndependentPerYear() {
        let context = TestSupport.makeInMemoryContext()
        let project = TestSupport.makeProject(in: context, code: "RVF")
        _ = TestSupport.makeTicket(in: context, project: project, serial: "TKT-RVF-2025-0042")

        let serial = TicketSerialGenerator.nextSerial(for: project, year: 2026)

        XCTAssertEqual(serial, "TKT-RVF-2026-0001")
    }

    func testSerialIsScopedToItsOwnProjectCode() {
        let context = TestSupport.makeInMemoryContext()
        let projectA = TestSupport.makeProject(in: context, code: "AAA")
        let projectB = TestSupport.makeProject(in: context, code: "BBB")
        _ = TestSupport.makeTicket(in: context, project: projectA, serial: "TKT-AAA-2026-0005")

        let serial = TicketSerialGenerator.nextSerial(for: projectB, year: 2026)

        XCTAssertEqual(serial, "TKT-BBB-2026-0001")
    }
}
