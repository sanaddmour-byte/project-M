//
//  AppSettings.swift
//  SiteVantage
//
//  Single-row settings record. No multi-user auth/login exists in this
//  build — a plain "current user name" field is enough to label tickets
//  and drive the approved-$ counter, per spec §7.
//

import Foundation
import SwiftData

@Model
final class AppSettings {
    /// Fixed identifier so callers can always fetch/create the one row.
    var singletonKey: String = "default"

    var currentUserName: String = ""
    var currentUserTitle: String = ""
    var highContrastModeEnabled: Bool = false
    var activeProjectID: UUID?

    init() {
        self.singletonKey = "default"
        self.currentUserName = ""
        self.currentUserTitle = ""
        self.highContrastModeEnabled = false
    }

    /// Fetches the single settings row, creating and inserting it on first
    /// launch. Callers should hold a stable reference (e.g. via @Query)
    /// rather than calling this repeatedly on every render.
    @MainActor
    static func fetchOrCreate(in context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }
}
