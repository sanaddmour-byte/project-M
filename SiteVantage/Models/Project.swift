//
//  Project.swift
//  SiteVantage
//

import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID = UUID()
    var name: String = ""
    var projectCode: String = ""
    var gcCompanyName: String = ""
    var gcSuperName: String?
    var gcSuperEmail: String?
    var requireSignature: Bool = true

    /// Drives which e-signature disclosure template is rendered on the
    /// signature step. Only "US" ships with real copy in this build; see
    /// DECISIONS.md.
    var jurisdiction: String = "US"

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade)
    var noticeConfig: ProjectNoticeConfig?

    @Relationship(deleteRule: .cascade, inverse: \ProjectRate.project)
    var rates: [ProjectRate] = []

    @Relationship(deleteRule: .cascade, inverse: \FieldTicket.project)
    var tickets: [FieldTicket] = []

    init(
        name: String = "",
        projectCode: String = "",
        gcCompanyName: String = "",
        gcSuperName: String? = nil,
        gcSuperEmail: String? = nil,
        requireSignature: Bool = true,
        jurisdiction: String = "US"
    ) {
        self.id = UUID()
        self.name = name
        self.projectCode = projectCode
        self.gcCompanyName = gcCompanyName
        self.gcSuperName = gcSuperName
        self.gcSuperEmail = gcSuperEmail
        self.requireSignature = requireSignature
        self.jurisdiction = jurisdiction
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Local aggregate: sum of grandTotal across all SIGNED_ON_SITE tickets
    /// for this project. This is the foreman-facing "value loop" counter —
    /// purely a local query, no backend involved.
    var approvedExtraWorkTotal: Decimal {
        tickets
            .filter { $0.status == .signedOnSite }
            .reduce(Decimal(0)) { $0 + $1.grandTotal }
    }
}
