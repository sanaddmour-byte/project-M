//
//  NewTicketFlowView.swift
//  SiteVantage
//
//  Owns the step state for the 6-screen new-ticket flow (spec §4, screens
//  2-6: Voice Capture, Scope Review, Evidence Capture, Pricing, Signature).
//  The FieldTicket is created and inserted into the model context the
//  instant this view appears, and every step mutates that same persisted
//  object directly (plus an explicit `context.save()` on every meaningful
//  change) so nothing is lost if the foreman is interrupted mid-flow.
//

import SwiftUI
import SwiftData

enum NewTicketStep: Int, CaseIterable {
    case voice = 0
    case scope
    case evidence
    case pricing
    case signature

    var title: String {
        switch self {
        case .voice: return "Voice Capture"
        case .scope: return "Scope Review"
        case .evidence: return "Evidence"
        case .pricing: return "Pricing"
        case .signature: return "Signature"
        }
    }
}

struct NewTicketFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var project: Project
    let settings: AppSettings

    @State private var ticket: FieldTicket
    @State private var step: NewTicketStep = .voice
    @State private var didFinish = false

    init(project: Project, settings: AppSettings) {
        self.project = project
        self.settings = settings
        let serial = TicketSerialGenerator.nextSerial(for: project)
        let newTicket = FieldTicket(ticketSerial: serial)
        newTicket.project = project
        _ticket = State(initialValue: newTicket)
    }

    var body: some View {
        VStack(spacing: 0) {
            StepProgressHeader(step: step, ticketSerial: ticket.ticketSerial)

            Group {
                switch step {
                case .voice:
                    VoiceCaptureStepView(ticket: ticket, onNext: { advance(to: .scope) })
                case .scope:
                    ScopeReviewStepView(ticket: ticket, project: project, onBack: { step = .voice }, onNext: { advance(to: .evidence) })
                case .evidence:
                    EvidenceCaptureStepView(ticket: ticket, onBack: { step = .scope }, onNext: { advance(to: .pricing) })
                case .pricing:
                    PricingStepView(ticket: ticket, project: project, onBack: { step = .evidence }, onNext: { advance(to: .signature) })
                case .signature:
                    SignatureStepView(
                        ticket: ticket,
                        project: project,
                        settings: settings,
                        onBack: { step = .pricing },
                        onFinished: { finish() }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Save & Exit") {
                    persist()
                    dismiss()
                }
            }
        }
        .onAppear {
            if ticket.modelContext == nil {
                modelContext.insert(ticket)
                persist()
            }
        }
    }

    private func advance(to next: NewTicketStep) {
        persist()
        step = next
    }

    private func finish() {
        persist()
        didFinish = true
        dismiss()
    }

    private func persist() {
        ticket.updatedAt = Date()
        try? modelContext.save()
    }
}

private struct StepProgressHeader: View {
    let step: NewTicketStep
    let ticketSerial: String

    var body: some View {
        VStack(spacing: 6) {
            Text(ticketSerial)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                ForEach(NewTicketStep.allCases, id: \.rawValue) { candidate in
                    Capsule()
                        .fill(candidate.rawValue <= step.rawValue ? Color.accentColor : Color(.systemGray4))
                        .frame(height: 4)
                }
            }
            Text("\(step.rawValue + 1) of \(NewTicketStep.allCases.count) \u{2014} \(step.title)")
                .font(.subheadline.bold())
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}
