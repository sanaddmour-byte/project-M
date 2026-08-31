//
//  ProjectNoticeConfig.swift
//  SiteVantage
//

import Foundation
import SwiftData

@Model
final class ProjectNoticeConfig {
    var id: UUID = UUID()
    var contractClauseReference: String?
    var requiredNoticePeriodHours: Int?
    var requiredDeliveryMethod: String?
    var requiredRecipientRole: String?

    /// Must be true before `autoSendApproved` can be set true. Enforced in
    /// the UI (NoticeConfigEditorView disables the toggle) — there is no
    /// send capability in this build regardless, so this only guards a
    /// forward-compatible flag for a future release.
    var counselReviewed: Bool = false

    /// Forward-compatible only. This build has no send capability at all —
    /// setting this true does nothing today. See DECISIONS.md.
    var autoSendApproved: Bool = false

    var templateText: String?

    var project: Project?

    init(
        contractClauseReference: String? = nil,
        requiredNoticePeriodHours: Int? = nil,
        requiredDeliveryMethod: String? = nil,
        requiredRecipientRole: String? = nil,
        counselReviewed: Bool = false,
        autoSendApproved: Bool = false,
        templateText: String? = nil
    ) {
        self.id = UUID()
        self.contractClauseReference = contractClauseReference
        self.requiredNoticePeriodHours = requiredNoticePeriodHours
        self.requiredDeliveryMethod = requiredDeliveryMethod
        self.requiredRecipientRole = requiredRecipientRole
        self.counselReviewed = counselReviewed
        self.autoSendApproved = autoSendApproved
        self.templateText = templateText
    }
}
