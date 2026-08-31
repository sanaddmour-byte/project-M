//
//  ScopeReviewStepView.swift
//  SiteVantage
//
//  Editable scope description plus labor/equipment line items pre-filled
//  from the on-device transcript via FieldItemParser where confidently
//  parsed. Every field remains manually editable/deletable — parsing is a
//  suggestion, never authoritative (spec §4 screen 3, §5).
//

import SwiftUI
import SwiftData

struct ScopeReviewStepView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var ticket: FieldTicket
    let project: Project
    let onBack: () -> Void
    let onNext: () -> Void

    @State private var hasAppliedParser = false

    var body: some View {
        Form {
            Section("Scope Description") {
                TextEditor(text: Binding(
                    get: { ticket.scopeDescription },
                    set: { ticket.scopeDescription = $0 }
                ))
                .frame(minHeight: 100)
            }

            Section {
                HStack {
                    Text("Labor")
                        .font(.headline)
                    Spacer()
                    Button {
                        addLaborItem()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .fieldTapTarget()
                }
                if ticket.laborItems.isEmpty {
                    Text("No labor line items. Add one manually or dictate headcount/hours on the previous step.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ticket.laborItems) { item in
                        LaborItemEditor(item: item, project: project) {
                            deleteLaborItem(item)
                        }
                    }
                }
            }

            Section {
                HStack {
                    Text("Equipment")
                        .font(.headline)
                    Spacer()
                    Button {
                        addEquipmentItem()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .fieldTapTarget()
                }
                if ticket.equipmentItems.isEmpty {
                    Text("No equipment line items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ticket.equipmentItems) { item in
                        EquipmentItemEditor(item: item, project: project) {
                            deleteEquipmentItem(item)
                        }
                    }
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
                    persistAndAdvance()
                } label: {
                    Text("Next: Evidence")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .fieldTapTarget()
                .disabled(ticket.scopeDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(.bar)
        }
        .onAppear {
            applyParserSuggestionsIfNeeded()
        }
    }

    private func applyParserSuggestionsIfNeeded() {
        guard !hasAppliedParser else { return }
        hasAppliedParser = true

        if ticket.scopeDescription.isEmpty, let raw = ticket.voiceRawText {
            ticket.scopeDescription = raw
        }

        guard ticket.laborItems.isEmpty, ticket.equipmentItems.isEmpty,
              let rawText = ticket.voiceRawText, !rawText.isEmpty else { return }

        let suggestions = FieldItemParser.parse(rawText)

        for suggestion in suggestions.laborItems {
            let matchedRate = bestLaborRateMatch(for: suggestion.description)
            let item = TicketLaborItem(
                customDescription: suggestion.description,
                headcount: suggestion.headcount,
                standardHours: suggestion.hours,
                linkedRate: matchedRate,
                isParserSuggested: true
            )
            item.ticket = ticket
            modelContext.insert(item)
            ticket.laborItems.append(item)
        }

        for suggestion in suggestions.equipmentItems {
            let matchedRate = bestEquipmentRateMatch(for: suggestion.description)
            let item = TicketEquipmentItem(
                customDescription: suggestion.description,
                quantity: 1,
                hoursOperated: suggestion.hoursOperated,
                linkedRate: matchedRate,
                isParserSuggested: true
            )
            item.ticket = ticket
            modelContext.insert(item)
            ticket.equipmentItems.append(item)
        }

        try? modelContext.save()
    }

    private func bestLaborRateMatch(for description: String) -> ProjectRate? {
        project.rates.first {
            $0.itemType == .labor && !$0.isArchived &&
            $0.resourceTitle.localizedCaseInsensitiveContains(description)
        }
    }

    private func bestEquipmentRateMatch(for description: String) -> ProjectRate? {
        project.rates.first {
            $0.itemType == .equipment && !$0.isArchived &&
            $0.resourceTitle.localizedCaseInsensitiveContains(description)
        }
    }

    private func addLaborItem() {
        let item = TicketLaborItem(customDescription: "", headcount: 1, standardHours: 0)
        item.ticket = ticket
        modelContext.insert(item)
        ticket.laborItems.append(item)
        try? modelContext.save()
    }

    private func addEquipmentItem() {
        let item = TicketEquipmentItem(customDescription: "", quantity: 1, hoursOperated: 0)
        item.ticket = ticket
        modelContext.insert(item)
        ticket.equipmentItems.append(item)
        try? modelContext.save()
    }

    private func deleteLaborItem(_ item: TicketLaborItem) {
        ticket.laborItems.removeAll { $0.id == item.id }
        modelContext.delete(item)
        try? modelContext.save()
    }

    private func deleteEquipmentItem(_ item: TicketEquipmentItem) {
        ticket.equipmentItems.removeAll { $0.id == item.id }
        modelContext.delete(item)
        try? modelContext.save()
    }

    private func persistAndAdvance() {
        try? modelContext.save()
        onNext()
    }
}

private struct LaborItemEditor: View {
    @Bindable var item: TicketLaborItem
    let project: Project
    let onDelete: () -> Void

    private var laborRates: [ProjectRate] {
        project.rates.filter { $0.itemType == .labor && !$0.isArchived }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Description (e.g. Electrician)", text: $item.customDescription)
                if item.isParserSuggested {
                    Text("SUGGESTED")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(Color.blue)
                        .clipShape(Capsule())
                }
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .fieldTapTarget()
            }

            Picker("Rate", selection: $item.linkedRate) {
                Text("No rate linked").tag(ProjectRate?.none)
                ForEach(laborRates) { rate in
                    Text(rate.resourceTitle).tag(ProjectRate?.some(rate))
                }
            }
            .font(.subheadline)

            HStack {
                Stepper("Headcount: \(item.headcount)", value: $item.headcount, in: 1...200)
                    .onChange(of: item.headcount) { item.isParserSuggested = false }
            }

            HStack {
                LabeledDecimalField(label: "Std Hrs", value: $item.standardHours)
                LabeledDecimalField(label: "OT Hrs", value: $item.overtimeHours)
            }
        }
        .padding(.vertical, 6)
        .onChange(of: item.customDescription) { item.isParserSuggested = false }
    }
}

private struct EquipmentItemEditor: View {
    @Bindable var item: TicketEquipmentItem
    let project: Project
    let onDelete: () -> Void

    private var equipmentRates: [ProjectRate] {
        project.rates.filter { $0.itemType == .equipment && !$0.isArchived }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Description (e.g. Scissor Lift)", text: $item.customDescription)
                if item.isParserSuggested {
                    Text("SUGGESTED")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(Color.blue)
                        .clipShape(Capsule())
                }
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .fieldTapTarget()
            }

            Picker("Rate", selection: $item.linkedRate) {
                Text("No rate linked").tag(ProjectRate?.none)
                ForEach(equipmentRates) { rate in
                    Text(rate.resourceTitle).tag(ProjectRate?.some(rate))
                }
            }
            .font(.subheadline)

            Stepper("Quantity: \(item.quantity)", value: $item.quantity, in: 1...100)

            HStack {
                LabeledDecimalField(label: "Hrs Operated", value: $item.hoursOperated)
                LabeledDecimalField(label: "Hrs Standby", value: $item.hoursStandby)
            }
        }
        .padding(.vertical, 6)
        .onChange(of: item.customDescription) { item.isParserSuggested = false }
    }
}

struct LabeledDecimalField: View {
    let label: String
    @Binding var value: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextField(label, value: $value, format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
        }
    }
}
