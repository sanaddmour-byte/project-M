//
//  TicketListView.swift
//  SiteVantage
//

import SwiftUI
import SwiftData

struct TicketListView: View {
    @Environment(\.modelContext) private var modelContext
    let activeProject: Project?
    let allProjects: [Project]
    let settings: AppSettings

    @State private var showingNewTicket = false
    @State private var showingProjectPicker = false

    private var groupedTickets: [(status: TicketStatus, tickets: [FieldTicket])] {
        guard let activeProject else { return [] }
        let order: [TicketStatus] = [.draft, .declinedSignature, .signedOnSite, .rejected]
        return order.compactMap { status in
            let matches = activeProject.tickets
                .filter { $0.status == status }
                .sorted { $0.createdAt > $1.createdAt }
            return matches.isEmpty ? nil : (status, matches)
        }
    }

    var body: some View {
        Group {
            if allProjects.isEmpty {
                ContentUnavailableView(
                    "No Projects Set Up",
                    systemImage: "building.2",
                    description: Text("Create a project in the Projects & Rates tab before capturing tickets.")
                )
            } else if let activeProject {
                VStack(spacing: 0) {
                    ApprovedTotalBanner(project: activeProject)

                    if activeProject.tickets.isEmpty {
                        ContentUnavailableView(
                            "No Tickets Yet",
                            systemImage: "list.bullet.clipboard",
                            description: Text("Tap + to capture your first field ticket for \(activeProject.name).")
                        )
                        .frame(maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(groupedTickets, id: \.status) { group in
                                Section(group.status.displayName) {
                                    ForEach(group.tickets) { ticket in
                                        NavigationLink(value: ticket) {
                                            TicketRowView(ticket: ticket)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Active Project",
                    systemImage: "building.2",
                    description: Text("Pick an active project to start capturing tickets.")
                )
            }
        }
        .navigationTitle(activeProject?.name ?? "Tickets")
        .navigationDestination(for: FieldTicket.self) { ticket in
            TicketDetailView(ticket: ticket)
        }
        .toolbar {
            if allProjects.count > 1 {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingProjectPicker = true
                    } label: {
                        Image(systemName: "building.2")
                    }
                    .fieldTapTarget()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewTicket = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .fieldTapTarget()
                .disabled(activeProject == nil)
            }
        }
        .confirmationDialog("Switch Active Project", isPresented: $showingProjectPicker, titleVisibility: .visible) {
            ForEach(allProjects) { project in
                Button(project.name.isEmpty ? "Untitled Project" : project.name) {
                    settings.activeProjectID = project.id
                }
            }
        }
        .fullScreenCover(isPresented: $showingNewTicket) {
            if let activeProject {
                NavigationStack {
                    NewTicketFlowView(project: activeProject, settings: settings)
                }
            }
        }
    }
}

private struct ApprovedTotalBanner: View {
    let project: Project

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Approved Extra Work \u{2014} This Project")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(project.approvedExtraWorkTotal, format: .currency(code: "USD"))
                    .font(.title2.bold())
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
    }
}

private struct TicketRowView: View {
    let ticket: FieldTicket

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ticket.ticketSerial)
                    .font(.headline)
                Text(ticket.scopeDescription.isEmpty ? "No scope description yet" : ticket.scopeDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(ticket.createdAt, format: .dateTime.month().day().year().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(ticket.grandTotal, format: .currency(code: "USD"))
                    .font(.subheadline.bold())
                StatusBadge(status: ticket.status)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: TicketStatus

    private var color: Color {
        switch status {
        case .draft: return .gray
        case .signedOnSite: return .green
        case .declinedSignature: return .orange
        case .rejected: return .red
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
