//
//  TicketLaborItem.swift
//  SiteVantage
//

import Foundation
import SwiftData

@Model
final class TicketLaborItem {
    var id: UUID = UUID()
    var customDescription: String = ""
    var headcount: Int = 1
    var standardHours: Decimal = Decimal(0)
    var overtimeHours: Decimal = Decimal(0)
    var calculatedCost: Decimal = Decimal(0)

    /// True when this line was pre-filled by the on-device voice parser and
    /// has not yet been confirmed/edited by the foreman. Surfaced in the UI
    /// as a "suggested" badge — never treated as authoritative.
    var isParserSuggested: Bool = false

    var linkedRate: ProjectRate?
    var ticket: FieldTicket?

    init(
        customDescription: String = "",
        headcount: Int = 1,
        standardHours: Decimal = Decimal(0),
        overtimeHours: Decimal = Decimal(0),
        linkedRate: ProjectRate? = nil,
        isParserSuggested: Bool = false
    ) {
        self.id = UUID()
        self.customDescription = customDescription
        self.headcount = headcount
        self.standardHours = standardHours
        self.overtimeHours = overtimeHours
        self.calculatedCost = Decimal(0)
        self.linkedRate = linkedRate
        self.isParserSuggested = isParserSuggested
    }
}
