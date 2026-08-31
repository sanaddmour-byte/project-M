//
//  PricingStepView.swift
//  SiteVantage
//
//  Line items x project rates -> live-calculated subtotals and grand total,
//  fully editable (spec §4 screen 5). Labor/equipment quantities and hours
//  can still be adjusted here; materials (never voice-parsed) are added
//  here directly against the project's MATERIAL rate sheet.
//

import SwiftUI
import SwiftData

struct PricingStepView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var ticket: FieldTicket
    let project: Project
    let onBack: () -> Void
    let onNext: () -> Void

    @State private var showingNewMaterial = false

    private var pricing: TicketPricingResult {
        PricingCalculator.calculate(
            laborItems: ticket.laborItems,
            equipmentItems: ticket.equipmentItems,
            materialItems: ticket.materialItems
        )
    }

    var body: some View {
        Form {
            if ticket.laborItems.isEmpty && ticket.equipmentItems.isEmpty && ticket.materialItems.isEmpty {
                Section {
                    Text("No line items yet. Go back to add labor/equipment, or add a material below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !ticket.laborItems.isEmpty {
                Section("Labor") {
                    ForEach(ticket.laborItems) { item in
                        LineItemSummaryRow(
                            title: item.customDescription.isEmpty ? "Labor item" : item.customDescription,
                            detail: "\(item.headcount)x \u{2022} \(item.standardHours) std + \(item.overtimeHours) OT hrs",
                            missingRate: item.linkedRate == nil,
                            cost: pricing.laborLineCosts[item.id] ?? 0
                        )
                    }
                    HStack {
                        Text("Labor Subtotal").font(.subheadline.bold())
                        Spacer()
                        Text(pricing.laborSubtotal, format: .currency(code: "USD")).font(.subheadline.bold())
                    }
                }
            }

            if !ticket.equipmentItems.isEmpty {
                Section("Equipment") {
                    ForEach(ticket.equipmentItems) { item in
                        LineItemSummaryRow(
                            title: item.customDescription.isEmpty ? "Equipment item" : item.customDescription,
                            detail: "\(item.quantity)x \u{2022} \(item.hoursOperated) op + \(item.hoursStandby) standby hrs",
                            missingRate: item.linkedRate == nil,
                            cost: pricing.equipmentLineCosts[item.id] ?? 0
                        )
                    }
                    HStack {
                        Text("Equipment Subtotal").font(.subheadline.bold())
                        Spacer()
                        Text(pricing.equipmentSubtotal, format: .currency(code: "USD")).font(.subheadline.bold())
                    }
                }
            }

            Section {
                HStack {
                    Text("Materials").font(.headline)
                    Spacer()
                    Button {
                        showingNewMaterial = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .fieldTapTarget()
                }
                if ticket.materialItems.isEmpty {
                    Text("No materials added.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ticket.materialItems) { item in
                        LineItemSummaryRow(
                            title: item.customDescription.isEmpty ? "Material item" : item.customDescription,
                            detail: "Qty \(item.quantity)",
                            missingRate: item.linkedRate == nil,
                            cost: pricing.materialLineCosts[item.id] ?? 0
                        )
                    }
                    .onDelete(perform: deleteMaterialItems)
                    HStack {
                        Text("Material Subtotal").font(.subheadline.bold())
                        Spacer()
                        Text(pricing.materialSubtotal, format: .currency(code: "USD")).font(.subheadline.bold())
                    }
                }
            }

            Section {
                HStack {
                    Text("Grand Total").font(.title3.bold())
                    Spacer()
                    Text(pricing.grandTotal, format: .currency(code: "USD")).font(.title3.bold())
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button("Back", action: onBack)
                    .buttonStyle(.bordered)
                    .fieldTapTarget()
                Button {
                    PricingCalculator.applyPricing(to: ticket)
                    try? modelContext.save()
                    onNext()
                } label: {
                    Text("Next: Signature")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .fieldTapTarget()
            }
            .padding()
            .background(.bar)
        }
        .sheet(isPresented: $showingNewMaterial) {
            NavigationStack {
                MaterialItemEditSheet(ticket: ticket, project: project, item: nil)
            }
        }
        .onAppear {
            PricingCalculator.applyPricing(to: ticket)
            try? modelContext.save()
        }
    }

    private func deleteMaterialItems(at offsets: IndexSet) {
        for index in offsets {
            let item = ticket.materialItems[index]
            modelContext.delete(item)
        }
        ticket.materialItems.remove(atOffsets: offsets)
        try? modelContext.save()
    }
}

private struct LineItemSummaryRow: View {
    let title: String
    let detail: String
    let missingRate: Bool
    let cost: Decimal

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                Text(detail).font(.caption).foregroundStyle(.secondary)
                if missingRate {
                    Text("No rate linked \u{2014} cost is $0 until a rate is selected")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            Text(cost, format: .currency(code: "USD"))
                .font(.subheadline.bold())
        }
        .padding(.vertical, 2)
    }
}

private struct MaterialItemEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var ticket: FieldTicket
    let project: Project
    let item: TicketMaterialItem?

    @State private var description: String = ""
    @State private var quantity: Decimal = 1
    @State private var selectedRate: ProjectRate?

    private var materialRates: [ProjectRate] {
        project.rates.filter { $0.itemType == .material && !$0.isArchived }
    }

    var body: some View {
        Form {
            TextField("Description", text: $description)
            Picker("Rate", selection: $selectedRate) {
                Text("No rate linked").tag(ProjectRate?.none)
                ForEach(materialRates) { rate in
                    Text("\(rate.resourceTitle) (\(rate.standardRate, format: .currency(code: "USD"))/\(rate.unitOfMeasure))")
                        .tag(ProjectRate?.some(rate))
                }
            }
            TextField("Quantity", value: $quantity, format: .number)
                .keyboardType(.decimalPad)
        }
        .navigationTitle("Material Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if let item {
                description = item.customDescription
                quantity = item.quantity
                selectedRate = item.linkedRate
            }
        }
    }

    private func save() {
        if let item {
            item.customDescription = description
            item.quantity = quantity
            item.linkedRate = selectedRate
            item.isParserSuggested = false
        } else {
            let newItem = TicketMaterialItem(customDescription: description, quantity: quantity, linkedRate: selectedRate)
            newItem.ticket = ticket
            modelContext.insert(newItem)
            ticket.materialItems.append(newItem)
        }
        PricingCalculator.applyPricing(to: ticket)
        try? modelContext.save()
        dismiss()
    }
}
