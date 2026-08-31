//
//  TicketDetailView.swift
//  SiteVantage
//
//  Full ticket summary: all photos with their burned metadata visible, the
//  signature or decline reason, and the running "Approved Extra Work $"
//  counter for the project. PDF export via the standard share sheet is the
//  only export path — no server upload (spec §4 screen 7).
//

import SwiftUI
import SwiftData
import UIKit

struct TicketDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var ticket: FieldTicket

    @State private var shareURL: IdentifiableURL?
    @State private var isGeneratingPDF = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let project = ticket.project {
                    ApprovedCounter(project: project)
                }
                scopeSection
                lineItemsSection
                totalsSection
                approvalSection
                evidenceSection
                disclaimerSection
            }
            .padding()
        }
        .navigationTitle(ticket.ticketSerial)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    exportPDF()
                } label: {
                    if isGeneratingPDF {
                        ProgressView()
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .fieldTapTarget()
                .disabled(isGeneratingPDF)
            }
        }
        .sheet(item: $shareURL) { identifiable in
            ShareSheet(items: [identifiable.url])
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(ticket.ticketSerial).font(.title3.bold())
                Spacer()
                StatusBadge(status: ticket.status)
            }
            if let project = ticket.project {
                Text("\(project.name) \u{2022} \(project.gcCompanyName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("Created \(ticket.createdAt, format: .dateTime.month().day().year().hour().minute())")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Scope").font(.headline)
            Text(ticket.scopeDescription.isEmpty ? "(no scope description)" : ticket.scopeDescription)
                .font(.body)
        }
    }

    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !ticket.laborItems.isEmpty {
                Text("Labor").font(.headline)
                ForEach(ticket.laborItems) { item in
                    DetailLineRow(
                        title: item.customDescription,
                        detail: "\(item.headcount)x \u{2022} \(item.standardHours) std + \(item.overtimeHours) OT hrs",
                        cost: item.calculatedCost
                    )
                }
            }
            if !ticket.equipmentItems.isEmpty {
                Text("Equipment").font(.headline)
                ForEach(ticket.equipmentItems) { item in
                    DetailLineRow(
                        title: item.customDescription,
                        detail: "\(item.quantity)x \u{2022} \(item.hoursOperated) op + \(item.hoursStandby) standby hrs",
                        cost: item.calculatedCost
                    )
                }
            }
            if !ticket.materialItems.isEmpty {
                Text("Materials").font(.headline)
                ForEach(ticket.materialItems) { item in
                    DetailLineRow(title: item.customDescription, detail: "Qty \(item.quantity)", cost: item.calculatedCost)
                }
            }
        }
    }

    private var totalsSection: some View {
        VStack(spacing: 6) {
            TotalRow(label: "Labor Subtotal", value: ticket.laborSubtotal)
            TotalRow(label: "Equipment Subtotal", value: ticket.equipmentSubtotal)
            TotalRow(label: "Material Subtotal", value: ticket.materialSubtotal)
            Divider()
            TotalRow(label: "Grand Total", value: ticket.grandTotal, bold: true)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var approvalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Approval").font(.headline)
            switch ticket.status {
            case .signedOnSite:
                if let data = ticket.signatureImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260, maxHeight: 100)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Text("Signed by \(ticket.signedByName ?? "\u{2014}")\(ticket.signedByTitle.map { ", \($0)" } ?? "")")
                    .font(.subheadline)
                if let signedAt = ticket.deviceReportedSignedAt {
                    Text("Device-reported signed at \(signedAt, format: .dateTime.month().day().year().hour().minute()) \u{2014} unverified, device clock only")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .declinedSignature:
                Text("Signature declined by \(ticket.signedByName ?? "\u{2014}")")
                    .font(.subheadline)
                Text("Reason: \(ticket.unsignedReasonDetail ?? ticket.unsignedReasonCode ?? "\u{2014}")")
                    .font(.subheadline)
                if let noticeText = ticket.noticeDraftText {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Draft only \u{2014} not sent", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                        Text(noticeText)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            case .draft:
                Text("Not yet resolved.").font(.subheadline).foregroundStyle(.secondary)
            case .rejected:
                Text("Rejected.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Evidence Photos (\(ticket.evidencePhotos.count))").font(.headline)
            ForEach(ticket.evidencePhotos.sorted(by: { $0.deviceCapturedAt < $1.deviceCapturedAt })) { photo in
                EvidenceDetailRow(photo: photo)
            }
        }
    }

    private var disclaimerSection: some View {
        Text("This is a single-device field capture record. All timestamps are device-reported and unverified \u{2014} there is no server receipt time in this build.")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private func exportPDF() {
        // Runs on the main thread deliberately: FieldTicket/Project are
        // SwiftData models, which are not Sendable, so reading them from a
        // background queue is a real (if often-tolerated) data-race risk.
        // Generating one ticket's PDF from a handful of already-decoded
        // JPEGs is well within "local disk I/O" fast-path territory per
        // spec §6, so there's no need to hop threads for it.
        isGeneratingPDF = true
        defer { isGeneratingPDF = false }
        guard let project = ticket.project else { return }

        let data = PDFGenerator.generate(ticket: ticket, project: project)
        let fileName = "\(ticket.ticketSerial).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL, options: .atomic)
            shareURL = IdentifiableURL(url: tempURL)
        } catch {
            // Nothing more actionable to do here; the share sheet simply
            // won't open. isGeneratingPDF is already reset via `defer`.
        }
    }
}

struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct ApprovedCounter: View {
    let project: Project

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Approved Extra Work \u{2014} This Project")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(project.approvedExtraWorkTotal, format: .currency(code: "USD"))
                    .font(.title3.bold())
            }
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct DetailLineRow: View {
    let title: String
    let detail: String
    let cost: Decimal

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.isEmpty ? "Item" : title).font(.subheadline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(cost, format: .currency(code: "USD")).font(.subheadline.bold())
        }
    }
}

private struct TotalRow: View {
    let label: String
    let value: Decimal
    var bold: Bool = false

    var body: some View {
        HStack {
            Text(label).font(bold ? .headline : .subheadline)
            Spacer()
            Text(value, format: .currency(code: "USD")).font(bold ? .headline : .subheadline)
        }
    }
}

private struct EvidenceDetailRow: View {
    let photo: TicketEvidencePhoto

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let url = photo.resolvedFileURL, let uiImage = UIImage(contentsOfFile: url.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(photo.photoType.displayName).font(.subheadline.bold())
                if let lat = photo.latitude, let lon = photo.longitude {
                    Text(String(format: "%.5f, %.5f", lat, lon))
                        .font(.caption)
                } else {
                    Text("Manual pin (no GPS fix)")
                        .font(.caption)
                }
                Text("\(photo.locationSource.displayName) \u{2022} \(photo.locationConfidence.displayName) confidence")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(photo.deviceCapturedAt, format: .dateTime.month().day().year().hour().minute()) (device-reported)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("SHA-256: \(photo.fileHashSHA256.prefix(16))\u{2026}")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
