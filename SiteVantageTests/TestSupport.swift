//
//  TestSupport.swift
//  SiteVantageTests
//
//  Shared in-memory SwiftData stack for tests. Using a real, in-memory
//  ModelContainer (rather than constructing @Model instances loose and
//  unattached) matches Apple's documented pattern for testing SwiftData
//  code and exercises the same relationship/inverse machinery the app
//  actually relies on.
//

import Foundation
import SwiftData
@testable import SiteVantage

@MainActor
enum TestSupport {
    static func makeInMemoryContext() -> ModelContext {
        let schema = Schema([
            Project.self,
            ProjectNoticeConfig.self,
            ProjectRate.self,
            FieldTicket.self,
            TicketLaborItem.self,
            TicketEquipmentItem.self,
            TicketMaterialItem.self,
            TicketEvidencePhoto.self,
            AppSettings.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    static func makeProject(
        in context: ModelContext,
        name: String = "Riverfront Tower",
        code: String = "RVF",
        gcCompany: String = "Acme Construction"
    ) -> Project {
        let project = Project(name: name, projectCode: code, gcCompanyName: gcCompany)
        context.insert(project)
        return project
    }

    static func makeLaborRate(
        in context: ModelContext,
        project: Project,
        title: String = "Journeyman Electrician",
        standardRate: Decimal = 85,
        otRate: Decimal = 127.50
    ) -> ProjectRate {
        let rate = ProjectRate(itemType: .labor, resourceTitle: title, standardRate: standardRate, premiumOTRate: otRate)
        rate.project = project
        project.rates.append(rate)
        context.insert(rate)
        return rate
    }

    static func makeEquipmentRate(
        in context: ModelContext,
        project: Project,
        title: String = "Scissor Lift",
        standardRate: Decimal = 40
    ) -> ProjectRate {
        let rate = ProjectRate(itemType: .equipment, resourceTitle: title, standardRate: standardRate)
        rate.project = project
        project.rates.append(rate)
        context.insert(rate)
        return rate
    }

    static func makeMaterialRate(
        in context: ModelContext,
        project: Project,
        title: String = "1/2\" EMT Conduit (ft)",
        standardRate: Decimal = 2.25
    ) -> ProjectRate {
        let rate = ProjectRate(itemType: .material, resourceTitle: title, unitOfMeasure: "EACH", standardRate: standardRate)
        rate.project = project
        project.rates.append(rate)
        context.insert(rate)
        return rate
    }

    static func makeTicket(
        in context: ModelContext,
        project: Project,
        serial: String? = nil,
        scope: String = "Test scope"
    ) -> FieldTicket {
        let ticket = FieldTicket(ticketSerial: serial ?? TicketSerialGenerator.nextSerial(for: project), scopeDescription: scope)
        ticket.project = project
        project.tickets.append(ticket)
        context.insert(ticket)
        return ticket
    }
}
