//
//  SiteVantageApp.swift
//  SiteVantage
//

import SwiftUI
import SwiftData

@main
struct SiteVantageApp: App {
    let modelContainer: ModelContainer = PersistenceContainer.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(modelContainer)
    }
}
