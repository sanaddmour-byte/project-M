//
//  TicketSerialGenerator.swift
//  SiteVantage
//
//  Generates TKT-{projectCode}-{year}-{sequential 4-digit} serials, unique
//  per project per calendar year. Sequence is derived from existing tickets
//  already on the project rather than a stored counter, so it stays correct
//  even if a ticket is later deleted mid-sequence (gaps are fine; repeats
//  are not).
//

import Foundation

enum TicketSerialGenerator {
    static func nextSerial(for project: Project, year: Int = Calendar.current.component(.year, from: Date())) -> String {
        let prefix = "TKT-\(project.projectCode)-\(year)-"
        let existingSequences: [Int] = project.tickets.compactMap { ticket in
            guard ticket.ticketSerial.hasPrefix(prefix) else { return nil }
            let suffix = ticket.ticketSerial.dropFirst(prefix.count)
            return Int(suffix)
        }
        let nextSequence = (existingSequences.max() ?? 0) + 1
        let padded = String(format: "%04d", nextSequence)
        return "\(prefix)\(padded)"
    }
}
