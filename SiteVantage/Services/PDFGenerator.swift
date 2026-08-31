//
//  PDFGenerator.swift
//  SiteVantage
//
//  Renders a clean T&M ticket PDF via UIGraphicsPDFRenderer: header, scope,
//  labor/equipment/materials table, subtotal breakdown, signature or
//  decline block, and evidence photo thumbnails with their location-source/
//  confidence and device-reported timestamp labels printed alongside (not
//  hidden), per spec §4 screen 7. This is the only export path in this
//  build — there is no server upload.
//

import Foundation
import UIKit
import PDFKit

enum PDFGenerator {
    private static let pageWidth: CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat = 36

    static func generate(ticket: FieldTicket, project: Project) -> Data {
        let pageBounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        let currencyFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            return formatter
        }()

        let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter
        }()

        return renderer.pdfData { context in
            var cursor = PDFCursor(context: context, pageBounds: pageBounds, margin: margin)
            cursor.beginPage()

            // Header
            cursor.drawText("SiteVantage \u{2014} Field T&M Ticket", font: .boldSystemFont(ofSize: 18))
            cursor.advance(6)
            cursor.drawText(ticket.ticketSerial, font: .boldSystemFont(ofSize: 14))
            cursor.drawText("Created: \(dateFormatter.string(from: ticket.createdAt))", font: .systemFont(ofSize: 10), color: .darkGray)
            cursor.drawText("Project: \(project.name) (\(project.projectCode))", font: .systemFont(ofSize: 11))
            cursor.drawText("GC: \(project.gcCompanyName)", font: .systemFont(ofSize: 11))
            if let drawingRef = ticket.drawingReference, !drawingRef.isEmpty {
                cursor.drawText("Drawing Reference: \(drawingRef)", font: .systemFont(ofSize: 10), color: .darkGray)
            }
            cursor.drawStatusBadge(ticket.status.displayName)
            cursor.advance(10)
            cursor.drawDivider()

            // Scope
            cursor.drawText("Scope of Work", font: .boldSystemFont(ofSize: 13))
            cursor.drawWrappedText(ticket.scopeDescription.isEmpty ? "(no scope description)" : ticket.scopeDescription, font: .systemFont(ofSize: 10))
            cursor.advance(8)
            cursor.drawDivider()

            // Line items table
            cursor.drawText("Labor / Equipment / Materials", font: .boldSystemFont(ofSize: 13))
            cursor.advance(4)

            if !ticket.laborItems.isEmpty {
                cursor.drawText("Labor", font: .boldSystemFont(ofSize: 11))
                for item in ticket.laborItems {
                    let desc = item.customDescription.isEmpty ? "Labor" : item.customDescription
                    let line = "\(desc) \u{2014} \(item.headcount)x, \(item.standardHours) std + \(item.overtimeHours) OT hrs"
                    cursor.drawLineItemRow(line, currencyFormatter.string(from: item.calculatedCost as NSDecimalNumber) ?? "-")
                }
            }
            if !ticket.equipmentItems.isEmpty {
                cursor.drawText("Equipment", font: .boldSystemFont(ofSize: 11))
                for item in ticket.equipmentItems {
                    let desc = item.customDescription.isEmpty ? "Equipment" : item.customDescription
                    let line = "\(desc) \u{2014} \(item.quantity)x, \(item.hoursOperated) op + \(item.hoursStandby) standby hrs"
                    cursor.drawLineItemRow(line, currencyFormatter.string(from: item.calculatedCost as NSDecimalNumber) ?? "-")
                }
            }
            if !ticket.materialItems.isEmpty {
                cursor.drawText("Materials", font: .boldSystemFont(ofSize: 11))
                for item in ticket.materialItems {
                    let desc = item.customDescription.isEmpty ? "Material" : item.customDescription
                    let line = "\(desc) \u{2014} Qty \(item.quantity)"
                    cursor.drawLineItemRow(line, currencyFormatter.string(from: item.calculatedCost as NSDecimalNumber) ?? "-")
                }
            }

            cursor.advance(6)
            cursor.drawDivider()
            cursor.drawTotalsRow("Labor Subtotal", currencyFormatter.string(from: ticket.laborSubtotal as NSDecimalNumber) ?? "-")
            cursor.drawTotalsRow("Equipment Subtotal", currencyFormatter.string(from: ticket.equipmentSubtotal as NSDecimalNumber) ?? "-")
            cursor.drawTotalsRow("Material Subtotal", currencyFormatter.string(from: ticket.materialSubtotal as NSDecimalNumber) ?? "-")
            cursor.drawTotalsRow("GRAND TOTAL", currencyFormatter.string(from: ticket.grandTotal as NSDecimalNumber) ?? "-", bold: true)
            cursor.advance(10)
            cursor.drawDivider()

            // Signature / decline block
            cursor.drawText("Approval", font: .boldSystemFont(ofSize: 13))
            switch ticket.status {
            case .signedOnSite:
                if let signatureData = ticket.signatureImageData, let signatureImage = UIImage(data: signatureData) {
                    cursor.drawImage(signatureImage, maxWidth: 220, maxHeight: 90)
                }
                cursor.drawText("Signed by: \(ticket.signedByName ?? "\u{2014}") \(ticket.signedByTitle.map { "(\($0))" } ?? "")", font: .systemFont(ofSize: 10))
                if let signedAt = ticket.deviceReportedSignedAt {
                    cursor.drawText("Device-reported signed at: \(dateFormatter.string(from: signedAt)) (unverified, device clock only)", font: .systemFont(ofSize: 9), color: .darkGray)
                }
            case .declinedSignature:
                cursor.drawText("Signature declined by: \(ticket.signedByName ?? "\u{2014}")", font: .systemFont(ofSize: 10))
                cursor.drawText("Reason: \(ticket.unsignedReasonDetail ?? ticket.unsignedReasonCode ?? "\u{2014}")", font: .systemFont(ofSize: 10))
                cursor.drawWrappedText("DRAFT NOTICE \u{2014} NOT SENT. This notice draft is for internal PM/counsel review only.", font: .boldSystemFont(ofSize: 9), color: .systemOrange)
            case .draft:
                cursor.drawText("Not yet signed.", font: .systemFont(ofSize: 10), color: .darkGray)
            case .rejected:
                cursor.drawText("Rejected.", font: .systemFont(ofSize: 10), color: .darkGray)
            }
            cursor.advance(10)
            cursor.drawDivider()

            // Evidence photos
            cursor.drawText("Evidence Photos", font: .boldSystemFont(ofSize: 13))
            cursor.advance(4)
            if ticket.evidencePhotos.isEmpty {
                cursor.drawText("(none captured)", font: .systemFont(ofSize: 10), color: .darkGray)
            } else {
                for photo in ticket.evidencePhotos.sorted(by: { $0.deviceCapturedAt < $1.deviceCapturedAt }) {
                    if let url = photo.resolvedFileURL, let image = UIImage(contentsOfFile: url.path) {
                        cursor.drawEvidencePhoto(
                            image: image,
                            caption: photoCaption(photo, dateFormatter: dateFormatter)
                        )
                    }
                }
            }

            cursor.advance(14)
            cursor.drawDivider()
            cursor.drawWrappedText(
                "This is a single-device field capture record. All timestamps are device-reported and unverified \u{2014} there is no server-side receipt time in this build. Evidence photo hashes (SHA-256) are recorded in-app as a tamper-evidence anchor but are not independently notarized.",
                font: .systemFont(ofSize: 8),
                color: .darkGray
            )
        }
    }

    private static func photoCaption(_ photo: TicketEvidencePhoto, dateFormatter: DateFormatter) -> String {
        var parts: [String] = [photo.photoType.displayName]
        if let lat = photo.latitude, let lon = photo.longitude {
            parts.append(String(format: "%.5f, %.5f (%@/%@)", lat, lon, photo.locationSource.displayName, photo.locationConfidence.displayName))
        } else {
            parts.append("Manual pin (\(photo.locationConfidence.displayName))")
        }
        parts.append("\(dateFormatter.string(from: photo.deviceCapturedAt)) (device-reported)")
        return parts.joined(separator: " \u{2022} ")
    }
}

