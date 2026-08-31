//
//  RateSheetEditorView.swift
//  SiteVantage
//

import SwiftUI
import SwiftData

struct RateSheetEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: Project

    @State private var editingRate: ProjectRate?
    @State private var showingNewRateType: RateItemType?

    private func rates(for type: RateItemType) -> [ProjectRate] {
        project.rates
            .filter { $0.itemType == type && !$0.isArchived }
            .sorted { $0.resourceTitle < $1.resourceTitle }
    }

    var body: some View {
        List {
            ForEach(RateItemType.allCases) { type in
                Section {
                    let items = rates(for: type)
                    if items.isEmpty {
                        Text("No \(type.displayName.lowercased()) rates yet.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(items) { rate in
                            Button {
                                editingRate = rate
                            } label: {
                                RateRowView(rate: rate)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            deleteRates(type: type, at: offsets, items: items)
                        }
                    }
                } header: {
                    HStack {
                        Text(type.displayName)
                        Spacer()
                        Button {
                            showingNewRateType = type
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .fieldTapTarget()
                    }
                }
            }
        }
        .navigationTitle("Rate Sheet")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingRate) { rate in
            NavigationStack {
                RateEditSheet(project: project, rate: rate, itemType: rate.itemType)
            }
        }
        .sheet(item: $showingNewRateType) { type in
            NavigationStack {
                RateEditSheet(project: project, rate: nil, itemType: type)
            }
        }
    }

    private func deleteRates(type: RateItemType, at offsets: IndexSet, items: [ProjectRate]) {
        for index in offsets {
            // Archive instead of hard-delete: rates already linked to
            // historical ticket line items must keep pricing on old
            // tickets stable and auditable.
            items[index].isArchived = true
        }
        try? modelContext.save()
    }
}

private struct RateRowView: View {
    let rate: ProjectRate

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rate.resourceTitle)
                .font(.body)
            Text("\(rate.standardRate, format: .currency(code: "USD"))/\(rate.unitOfMeasure.lowercased()) \u{2022} OT \(rate.premiumOTRate, format: .currency(code: "USD"))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct RateEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var project: Project
    let rate: ProjectRate?
    let itemType: RateItemType

    @State private var resourceTitle: String = ""
    @State private var unitOfMeasure: String = "HOURS"
    @State private var standardRate: Decimal = 0
    @State private var premiumOTRate: Decimal = 0

    var body: some View {
        Form {
            Section(itemType.displayName) {
                TextField("Description (e.g. Journeyman Electrician)", text: $resourceTitle)
                TextField("Unit of Measure", text: $unitOfMeasure)
                TextField("Standard Rate", value: $standardRate, format: .currency(code: "USD"))
                    .keyboardType(.decimalPad)
                TextField("Overtime / Premium Rate", value: $premiumOTRate, format: .currency(code: "USD"))
                    .keyboardType(.decimalPad)
            }
        }
        .navigationTitle(rate == nil ? "New Rate" : "Edit Rate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(resourceTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if let rate {
                resourceTitle = rate.resourceTitle
                unitOfMeasure = rate.unitOfMeasure
                standardRate = rate.standardRate
                premiumOTRate = rate.premiumOTRate
            }
        }
    }

    private func save() {
        if let rate {
            rate.resourceTitle = resourceTitle
            rate.unitOfMeasure = unitOfMeasure
            rate.standardRate = standardRate
            rate.premiumOTRate = premiumOTRate
        } else {
            let newRate = ProjectRate(
                itemType: itemType,
                resourceTitle: resourceTitle,
                unitOfMeasure: unitOfMeasure,
                standardRate: standardRate,
                premiumOTRate: premiumOTRate
            )
            newRate.project = project
            project.rates.append(newRate)
            modelContext.insert(newRate)
        }
        try? modelContext.save()
        dismiss()
    }
}
