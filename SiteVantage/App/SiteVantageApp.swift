//
//  SiteVantageApp.swift
//  SiteVantage
//

import SwiftUI
import SwiftData

@main
struct SiteVantageApp: App {
    let modelContainer: ModelContainer = PersistenceContainer.shared

    init() {
        // Bootstrap the single AppSettings row before any view's body ever
        // runs, so downstream views can treat @Query's settingsRows.first
        // as always present instead of inserting into the context (a
        // model mutation) from inside a computed property that view
        // rendering depends on.
        _ = AppSettings.fetchOrCreate(in: modelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(modelContainer)
    }
}
