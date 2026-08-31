//
//  RootTabView.swift
//  SiteVantage
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsRows: [AppSettings]
    @Query(sort: \Project.name) private var projects: [Project]

    private var settings: AppSettings {
        if let existing = settingsRows.first {
            return existing
        }
        return AppSettings.fetchOrCreate(in: modelContext)
    }

    private var activeProject: Project? {
        if let activeID = settings.activeProjectID,
           let match = projects.first(where: { $0.id == activeID }) {
            return match
        }
        return projects.first
    }

    var body: some View {
        TabView {
            NavigationStack {
                TicketListView(activeProject: activeProject, allProjects: projects, settings: settings)
            }
            .tabItem {
                Label("Tickets", systemImage: "list.bullet.clipboard")
            }

            NavigationStack {
                ProjectListView()
            }
            .tabItem {
                Label("Projects & Rates", systemImage: "building.2")
            }
        }
        .tint(FieldPalette.accent(highContrast: settings.highContrastModeEnabled))
        .preferredColorScheme(settings.highContrastModeEnabled ? .dark : nil)
        .onAppear {
            if settingsRows.isEmpty {
                _ = AppSettings.fetchOrCreate(in: modelContext)
            }
        }
    }
}
