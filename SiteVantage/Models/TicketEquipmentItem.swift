//
//  TicketEquipmentItem.swift
//  SiteVantage
//

import Foundation
import SwiftData

@Model
final class TicketEquipmentItem {
    var id: UUID = UUID()
    var customDescription: String = ""
    var quantity: Int = 1
    var hoursOperated: Decimal = Decimal(0)
    var hoursStandby: Decimal = Decimal(0)
    var calculatedCost: Decimal = Decimal(0)

    /// True when this line was pre-filled by the on-device voice parser and
    /// has not yet been confirmed/edited by the foreman.
    var isParserSuggested: Bool = false

    var linkedRate: ProjectRate?
    var ticket: FieldTicket?

    init(
        customDescription: String = "",
        quantity: Int = 1,
        hoursOperated: Decimal = Decimal(0),
        hoursStandby: Decimal = Decimal(0),
        linkedRate: ProjectRate? = nil,
        isParserSuggested: Bool = false
    ) {
        self.id = UUID()
        self.customDescription = customDescription
        self.quantity = quantity
        self.hoursOperated = hoursOperated
        self.hoursStandby = hoursStandby
        self.calculatedCost = Decimal(0)
        self.linkedRate = linkedRate
        self.isParserSuggested = isParserSuggested
    }
}
