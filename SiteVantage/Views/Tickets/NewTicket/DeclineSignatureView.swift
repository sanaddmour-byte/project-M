//
//  DeclineSignatureView.swift
//  SiteVantage
//
//  Path B: representative refused signature. Captures GC rep name + reason,
//  sets status DECLINED_SIGNATURE, and generates a draft-only notice.
//  Never sends anything — the banner below is not decoration, it is the
//  entire send-safety model for this build (spec §4 screen 6 Path B).
//

import SwiftUI

struct DeclineSignatureView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var ticket: FieldTicket
    let project: Project
    let onBack: () -> Void
    let onFinished: () -> Void

    @State private var repName: String = ""
    @State private var reasonCode: DeclineReasonCode = .notAuthorized
    @State private var reasonDetail: String = ""
    @State private var errorMessage: String?
    @State private var draftGenerated = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !draftGenerated {
                    TextField("GC Representative Name", text: $repName)
                        .textFieldStyle(.roundedBorder)

                    Picker("Reason", selection: $reasonCode) {
                        ForEach(DeclineReasonCode.allCases) { reason in
                            Text(reason.displayName).tag(reason)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Text("Additional Detail")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $reasonDetail)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    if let errorMessage {
                        Text(errorMessage).font(.caption).foregroundStyle(.red)
                    }

                    HStack(spacing: 12) {
                        Button("Back", action: onBack)
                            .buttonStyle(.bordered)
                            .fieldTapTarget()
                        Button {
                            confirmDecline()
                        } label: {
                            Text("Record Decline & Draft Notice")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .fieldTapTarget()
                    }
                } else {
                    DraftBanner()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Draft Notice (not sent)")
                            .font(.headline)
                        Text(ticket.noticeDraftText ?? "")
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button {
                        onFinished()
                    } label: {
                        Text("Done")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .fieldTapTarget()
                }
            }
            .padding()
        }
    }

    private func confirmDecline() {
        guard !repName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Enter the GC representative's name."
            return
        }

        ticket.status = .declinedSignature
        ticket.signedByName = repName
        ticket.unsignedReasonCode = reasonCode.rawValue
        ticket.unsignedReasonDetail = reasonDetail.isEmpty
            ? (reasonCode == .other ? nil : reasonCode.displayName)
            : reasonDetail
        ticket.deviceReportedSignedAt = nil
        ticket.updatedAt = Date()

        let declineText = reasonDetail.isEmpty ? reasonCode.displayName : "\(reasonCode.displayName) \u{2014} \(reasonDetail)"
        ticket.noticeDraftText = NoticeDraftGenerator.generate(
            ticket: ticket,
            project: project,
            declineReasonText: declineText
        )
        ticket.noticeDraftStatus = .drafted

        try? modelContext.save()
        draftGenerated = true
    }
}

private struct DraftBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("This is a draft. It has not been sent.")
                    .font(.subheadline.bold())
                Text("Configure this project's actual contract clause in Project Settings, and have your PM/counsel review before sending this by whatever channel your contract requires. SiteVantage has no send capability \u{2014} email/SMS/portal delivery is not implemented in this build.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
