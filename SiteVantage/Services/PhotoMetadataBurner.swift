//
//  PhotoMetadataBurner.swift
//  SiteVantage
//
//  Burns timestamp, location (or "Manual pin"), compass heading, and the
//  ticket serial directly into the image's raster pixels via a Core
//  Graphics draw pass — EXIF alone strips too easily to serve as evidence,
//  per spec §4 screen 4. The flattened JPEG is then hashed with CryptoKit
//  (SHA-256) as the tamper-evidence anchor and written to the app's
//  Documents directory — never to the Photos library.
//

import Foundation
import UIKit
import CryptoKit

enum PhotoMetadataBurnerError: Error {
    case renderFailed
    case encodingFailed
    case writeFailed
}

struct PhotoBurnResult {
    var relativePath: String
    var sha256Hash: String
}

enum PhotoMetadataBurner {
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    static func burnAndSave(
        image: UIImage,
        ticketSerial: String,
        capturedAt: Date,
        latitude: Double?,
        longitude: Double?,
        locationSource: LocationSource,
        compassBearing: Double?
    ) throws -> PhotoBurnResult {
        let burned = try burn(
            image: image,
            ticketSerial: ticketSerial,
            capturedAt: capturedAt,
            latitude: latitude,
            longitude: longitude,
            locationSource: locationSource,
            compassBearing: compassBearing
        )

        guard let jpegData = burned.jpegData(compressionQuality: 0.85) else {
            throw PhotoMetadataBurnerError.encodingFailed
        }

        let hash = SHA256.hash(data: jpegData)
        let hashHex = hash.compactMap { String(format: "%02x", $0) }.joined()

        let directoryName = "EvidencePhotos"
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw PhotoMetadataBurnerError.writeFailed
        }
        let directoryURL = documentsURL.appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = directoryURL.appendingPathComponent(fileName)

        do {
            try jpegData.write(to: fileURL, options: .atomic)
        } catch {
            throw PhotoMetadataBurnerError.writeFailed
        }

        return PhotoBurnResult(relativePath: "\(directoryName)/\(fileName)", sha256Hash: hashHex)
    }

    private static func burn(
        image: UIImage,
        ticketSerial: String,
        capturedAt: Date,
        latitude: Double?,
        longitude: Double?,
        locationSource: LocationSource,
        compassBearing: Double?
    ) throws -> UIImage {
        let size = image.size
        let scale = image.scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let overlayLines = overlayText(
            ticketSerial: ticketSerial,
            capturedAt: capturedAt,
            latitude: latitude,
            longitude: longitude,
            locationSource: locationSource,
            compassBearing: compassBearing
        )

        let rendered = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))

            let fontSize = max(14, size.width * 0.022)
            let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
            let lineHeight = font.lineHeight + 4
            let padding: CGFloat = fontSize * 0.6
            let barHeight = lineHeight * CGFloat(overlayLines.count) + padding * 2

            let barRect = CGRect(x: 0, y: size.height - barHeight, width: size.width, height: barHeight)
            context.cgContext.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor)
            context.cgContext.fill(barRect)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]

            var y = barRect.minY + padding
            for line in overlayLines {
                let rect = CGRect(x: padding, y: y, width: size.width - padding * 2, height: lineHeight)
                (line as NSString).draw(in: rect, withAttributes: attributes)
                y += lineHeight
            }
        }

        return rendered
    }

    private static func overlayText(
        ticketSerial: String,
        capturedAt: Date,
        latitude: Double?,
        longitude: Double?,
        locationSource: LocationSource,
        compassBearing: Double?
    ) -> [String] {
        var lines: [String] = []
        lines.append("Ticket \(ticketSerial)")

        if let latitude, let longitude {
            let coordinateText = String(format: "%.6f, %.6f", latitude, longitude)
            lines.append("\(coordinateText) (\(locationSource.displayName))")
        } else {
            lines.append("Manual pin (no GPS fix)")
        }

        lines.append("\(isoFormatter.string(from: capturedAt)) UTC \u{2014} device-reported")

        if let compassBearing {
            lines.append(String(format: "Heading %.0f\u{00B0}", compassBearing))
        }

        return lines
    }
}
