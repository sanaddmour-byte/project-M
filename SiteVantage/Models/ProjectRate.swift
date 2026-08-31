//
//  ProjectRate.swift
//  SiteVantage
//

import Foundation
import SwiftData

@Model
final class ProjectRate {
    var id: UUID = UUID()
    var itemType: RateItemType = RateItemType.labor
    var resourceTitle: String = ""
    var unitOfMeasure: String = "HOURS"
    var standardRate: Decimal = Decimal(0)
    var premiumOTRate: Decimal = Decimal(0)
    var isArchived: Bool = false

    var project: Project?

    init(
        itemType: RateItemType,
        resourceTitle: String,
        unitOfMeasure: String = "HOURS",
        standardRate: Decimal,
        premiumOTRate: Decimal = Decimal(0)
    ) {
        self.id = UUID()
        self.itemType = itemType
        self.resourceTitle = resourceTitle
        self.unitOfMeasure = unitOfMeasure
        self.standardRate = standardRate
        self.premiumOTRate = premiumOTRate
        self.isArchived = false
    }
}
