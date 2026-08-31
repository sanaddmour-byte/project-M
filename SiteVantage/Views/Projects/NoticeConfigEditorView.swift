//
//  NoticeConfigEditorView.swift
//  SiteVantage
//

import SwiftUI
import SwiftData

struct NoticeConfigEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: Project

    private var config: ProjectNoticeConfig {
        if let existing = project.noticeConfig {
            return existing
        }
        let created = ProjectNoticeConfig()
        created.project = project
        project.noticeConfig = created
        modelContext.insert(created)
        return created
    }

    var body: some View {
        Form {
            Section {
                Text("This configures the draft-only notice generated when a GC representative declines to sign a ticket. Nothing here ever sends anything automatically \u{2014} there is no send capability in this build. Configure this per-project from your actual contract before relying on drafted notices.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Contract Reference") {
                TextField("Clause Reference (e.g. \u{00A7}8.3 Changes)", text: Binding(
                    get: { config.contractClauseReference ?? "" },
                    set: { config.contractClauseReference = $0.isEmpty ? nil : $0; persist() }
                ))
                TextField("Required Recipient Role (e.g. Project Executive)", text: Binding(
                    get: { config.requiredRecipientRole ?? "" },
                    set: { config.requiredRecipientRole = $0.isEmpty ? nil : $0; persist() }
                ))
                Stepper(
                    "Required Notice Period: \(config.requiredNoticePeriodHours.map { "\($0)h" } ?? "Not set")",
                    value: Binding(
                        get: { config.requiredNoticePeriodHours ?? 0 },
                        set: { config.requiredNoticePeriodHours = $0 == 0 ? nil : $0; persist() }
                    ),
                    in: 0...240,
                    step: 4
                )
                Picker("Required Delivery Method", selection: Binding(
                    get: { config.requiredDeliveryMethod ?? "" },
                    set: { config.requiredDeliveryMethod = $0.isEmpty ? nil : $0; persist() }
                )) {
                    Text("Not set").tag("")
                    ForEach(NoticeDeliveryMethod.allCases) { method in
                        Text(method.displayName).tag(method.rawValue)
                    }
                }
            }

            Section("Notice Template") {
                TextEditor(text: Binding(
                    get: { config.templateText ?? "" },
                    set: { config.templateText = $0.isEmpty ? nil : $0; persist() }
                ))
                .frame(minHeight: 120)
                Text("Leave blank to fall back to a generic, clearly-labeled placeholder template at draft time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Review Gate") {
                Toggle("Counsel Reviewed", isOn: Binding(
                    get: { config.counselReviewed },
                    set: { newValue in
                        config.counselReviewed = newValue
                        if !newValue {
                            config.autoSendApproved = false
                        }
                        persist()
                    }
                ))
                .fieldTapTarget()

                Toggle("Auto-Send When Approved", isOn: Binding(
                    get: { config.autoSendApproved },
                    set: { newValue in
                        config.autoSendApproved = newValue
                        persist()
                    }
                ))
                .fieldTapTarget()
                .disabled(!config.counselReviewed)

                Text(autoSendCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Notice Configuration")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var autoSendCaption: String {
        if !config.counselReviewed {
            return "Locked until \u{201C}Counsel Reviewed\u{201D} is on. This project's notice clause must be reviewed before this can even be considered."
        }
        return "Forward-compatible setting only \u{2014} this build has no send capability at all. Enabling this does nothing today; it exists so a future release can honor it without a schema change."
    }

    private func persist() {
        project.updatedAt = Date()
        try? modelContext.save()
    }
}
