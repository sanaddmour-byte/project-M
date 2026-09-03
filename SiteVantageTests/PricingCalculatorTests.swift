//
//  PricingCalculatorTests.swift
//  SiteVantageTests
//

import XCTest
import SwiftData
@testable import SiteVantage

@MainActor
final class PricingCalculatorTests: XCTestCase {
    func testLaborLineCostCombinesStandardAndOvertimeAtTheirOwnRates() {
        let context = TestSupport.makeInMemoryContext()
        let project = TestSupport.makeProject(in: context)
        let rate = TestSupport.makeLaborRate(in: context, project: project, standardRate: 80, otRate: 120)

        let item = TicketLaborItem(customDescription: "Electrician", headcount: 2, standardHours: 8, overtimeHours: 2, linkedRate: rate)

        // 2 heads * 8 std hrs * $80 = $1280; 2 heads * 2 OT hrs * $120 = $480
        XCTAssertEqual(PricingCalculator.laborLineCost(item), 1280 + 480)
    }

    func testLaborLineCostFallsBackToStandardRateWhenNoPremiumRateSet() {
        let context = TestSupport.makeInMemoryContext()
        let project = TestSupport.makeProject(in: context)
        let rate = TestSupport.makeLaborRate(in: context, project: project, standardRate: 50, otRate: 0)

        let item = TicketLaborItem(customDescription: "Laborer", headcount: 1, standardHours: 0, overtimeHours: 4, linkedRate: rate)

        // No premium rate configured (0) -> overtime falls back to standard rate.
        XCTAssertEqual(PricingCalculator.laborLineCost(item), 4 * 50)
    }

    func testLaborLineCostIsZeroWithoutALinkedRate() {
        let item = TicketLaborItem(customDescription: "Unlinked", headcount: 3, standardHours: 10, overtimeHours: 1, linkedRate: nil)
        XCTAssertEqual(PricingCalculator.laborLineCost(item), 0)
    }

    func testEquipmentLineCostCombinesOperatedAndStandbyHours() {
        let context = TestSupport.makeInMemoryContext()
        let project = TestSupport.makeProject(in: context)
        let rate = TestSupport.makeEquipmentRate(in: context, project: project, standardRate: 40)

        let item = TicketEquipmentItem(customDescription: "Scissor Lift", quantity: 2, hoursOperated: 6, hoursStandby: 2, linkedRate: rate)

        // No premium standby rate set -> falls back to standard: (2*6*40) + (2*2*40)
        XCTAssertEqual(PricingCalculator.equipmentLineCost(item), 480 + 160)
    }

    func testMaterialLineCostIsQuantityTimesRate() {
        let context = TestSupport.makeInMemoryContext()
        let project = TestSupport.makeProject(in: context)
        let rate = TestSupport.makeMaterialRate(in: context, project: project, standardRate: 2.5)

        let item = TicketMaterialItem(customDescription: "Conduit", quantity: 40, linkedRate: rate)

        XCTAssertEqual(PricingCalculator.materialLineCost(item), 100)
    }

    func testApplyPricingWritesLineCostsAndTicketTotals() {
        let context = TestSupport.makeInMemoryContext()
        let project = TestSupport.makeProject(in: context)
        let laborRate = TestSupport.makeLaborRate(in: context, project: project, standardRate: 80, otRate: 120)
        let equipmentRate = TestSupport.makeEquipmentRate(in: context, project: project, standardRate: 40)
        let materialRate = TestSupport.makeMaterialRate(in: context, project: project, standardRate: 2.5)

        let ticket = TestSupport.makeTicket(in: context, project: project)

        let labor = TicketLaborItem(customDescription: "Electrician", headcount: 1, standardHours: 8, overtimeHours: 0, linkedRate: laborRate)
        labor.ticket = ticket
        ticket.laborItems.append(labor)

        let equipment = TicketEquipmentItem(customDescription: "Lift", quantity: 1, hoursOperated: 4, hoursStandby: 0, linkedRate: equipmentRate)
        equipment.ticket = ticket
        ticket.equipmentItems.append(equipment)

        let material = TicketMaterialItem(customDescription: "Conduit", quantity: 10, linkedRate: materialRate)
        material.ticket = ticket
        ticket.materialItems.append(material)

        PricingCalculator.applyPricing(to: ticket)

        XCTAssertEqual(labor.calculatedCost, 640) // 1 * 8 * 80
        XCTAssertEqual(equipment.calculatedCost, 160) // 1 * 4 * 40
        XCTAssertEqual(material.calculatedCost, 25) // 10 * 2.5

        XCTAssertEqual(ticket.laborSubtotal, 640)
        XCTAssertEqual(ticket.equipmentSubtotal, 160)
        XCTAssertEqual(ticket.materialSubtotal, 25)
        XCTAssertEqual(ticket.grandTotal, 640 + 160 + 25)
    }

    func testApplyPricingOnTicketWithNoLineItemsZeroesTotals() {
        let context = TestSupport.makeInMemoryContext()
        let project = TestSupport.makeProject(in: context)
        let ticket = TestSupport.makeTicket(in: context, project: project)

        PricingCalculator.applyPricing(to: ticket)

        XCTAssertEqual(ticket.grandTotal, 0)
    }
}
