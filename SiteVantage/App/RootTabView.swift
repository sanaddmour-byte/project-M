//
//  RootTabView.swift
//  SiteVantage
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Query private var settingsRows: [AppSettings]
    @Query(sort: \Project.name) private var projects: [Project]

    // SiteVantageApp.init() bootstraps the single AppSettings row before
    // any view body runs, so this is always non-nil in practice. The
    // fallback is a transient, never-inserted default so a render never
    // crashes even if that invariant is ever broken.
    private var settings: AppSettings {
        settingsRows.first ?? AppSettings()
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
    }
}
