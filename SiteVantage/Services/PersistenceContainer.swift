//
//  PersistenceContainer.swift
//  SiteVantage
//
//  Local-only SwiftData stack. No CloudKit container is configured in this
//  build (single-device, offline-first per spec) — but every model is a
//  plain SwiftData @Model with value-type-friendly relationships, so a
//  future sync layer (CloudKit or a custom API) can be added by swapping
//  the ModelConfiguration without changing the model graph.
//

import Foundation
import SwiftData

enum PersistenceContainer {
    static let shared: ModelContainer = {
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

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to initialize local SwiftData store: \(error)")
        }
    }()
}
