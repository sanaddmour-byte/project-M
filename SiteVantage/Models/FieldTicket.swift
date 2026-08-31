//
//  FieldTicket.swift
//  SiteVantage
//

import Foundation
import SwiftData

@Model
final class FieldTicket {
    var id: UUID = UUID()
    var ticketSerial: String = ""
    var status: TicketStatus = TicketStatus.draft

    var drawingReference: String?
    var voiceRawText: String?

    /// This build only ever writes `.onDevice`. See VoiceTranscriptionSource.
    var voiceTranscriptionSource: VoiceTranscriptionSource = VoiceTranscriptionSource.onDevice

    var scopeDescription: String = ""

    @Relationship(deleteRule: .cascade, inverse: \TicketLaborItem.ticket)
    var laborItems: [TicketLaborItem] = []

    @Relationship(deleteRule: .cascade, inverse: \TicketEquipmentItem.ticket)
    var equipmentItems: [TicketEquipmentItem] = []

    @Relationship(deleteRule: .cascade, inverse: \TicketMaterialItem.ticket)
    var materialItems: [TicketMaterialItem] = []

    var laborSubtotal: Decimal = Decimal(0)
    var equipmentSubtotal: Decimal = Decimal(0)
    var materialSubtotal: Decimal = Decimal(0)
    var grandTotal: Decimal = Decimal(0)

    /// No BLE beacon source exists in this build.
    var locationSource: LocationSource = LocationSource.manualPin
    var locationConfidence: LocationConfidence = LocationConfidence.declared
    var geoLatitude: Double?
    var geoLongitude: Double?

    var signedByName: String?
    var signedByTitle: String?

    /// Rendered signature image (PNG), not just a stroke path, so it can be
    /// burned directly into the exported PDF without re-rendering strokes.
    var signatureImageData: Data?

    /// Device clock only — there is no server in this build to independently
    /// timestamp the event. Always labeled "device-reported" in the UI/PDF.
    var deviceReportedSignedAt: Date?

    var unsignedReasonCode: String?
    var unsignedReasonDetail: String?

    /// NONE until a decline draft is generated; DRAFTED once generated;
    /// REVIEWED_LOCALLY is a manual foreman/PM toggle available in the
    /// ticket detail screen. Never auto-advances to a "sent" state — there
    /// is no send capability in this build.
    var noticeDraftStatus: NoticeDraftStatus = NoticeDraftStatus.none
    var noticeDraftText: String?

    @Relationship(deleteRule: .cascade, inverse: \TicketEvidencePhoto.ticket)
    var evidencePhotos: [TicketEvidencePhoto] = []

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var project: Project?

    init(
        ticketSerial: String,
        scopeDescription: String = "",
        drawingReference: String? = nil
    ) {
        self.id = UUID()
        self.ticketSerial = ticketSerial
        self.status = .draft
        self.drawingReference = drawingReference
        self.voiceTranscriptionSource = .onDevice
        self.scopeDescription = scopeDescription
        self.laborSubtotal = Decimal(0)
        self.equipmentSubtotal = Decimal(0)
        self.materialSubtotal = Decimal(0)
        self.grandTotal = Decimal(0)
        self.locationSource = .manualPin
        self.locationConfidence = .declared
        self.noticeDraftStatus = .none
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var hasMinimumRequiredEvidence: Bool {
        evidencePhotos.contains { $0.photoType == .contextWide }
            && evidencePhotos.contains { $0.photoType == .defectMacro }
    }
}
