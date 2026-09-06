//
//  NoticeDraftGeneratorTests.swift
//  SiteVantageTests
//

import XCTest
import SwiftData
@testable import SiteVantage

@MainActor
final class NoticeDraftGeneratorTests: XCTestCase {
    func testFallsBackToGenericPlaceholderWhenNoNoticeConfigExists() {
        let context = TestSupport.makeInMemoryContext()
        let project = TestSupport.makeProject(in: context, name: "Riverfront Tower", code: "RVF")
        let ticket = TestSupport.makeTicket(in: context, project: project, serial: "TKT-RVF-2026-0001", scope: "Extra conduit run")

        let draft = NoticeDraftGenerator.generate(ticket: ticket, project: project, declineReasonText: "Disputes scope")

        XCTAssertTrue(draft.contains("GENERIC PLACEHOLDER"), "with no notice config, the draft must be clearly labeled generic")
        XCTAssertTrue(draft.contains("TKT-RVF-2026-0001"))
        XCTAssertTrue(draft.contains("Riverfront Tower"))
        XCTAssertTrue(draft.contains("Disputes scope"))
    }

    func testFallsBackToGenericPlaceholderWhenTemplateTextIsEmptyString() {
        let context = TestSupport.makeInMemoryContext()
        let project = TestSupport.makeProject(in: context)
        let config = ProjectNoticeConfig(templateText: "")
        config.project = project
        project.noticeConfig = config
        context.insert(config)
        let ticket = TestSupport.makeTicket(in: context, project: project)

        let draft = NoticeDraftGenerator.generate(ticket: ticket, project: project, declineReasonText: "Other")

        XCTAssertTrue(draft.contains("GENERIC PLACEHOLDER"))
    }

    func testUsesProjectSpecificTemplateWhenConfigured() {
        let context = TestSupport.makeInMemoryContext()
        let project = TestSupport.makeProject(in: context, name: "Riverfront Tower", code: "RVF")
        let config = ProjectNoticeConfig(
            requiredRecipientRole: "PM Director",
            templateText: "Notice to {{RECIPIENT_ROLE}} re: {{TICKET_SERIAL}} on {{PROJECT_NAME}}. Reason: {{DECLINE_REASON}}."
        )
        config.project = project
        project.noticeConfig = config
        context.insert(config)
        let ticket = TestSupport.makeTicket(in: context, project: project, serial: "TKT-RVF-2026-0009")

        let draft = NoticeDraftGenerator.generate(ticket: ticket, project: project, declineReasonText: "Not authorized to approve costs")

        XCTAssertEqual(draft, "Notice to PM Director re: TKT-RVF-2026-0009 on Riverfront Tower. Reason: Not authorized to approve costs.")
        XCTAssertFalse(draft.contains("GENERIC PLACEHOLDER"), "a configured template must not fall back to the generic one")
    }

    func testGenericTemplateDefaultsRecipientRoleWhenNotConfigured() {
        let context = TestSupport.makeInMemoryContext()
        let project = TestSupport.makeProject(in: context)
        let ticket = TestSupport.makeTicket(in: context, project: project)

        let draft = NoticeDraftGenerator.generate(ticket: ticket, project: project, declineReasonText: "Other")

        XCTAssertTrue(draft.contains("GC Project Executive"))
    }
}
