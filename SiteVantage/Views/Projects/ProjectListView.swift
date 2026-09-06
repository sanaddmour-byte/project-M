//
//  ProjectListView.swift
//  SiteVantage
//

import SwiftUI
import SwiftData

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.name) private var projects: [Project]
    @Query private var settingsRows: [AppSettings]

    @State private var showingNewProject = false

    // See RootTabView: the single AppSettings row is bootstrapped at app
    // launch, so this never needs to insert one during a view render.
    private var settings: AppSettings {
        settingsRows.first ?? AppSettings()
    }

    var body: some View {
        Group {
            if projects.isEmpty {
                ContentUnavailableView(
                    "No Projects Yet",
                    systemImage: "building.2",
                    description: Text("Add a project to set up its GC contact, rate sheet, and notice configuration.")
                )
            } else {
                List {
                    ForEach(projects) { project in
                        NavigationLink(value: project) {
                            ProjectRowView(project: project, isActive: project.id == settings.activeProjectID)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                setActive(project)
                            } label: {
                                Label("Set Active", systemImage: "checkmark.circle")
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete(perform: deleteProjects)
                }
            }
        }
        .navigationTitle("Projects")
        .navigationDestination(for: Project.self) { project in
            ProjectEditView(project: project)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                NavigationLink {
                    SettingsView(settings: settings)
                } label: {
                    Image(systemName: "gearshape")
                }
                .fieldTapTarget()
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewProject = true
                } label: {
                    Image(systemName: "plus")
                }
                .fieldTapTarget()
            }
        }
        .sheet(isPresented: $showingNewProject) {
            NavigationStack {
                ProjectEditView(project: nil)
            }
        }
    }

    private func setActive(_ project: Project) {
        settings.activeProjectID = project.id
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(projects[index])
        }
    }
}

private struct ProjectRowView: View {
    let project: Project
    let isActive: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(project.name.isEmpty ? "Untitled Project" : project.name)
                        .font(.headline)
                    if isActive {
                        Text("ACTIVE")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(Color.blue)
                            .clipShape(Capsule())
                    }
                }
                Text("\(project.projectCode) \u{2022} \(project.gcCompanyName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Approved Extra Work: \(project.approvedExtraWorkTotal, format: .currency(code: "USD"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
