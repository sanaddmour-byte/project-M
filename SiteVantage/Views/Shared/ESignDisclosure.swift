//
//  ESignDisclosure.swift
//  SiteVantage
//
//  Static, jurisdiction-keyed e-signature disclosure templates shown before
//  Path A (Sign On-Glass). This is intentionally a simple static template,
//  not a legal opinion — only "US" ships with ESIGN-Act-style consent copy
//  in this build; every other jurisdiction gets a generic placeholder and
//  a caption telling the reader to have counsel confirm local requirements
//  before relying on it. See DECISIONS.md.
//

import Foundation

enum ESignDisclosure {
    static func text(for jurisdiction: String) -> String {
        switch jurisdiction.uppercased() {
        case "US":
            return "By signing below, you consent to conducting this transaction electronically and confirm that your electronic signature is the legal equivalent of a manual signature, consistent with the U.S. Electronic Signatures in Global and National Commerce Act (ESIGN Act) and applicable state UETA law. You may request a paper record of this ticket."
        default:
            return "By signing below, you consent to sign this field ticket electronically. This is a generic placeholder disclosure \u{2014} \(jurisdiction) does not yet have jurisdiction-specific copy reviewed for this build. Confirm local e-signature requirements with counsel before relying on this for jurisdictions outside the US."
        }
    }
}
