//
//  SignatureStepView.swift
//  SiteVantage
//
//  Two clearly separate paths, never an ambiguous single flow, per spec §4
//  screen 6: Path A signs on-glass and sets SIGNED_ON_SITE; Path B records
//  a refusal and sets DECLINED_SIGNATURE plus a draft-only notice. Neither
//  path can be reached accidentally from the other.
//

import SwiftUI
import UIKit

private enum SignaturePath {
    case chooser
    case signOnGlass
    case declined
}

struct SignatureStepView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var ticket: FieldTicket
    let project: Project
    let settings: AppSettings
    let onBack: () -> Void
    let onFinished: () -> Void

    @State private var path: SignaturePath = .chooser

    var body: some View {
        switch path {
        case .chooser:
            ChooserView(
                onBack: onBack,
                onSelectSignOnGlass: { path = .signOnGlass },
                onSelectDeclined: { path = .declined }
            )
        case .signOnGlass:
            SignOnGlassView(
                ticket: ticket,
                project: project,
                onBack: { path = .chooser },
                onFinished: {
                    try? modelContext.save()
                    onFinished()
                }
            )
        case .declined:
            DeclineSignatureView(
                ticket: ticket,
                project: project,
                onBack: { path = .chooser },
                onFinished: {
                    try? modelContext.save()
                    onFinished()
                }
            )
        }
    }
}

private struct ChooserView: View {
    let onBack: () -> Void
    let onSelectSignOnGlass: () -> Void
    let onSelectDeclined: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("How was this ticket resolved on site?")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                onSelectSignOnGlass()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "signature")
                        .font(.system(size: 28))
                    Text("Sign On-Glass")
                        .font(.headline)
                    Text("GC representative signs now to approve this ticket")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundStyle(.white)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .fieldTapTarget()
            .padding(.horizontal)

            Button {
                onSelectDeclined()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "xmark.octagon")
                        .font(.system(size: 28))
                    Text("Representative Refused Signature")
                        .font(.headline)
                    Text("Record the refusal and draft a notice \u{2014} nothing is sent")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundStyle(.white)
                .background(Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .fieldTapTarget()
            .padding(.horizontal)

            Spacer()

            Button("Back", action: onBack)
                .buttonStyle(.bordered)
                .fieldTapTarget()
                .padding(.bottom)
        }
    }
}

private struct SignOnGlassView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var ticket: FieldTicket
    let project: Project
    let onBack: () -> Void
    let onFinished: () -> Void

    @State private var signerName: String = ""
    @State private var signerTitle: String = ""
    @State private var strokes: [[CGPoint]] = []
    @State private var errorMessage: String?

    private let canvasSize = CGSize(width: 340, height: 160)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(ESignDisclosure.text(for: project.jurisdiction))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                TextField("Signer Full Name", text: $signerName)
                    .textFieldStyle(.roundedBorder)
                TextField("Signer Title (e.g. GC Superintendent)", text: $signerTitle)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Signature")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SignaturePadView(strokes: $strokes, canvasSize: canvasSize)
                        .frame(width: canvasSize.width, height: canvasSize.height)
                    Button("Clear") { strokes = [] }
                        .buttonStyle(.bordered)
                        .fieldTapTarget()
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack(spacing: 12) {
                    Button("Back", action: onBack)
                        .buttonStyle(.bordered)
                        .fieldTapTarget()
                    Button {
                        confirmSignature()
                    } label: {
                        Text("Confirm & Sign")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .fieldTapTarget()
                }
            }
            .padding()
        }
    }

    @MainActor
    private func confirmSignature() {
        guard !signerName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Enter the signer's name."
            return
        }
        guard !strokes.isEmpty else {
            errorMessage = "Capture a signature before confirming."
            return
        }

        let renderer = ImageRenderer(content: SignatureCanvasContent(strokes: strokes, size: canvasSize))
        renderer.scale = UIScreen.main.scale
        guard let uiImage = renderer.uiImage, let pngData = uiImage.pngData() else {
            errorMessage = "Could not render the signature. Try again."
            return
        }

        ticket.signedByName = signerName
        ticket.signedByTitle = signerTitle.isEmpty ? nil : signerTitle
        ticket.signatureImageData = pngData
        ticket.deviceReportedSignedAt = Date()
        ticket.status = .signedOnSite
        ticket.updatedAt = Date()

        try? modelContext.save()
        onFinished()
    }
}
