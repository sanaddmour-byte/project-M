//
//  TicketEvidencePhoto.swift
//  SiteVantage
//

import Foundation
import SwiftData

@Model
final class TicketEvidencePhoto {
    var id: UUID = UUID()

    /// Relative path within the app's Documents directory (not an absolute
    /// URL, so the evidence survives an app reinstall/container path change
    /// across OS upgrades). Resolved to a full URL via
    /// `TicketEvidencePhoto.resolvedFileURL`.
    var localFilePath: String = ""

    /// SHA-256 of the final, metadata-burned JPEG, computed with CryptoKit
    /// at capture time. This is the tamper-evidence anchor: any edit to the
    /// exported file changes this hash.
    var fileHashSHA256: String = ""

    var deviceCapturedAt: Date = Date()
    var latitude: Double?
    var longitude: Double?
    var locationSource: LocationSource = LocationSource.manualPin
    var locationConfidence: LocationConfidence = LocationConfidence.declared
    var compassBearing: Double?
    var photoType: EvidencePhotoType = EvidencePhotoType.contextWide

    var ticket: FieldTicket?

    init(
        localFilePath: String,
        fileHashSHA256: String,
        deviceCapturedAt: Date = Date(),
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationSource: LocationSource,
        locationConfidence: LocationConfidence,
        compassBearing: Double? = nil,
        photoType: EvidencePhotoType
    ) {
        self.id = UUID()
        self.localFilePath = localFilePath
        self.fileHashSHA256 = fileHashSHA256
        self.deviceCapturedAt = deviceCapturedAt
        self.latitude = latitude
        self.longitude = longitude
        self.locationSource = locationSource
        self.locationConfidence = locationConfidence
        self.compassBearing = compassBearing
        self.photoType = photoType
    }

    /// Resolves the stored relative path against the current Documents
    /// directory. Documents-directory URLs are not stable across app
    /// launches (the container path can change), so we never persist an
    /// absolute URL.
    var resolvedFileURL: URL? {
        guard !localFilePath.isEmpty else { return nil }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documents?.appendingPathComponent(localFilePath)
    }
}
