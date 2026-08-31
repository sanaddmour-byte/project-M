//
//  ProjectEditView.swift
//  SiteVantage
//

import SwiftUI
import SwiftData

struct ProjectEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var workingProject: Project
    private let isNew: Bool

    init(project: Project?) {
        if let project {
            _workingProject = State(initialValue: project)
            isNew = false
        } else {
            // Inserted immediately so nothing is lost if the foreman/admin
            // is interrupted mid-entry, per the app-wide "no explicit save
            // step" requirement.
            let created = Project()
            _workingProject = State(initialValue: created)
            isNew = true
        }
    }

    private static let jurisdictions = ["US", "CA", "UK", "OTHER"]

    var body: some View {
        Form {
            Section("Project") {
                TextField("Project Name", text: $workingProject.name)
                    .onChange(of: workingProject.name) { persist() }
                TextField("Project Code", text: $workingProject.projectCode)
                    .autocapitalization(.allCharacters)
                    .onChange(of: workingProject.projectCode) { persist() }
                Picker("Jurisdiction", selection: $workingProject.jurisdiction) {
                    ForEach(Self.jurisdictions, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                .onChange(of: workingProject.jurisdiction) { persist() }
                Text("Jurisdiction selects the e-signature disclosure text shown on the signature step. Only US ships with reviewed copy in this build \u{2014} see DECISIONS.md.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("General Contractor") {
                TextField("GC Company Name", text: $workingProject.gcCompanyName)
                    .onChange(of: workingProject.gcCompanyName) { persist() }
                TextField("GC Superintendent Name", text: Binding(
                    get: { workingProject.gcSuperName ?? "" },
                    set: { workingProject.gcSuperName = $0.isEmpty ? nil : $0 }
                ))
                .onChange(of: workingProject.gcSuperName) { persist() }
                TextField("GC Superintendent Email", text: Binding(
                    get: { workingProject.gcSuperEmail ?? "" },
                    set: { workingProject.gcSuperEmail = $0.isEmpty ? nil : $0 }
                ))
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .onChange(of: workingProject.gcSuperEmail) { persist() }
            }

            Section("Signature") {
                Toggle("Require Signature to Approve", isOn: $workingProject.requireSignature)
                    .fieldTapTarget()
                    .onChange(of: workingProject.requireSignature) { persist() }
            }

            Section("Rates & Notices") {
                NavigationLink {
                    RateSheetEditorView(project: workingProject)
                } label: {
                    Label("Rate Sheet (\(workingProject.rates.count))", systemImage: "dollarsign.square")
                }
                NavigationLink {
                    NoticeConfigEditorView(project: workingProject)
                } label: {
                    Label("Notice Configuration", systemImage: "doc.text")
                }
            }

            if !isNew {
                Section {
                    Button("Delete Project", role: .destructive) {
                        modelContext.delete(workingProject)
                        persist()
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(isNew ? "New Project" : workingProject.name.isEmpty ? "Project" : workingProject.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isNew {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        persist()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if isNew, workingProject.modelContext == nil {
                modelContext.insert(workingProject)
                persist()
            }
        }
    }

    private func persist() {
        workingProject.updatedAt = Date()
        try? modelContext.save()
    }
}
