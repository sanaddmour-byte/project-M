//
//  EvidenceCaptureStepView.swift
//  SiteVantage
//
//  Forces the native camera only (CameraCaptureView, no gallery picker),
//  requires at least one CONTEXT_WIDE and one DEFECT_MACRO photo before
//  advancing, and on every capture: reads location, classifies confidence,
//  falls back to a manual pin on timeout, then burns metadata into the
//  image raster and hashes the result. Spec §4 screen 4.
//

import SwiftUI
import UIKit
import AVFoundation

struct EvidenceCaptureStepView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var ticket: FieldTicket
    let onBack: () -> Void
    let onNext: () -> Void

    @StateObject private var locationService = LocationCaptureService()

    @State private var showingCamera = false
    @State private var showingManualPin = false
    @State private var pendingPhotoType: EvidencePhotoType = .contextWide
    @State private var pendingImage: UIImage?
    @State private var isProcessing = false
    @State private var cameraPermissionDenied = false
    @State private var statusMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    RequirementRow(
                        title: "Context (Wide) Photo",
                        detail: "Shows the work area in context. Required.",
                        satisfied: ticket.evidencePhotos.contains { $0.photoType == .contextWide }
                    )
                    RequirementRow(
                        title: "Defect (Macro) Photo",
                        detail: "Close-up of the specific condition/extra work. Required.",
                        satisfied: ticket.evidencePhotos.contains { $0.photoType == .defectMacro }
                    )

                    VStack(spacing: 12) {
                        ForEach(EvidencePhotoType.allCases) { type in
                            Button {
                                startCapture(for: type)
                            } label: {
                                HStack {
                                    Image(systemName: "camera.fill")
                                    Text("Capture \(type.displayName) Photo")
                                    Spacer()
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .fieldTapTarget()
                            .disabled(isProcessing)
                        }
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if cameraPermissionDenied {
                        PermissionDeniedView(
                            iconName: "camera.fill",
                            title: "Camera Access Needed",
                            message: "SiteVantage only captures evidence photos with the live camera \u{2014} there is no gallery import. Enable Camera access in Settings to continue."
                        )
                    }

                    if !ticket.evidencePhotos.isEmpty {
                        Text("Captured Photos")
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                            ForEach(ticket.evidencePhotos.sorted(by: { $0.deviceCapturedAt < $1.deviceCapturedAt })) { photo in
                                EvidenceThumbnail(photo: photo) {
                                    deletePhoto(photo)
                                }
                            }
                        }
                    }
                }
                .padding()
            }

            HStack(spacing: 12) {
                Button("Back", action: onBack)
                    .buttonStyle(.bordered)
                    .fieldTapTarget()
                Button {
                    onNext()
                } label: {
                    Text("Next: Pricing")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .fieldTapTarget()
                .disabled(!ticket.hasMinimumRequiredEvidence)
            }
            .padding()
            .background(.bar)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                CameraCaptureView(
                    onCapture: { image in
                        showingCamera = false
                        pendingImage = image
                        Task { await processCapturedImage() }
                    },
                    onCancel: {
                        showingCamera = false
                        pendingImage = nil
                    }
                )
                .ignoresSafeArea()
            } else {
                CameraUnavailableView()
            }
        }
        .sheet(isPresented: $showingManualPin) {
            ManualPinView(
                locationPermissionDenied: locationService.authorizationDenied,
                onConfirm: {
                    showingManualPin = false
                    Task {
                        await finalizeCapture(result: LocationCaptureResult(
                            latitude: nil, longitude: nil, source: .manualPin, confidence: .declared
                        ))
                    }
                },
                onCancel: {
                    showingManualPin = false
                    pendingImage = nil
                    isProcessing = false
                }
            )
        }
    }

    private func startCapture(for type: EvidencePhotoType) {
        pendingPhotoType = type
        statusMessage = nil
        Task {
            let granted = await requestCameraAccess()
            if granted {
                cameraPermissionDenied = false
                showingCamera = true
            } else {
                cameraPermissionDenied = true
            }
        }
    }

    private func requestCameraAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func processCapturedImage() async {
        guard pendingImage != nil else { return }
        isProcessing = true
        statusMessage = "Getting location\u{2026}"

        _ = await locationService.requestAuthorization()
        let result = await locationService.captureLocation()

        if result.confidence == .declared {
            statusMessage = nil
            isProcessing = false
            showingManualPin = true
            return
        }

        await finalizeCapture(result: result)
    }

    private func finalizeCapture(result: LocationCaptureResult) async {
        guard let image = pendingImage else { return }
        isProcessing = true
        statusMessage = "Saving evidence photo\u{2026}"

        let heading = await locationService.captureHeading()
        let capturedAt = Date()

        do {
            let burnResult = try PhotoMetadataBurner.burnAndSave(
                image: image,
                ticketSerial: ticket.ticketSerial,
                capturedAt: capturedAt,
                latitude: result.latitude,
                longitude: result.longitude,
                locationSource: result.source,
                compassBearing: heading
            )

            let photo = TicketEvidencePhoto(
                localFilePath: burnResult.relativePath,
                fileHashSHA256: burnResult.sha256Hash,
                deviceCapturedAt: capturedAt,
                latitude: result.latitude,
                longitude: result.longitude,
                locationSource: result.source,
                locationConfidence: result.confidence,
                compassBearing: heading,
                photoType: pendingPhotoType
            )
            photo.ticket = ticket
            modelContext.insert(photo)
            ticket.evidencePhotos.append(photo)

            // First photo also seeds the ticket-level location fields shown
            // in the header/PDF.
            if ticket.evidencePhotos.count == 1 || ticket.geoLatitude == nil {
                ticket.locationSource = result.source
                ticket.locationConfidence = result.confidence
                ticket.geoLatitude = result.latitude
                ticket.geoLongitude = result.longitude
            }

            try? modelContext.save()
            statusMessage = nil
        } catch {
            statusMessage = "Could not save photo: \(error.localizedDescription)"
        }

        pendingImage = nil
        isProcessing = false
    }

    private func deletePhoto(_ photo: TicketEvidencePhoto) {
        if let url = photo.resolvedFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        ticket.evidencePhotos.removeAll { $0.id == photo.id }
        modelContext.delete(photo)
        try? modelContext.save()
    }
}

private struct RequirementRow: View {
    let title: String
    let detail: String
    let satisfied: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: satisfied ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(satisfied ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct EvidenceThumbnail: View {
    let photo: TicketEvidencePhoto
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            if let url = photo.resolvedFileURL, let uiImage = UIImage(contentsOfFile: url.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 100)
            }
            Text(photo.photoType.displayName)
                .font(.caption2)
                .lineLimit(1)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .fieldTapTarget()
        }
    }
}