/// Small stateful helper that tracks the current draw position and starts
/// new PDF pages automatically when content would overflow.
private struct PDFCursor {
    let context: UIGraphicsPDFRendererContext
    let pageBounds: CGRect
    let margin: CGFloat
    var y: CGFloat = 0

    init(context: UIGraphicsPDFRendererContext, pageBounds: CGRect, margin: CGFloat) {
        self.context = context
        self.pageBounds = pageBounds
        self.margin = margin
        self.y = margin
    }

    var contentWidth: CGFloat { pageBounds.width - margin * 2 }

    mutating func beginPage() {
        context.beginPage()
        y = margin
    }

    mutating func ensureSpace(_ height: CGFloat) {
        if y + height > pageBounds.height - margin {
            beginPage()
        }
    }

    mutating func advance(_ height: CGFloat) {
        y += height
    }

    mutating func drawDivider() {
        ensureSpace(10)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: pageBounds.width - margin, y: y))
        UIColor.lightGray.setStroke()
        path.lineWidth = 0.5
        path.stroke()
        y += 10
    }

    mutating func drawText(_ text: String, font: UIFont, color: UIColor = .black) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attributes)
        ensureSpace(size.height + 4)
        (text as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attributes)
        y += size.height + 4
    }

    mutating func drawStatusBadge(_ text: String) {
        drawText("Status: \(text)", font: .boldSystemFont(ofSize: 10), color: .black)
    }

    mutating func drawWrappedText(_ text: String, font: UIFont, color: UIColor = .black) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let boundingRect = (text as NSString).boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attributes,
            context: nil
        )
        ensureSpace(boundingRect.height + 4)
        let drawRect = CGRect(x: margin, y: y, width: contentWidth, height: boundingRect.height)
        (text as NSString).draw(in: drawRect, withAttributes: attributes)
        y += boundingRect.height + 4
    }

    mutating func drawLineItemRow(_ description: String, _ cost: String) {
        ensureSpace(16)
        let descAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.black]
        let costAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 9), .foregroundColor: UIColor.black]
        let descWidth = contentWidth - 80
        let boundingRect = (description as NSString).boundingRect(
            with: CGSize(width: descWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: descAttributes,
            context: nil
        )
        (description as NSString).draw(in: CGRect(x: margin, y: y, width: descWidth, height: boundingRect.height), withAttributes: descAttributes)
        let costSize = (cost as NSString).size(withAttributes: costAttributes)
        (cost as NSString).draw(at: CGPoint(x: pageBounds.width - margin - costSize.width, y: y), withAttributes: costAttributes)
        y += max(boundingRect.height, costSize.height) + 3
    }

    mutating func drawTotalsRow(_ label: String, _ value: String, bold: Bool = false) {
        ensureSpace(16)
        let font: UIFont = bold ? .boldSystemFont(ofSize: 12) : .systemFont(ofSize: 10)
        let labelAttributes: [NSAttributedString.Key: Any] = [.font: font]
        let valueAttributes: [NSAttributedString.Key: Any] = [.font: font]
        (label as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttributes)
        let valueSize = (value as NSString).size(withAttributes: valueAttributes)
        (value as NSString).draw(at: CGPoint(x: pageBounds.width - margin - valueSize.width, y: y), withAttributes: valueAttributes)
        y += valueSize.height + 4
    }

    mutating func drawImage(_ image: UIImage, maxWidth: CGFloat, maxHeight: CGFloat) {
        let aspect = image.size.width / max(image.size.height, 1)
        var drawSize = CGSize(width: maxWidth, height: maxWidth / aspect)
        if drawSize.height > maxHeight {
            drawSize = CGSize(width: maxHeight * aspect, height: maxHeight)
        }
        ensureSpace(drawSize.height + 6)
        image.draw(in: CGRect(x: margin, y: y, width: drawSize.width, height: drawSize.height))
        y += drawSize.height + 6
    }

    mutating func drawEvidencePhoto(image: UIImage, caption: String) {
        let thumbSize: CGFloat = 90
        let captionAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.darkGray]
        let captionWidth = contentWidth - thumbSize - 10
        let boundingRect = (caption as NSString).boundingRect(
            with: CGSize(width: captionWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: captionAttributes,
            context: nil
        )
        let rowHeight = max(thumbSize, boundingRect.height)
        ensureSpace(rowHeight + 8)

        let aspect = image.size.width / max(image.size.height, 1)
        var drawSize = CGSize(width: thumbSize, height: thumbSize / aspect)
        if drawSize.height > thumbSize {
            drawSize = CGSize(width: thumbSize * aspect, height: thumbSize)
        }
        image.draw(in: CGRect(x: margin, y: y, width: drawSize.width, height: drawSize.height))

        let captionRect = CGRect(x: margin + thumbSize + 10, y: y, width: captionWidth, height: boundingRect.height)
        (caption as NSString).draw(in: captionRect, withAttributes: captionAttributes)

        y += rowHeight + 8
    }
}
