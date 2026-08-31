//
//  PricingCalculator.swift
//  SiteVantage
//
//  Pure calculation engine: line items x ProjectRate -> subtotals + grand
//  total. Kept side-effect-free (returns a result, does not itself save)
//  so the Pricing screen can recompute live on every keystroke without
//  touching the model context.
//

import Foundation

struct TicketPricingResult {
    var laborSubtotal: Decimal
    var equipmentSubtotal: Decimal
    var materialSubtotal: Decimal
    var grandTotal: Decimal
    var laborLineCosts: [UUID: Decimal]
    var equipmentLineCosts: [UUID: Decimal]
    var materialLineCosts: [UUID: Decimal]
}

enum PricingCalculator {
    static func laborLineCost(_ item: TicketLaborItem) -> Decimal {
        guard let rate = item.linkedRate else { return 0 }
        let headcountDecimal = Decimal(item.headcount)
        let standard = headcountDecimal * item.standardHours * rate.standardRate
        let overtimeRate = rate.premiumOTRate > 0 ? rate.premiumOTRate : rate.standardRate
        let overtime = headcountDecimal * item.overtimeHours * overtimeRate
        return standard + overtime
    }

    static func equipmentLineCost(_ item: TicketEquipmentItem) -> Decimal {
        guard let rate = item.linkedRate else { return 0 }
        let quantityDecimal = Decimal(item.quantity)
        let operating = quantityDecimal * item.hoursOperated * rate.standardRate
        let standbyRate = rate.premiumOTRate > 0 ? rate.premiumOTRate : rate.standardRate
        let standby = quantityDecimal * item.hoursStandby * standbyRate
        return operating + standby
    }

    static func materialLineCost(_ item: TicketMaterialItem) -> Decimal {
        guard let rate = item.linkedRate else { return 0 }
        return item.quantity * rate.standardRate
    }

    static func calculate(
        laborItems: [TicketLaborItem],
        equipmentItems: [TicketEquipmentItem],
        materialItems: [TicketMaterialItem]
    ) -> TicketPricingResult {
        var laborCosts: [UUID: Decimal] = [:]
        var equipmentCosts: [UUID: Decimal] = [:]
        var materialCosts: [UUID: Decimal] = [:]

        var laborSubtotal = Decimal(0)
        for item in laborItems {
            let cost = laborLineCost(item)
            laborCosts[item.id] = cost
            laborSubtotal += cost
        }

        var equipmentSubtotal = Decimal(0)
        for item in equipmentItems {
            let cost = equipmentLineCost(item)
            equipmentCosts[item.id] = cost
            equipmentSubtotal += cost
        }

        var materialSubtotal = Decimal(0)
        for item in materialItems {
            let cost = materialLineCost(item)
            materialCosts[item.id] = cost
            materialSubtotal += cost
        }

        let grandTotal = laborSubtotal + equipmentSubtotal + materialSubtotal

        return TicketPricingResult(
            laborSubtotal: laborSubtotal,
            equipmentSubtotal: equipmentSubtotal,
            materialSubtotal: materialSubtotal,
            grandTotal: grandTotal,
            laborLineCosts: laborCosts,
            equipmentLineCosts: equipmentCosts,
            materialLineCosts: materialCosts
        )
    }

    /// Recomputes and writes calculatedCost on every line item plus the
    /// ticket's subtotal/grandTotal fields. Call after any edit to line
    /// items or before persisting a status change.
    @discardableResult
    static func applyPricing(to ticket: FieldTicket) -> TicketPricingResult {
        let result = calculate(
            laborItems: ticket.laborItems,
            equipmentItems: ticket.equipmentItems,
            materialItems: ticket.materialItems
        )

        for item in ticket.laborItems {
            item.calculatedCost = result.laborLineCosts[item.id] ?? 0
        }
        for item in ticket.equipmentItems {
            item.calculatedCost = result.equipmentLineCosts[item.id] ?? 0
        }
        for item in ticket.materialItems {
            item.calculatedCost = result.materialLineCosts[item.id] ?? 0
        }

        ticket.laborSubtotal = result.laborSubtotal
        ticket.equipmentSubtotal = result.equipmentSubtotal
        ticket.materialSubtotal = result.materialSubtotal
        ticket.grandTotal = result.grandTotal
        ticket.updatedAt = Date()

        return result
    }
}
