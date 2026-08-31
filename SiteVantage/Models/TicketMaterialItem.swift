//
//  TicketMaterialItem.swift
//  SiteVantage
//
//  Not explicitly enumerated in the original spec (which defines
//  TicketLaborItem / TicketEquipmentItem but only a bare `materialSubtotal`
//  field with no backing line-item collection). Added for consistency with
//  labor/equipment and because ProjectRate already supports a MATERIAL
//  itemType. See DECISIONS.md.
//

import Foundation
import SwiftData

@Model
final class TicketMaterialItem {
    var id: UUID = UUID()
    var customDescription: String = ""
    var quantity: Decimal = Decimal(1)
    var calculatedCost: Decimal = Decimal(0)
    var isParserSuggested: Bool = false

    var linkedRate: ProjectRate?
    var ticket: FieldTicket?

    init(
        customDescription: String = "",
        quantity: Decimal = Decimal(1),
        linkedRate: ProjectRate? = nil,
        isParserSuggested: Bool = false
    ) {
        self.id = UUID()
        self.customDescription = customDescription
        self.quantity = quantity
        self.calculatedCost = Decimal(0)
        self.linkedRate = linkedRate
        self.isParserSuggested = isParserSuggested
    }
}
