//
//  Enums.swift
//  SiteVantage
//
//  Shared enum types used across SwiftData models. Each enum is String-backed
//  and Codable so it can be stored directly as a SwiftData model property.
//

import Foundation

enum RateItemType: String, Codable, CaseIterable, Identifiable, Sendable {
    case labor = "LABOR"
    case equipment = "EQUIPMENT"
    case material = "MATERIAL"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .labor: return "Labor"
        case .equipment: return "Equipment"
        case .material: return "Material"
        }
    }
}

enum TicketStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case draft = "DRAFT"
    case signedOnSite = "SIGNED_ON_SITE"
    case declinedSignature = "DECLINED_SIGNATURE"
    case rejected = "REJECTED"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .signedOnSite: return "Signed On Site"
        case .declinedSignature: return "Signature Declined"
        case .rejected: return "Rejected"
        }
    }
}

/// This build only ever produces `.onDevice` transcriptions. `.cloudRefined`
/// is modeled now so a future v2 backend pass can be represented without a
/// schema migration, but no code path in this build ever sets it.
enum VoiceTranscriptionSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case onDevice = "ON_DEVICE"
    case cloudRefined = "CLOUD_REFINED"

    var id: String { rawValue }
}

/// No BLE beacon case exists in this build — there is no beacon
/// infrastructure to target. See DECISIONS.md.
enum LocationSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case gps = "GPS"
    case wifiCell = "WIFI_CELL"
    case manualPin = "MANUAL_PIN"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gps: return "GPS"
        case .wifiCell: return "Wi-Fi/Cell"
        case .manualPin: return "Manual Pin"
        }
    }
}

enum LocationConfidence: String, Codable, CaseIterable, Identifiable, Sendable {
    case high = "HIGH"
    case medium = "MEDIUM"
    case declared = "DECLARED"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .declared: return "Declared"
        }
    }
}

enum NoticeDraftStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case none = "NONE"
    case drafted = "DRAFTED"
    case reviewedLocally = "REVIEWED_LOCALLY"

    var id: String { rawValue }
}

enum EvidencePhotoType: String, Codable, CaseIterable, Identifiable, Sendable {
    case contextWide = "CONTEXT_WIDE"
    case defectMacro = "DEFECT_MACRO"
    case signOffSupport = "SIGN_OFF_SUPPORT"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .contextWide: return "Context (Wide)"
        case .defectMacro: return "Defect (Macro)"
        case .signOffSupport: return "Sign-Off Support"
        }
    }
}

/// Common canned reasons shown in the decline picker. "Other" always keeps
/// the free-text field editable.
enum DeclineReasonCode: String, Codable, CaseIterable, Identifiable, Sendable {
    case notAuthorized = "NOT_AUTHORIZED_TO_APPROVE_COSTS"
    case disputesScope = "DISPUTES_SCOPE"
    case wantsRevision = "WANTS_REVISION"
    case other = "OTHER"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notAuthorized: return "Not authorized to approve costs"
        case .disputesScope: return "Disputes scope"
        case .wantsRevision: return "Wants revision before signing"
        case .other: return "Other"
        }
    }
}

/// Common delivery methods for a contractual notice, per Project.noticeConfig.
enum NoticeDeliveryMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case email = "EMAIL"
    case certifiedMail = "CERTIFIED_MAIL"
    case portalUpload = "PORTAL_UPLOAD"
    case fax = "FAX"
    case handDelivery = "HAND_DELIVERY"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .email: return "Email"
        case .certifiedMail: return "Certified Mail"
        case .portalUpload: return "Portal Upload"
        case .fax: return "Fax"
        case .handDelivery: return "Hand Delivery"
        }
    }
}
