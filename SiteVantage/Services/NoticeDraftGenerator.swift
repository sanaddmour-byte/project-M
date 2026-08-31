//
//  NoticeDraftGenerator.swift
//  SiteVantage
//
//  Generates a DRAFT-ONLY notice when a GC representative declines to sign.
//  Uses Project.noticeConfig.templateText when present (with simple
//  placeholder substitution); otherwise falls back to a clearly-labeled
//  generic placeholder template. This never sends anything — there is no
//  send capability anywhere in this build. See spec §4 screen 6 Path B and
//  DECISIONS.md for why a generic auto-fired notice would be a liability
//  problem (wrong clause referenced) that this design avoids.
//

import Foundation

enum NoticeDraftGenerator {
    static let genericPlaceholderTemplate = """
    [DRAFT NOTICE OF DISPUTED/UNSIGNED FIELD TICKET \u{2014} PLACEHOLDER TEMPLATE]

    To: {{RECIPIENT_ROLE}}
    Project: {{PROJECT_NAME}} ({{PROJECT_CODE}})
    Re: Field Ticket {{TICKET_SERIAL}} dated {{DATE}}

    This ticket documents extra work directed in the field that the General Contractor's representative did not sign at the time of presentation.

    Scope: {{SCOPE}}
    Amount: {{AMOUNT}}
    Reason given for non-signature: {{DECLINE_REASON}}

    This is a GENERIC PLACEHOLDER \u{2014} no contract clause reference has been configured for this project. Configure this project's actual notice clause in Project Settings and have your PM/counsel review before relying on or sending any notice.
    """

    static func generate(
        ticket: FieldTicket,
        project: Project,
        declineReasonText: String
    ) -> String {
        let template = project.noticeConfig?.templateText?.isEmpty == false
            ? project.noticeConfig!.templateText!
            : genericPlaceholderTemplate

        let recipientRole = project.noticeConfig?.requiredRecipientRole ?? "GC Project Executive"
        let clauseReference = project.noticeConfig?.contractClauseReference ?? "[contract clause not configured]"
        let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter
        }()

        var result = template
        let substitutions: [String: String] = [
            "{{RECIPIENT_ROLE}}": recipientRole,
            "{{PROJECT_NAME}}": project.name,
            "{{PROJECT_CODE}}": project.projectCode,
            "{{TICKET_SERIAL}}": ticket.ticketSerial,
            "{{DATE}}": dateFormatter.string(from: Date()),
            "{{SCOPE}}": ticket.scopeDescription,
            "{{AMOUNT}}": (ticket.grandTotal as NSDecimalNumber).description(withLocale: Locale(identifier: "en_US")),
            "{{DECLINE_REASON}}": declineReasonText,
            "{{CLAUSE_REFERENCE}}": clauseReference
        ]

        for (key, value) in substitutions {
            result = result.replacingOccurrences(of: key, with: value)
        }

        return result
    }
}
