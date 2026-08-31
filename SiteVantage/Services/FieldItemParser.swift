//
//  FieldItemParser.swift
//  SiteVantage
//
//  Deliberately simple keyword/regex extraction over the raw voice
//  transcript to pre-fill labor/equipment line items. This is a heuristic,
//  not an NLP pipeline — per spec §5, parsing will not be perfect and the
//  foreman must always be able to edit or delete every suggestion. Every
//  item this produces is flagged `isParserSuggested = true` downstream.
//

import Foundation

struct ParsedLaborSuggestion: Identifiable {
    let id = UUID()
    var description: String
    var headcount: Int
    var hours: Decimal
}

struct ParsedEquipmentSuggestion: Identifiable {
    let id = UUID()
    var description: String
    var hoursOperated: Decimal
}

struct ParsedTicketSuggestions {
    var laborItems: [ParsedLaborSuggestion] = []
    var equipmentItems: [ParsedEquipmentSuggestion] = []
}

enum FieldItemParser {
    private static let laborTradeWords = [
        "electrician", "laborer", "labourer", "carpenter", "plumber", "apprentice",
        "foreman", "pipefitter", "ironworker", "mason", "operator", "welder",
        "painter", "drywaller", "worker", "crew member", "helper"
    ]

    private static let equipmentKeywords = [
        "mini excavator", "scissor lift", "boom lift", "skid steer", "man lift",
        "dump truck", "excavator", "forklift", "generator", "compressor",
        "crane", "backhoe", "bobcat", "chipper", "welder machine"
    ]

    static func parse(_ text: String) -> ParsedTicketSuggestions {
        var result = ParsedTicketSuggestions()
        guard !text.isEmpty else { return result }

        let lowercased = text.lowercased()

        // Labor: "<n> <trade word>(s)"
        for trade in laborTradeWords {
            let pattern = "(\\d+)\\s+\(NSRegularExpression.escapedPattern(for: trade))s?\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(lowercased.startIndex..., in: lowercased)
            regex.enumerateMatches(in: lowercased, range: range) { match, _, _ in
                guard let match, match.numberOfRanges >= 2,
                      let countRange = Range(match.range(at: 1), in: lowercased) else { return }
                let count = Int(lowercased[countRange]) ?? 1
                let hours = nearestHours(in: lowercased, around: match.range) ?? 0
                result.laborItems.append(
                    ParsedLaborSuggestion(description: trade.capitalized, headcount: count, hours: hours)
                )
            }
        }

        // Equipment: bare keyword mention, optionally with nearby hours.
        // Longer phrases are checked first and claim their match range so
        // e.g. "mini excavator" doesn't also produce a second, redundant
        // suggestion just for containing the substring "excavator".
        var matchedEquipmentRanges: [Range<String.Index>] = []
        for equipment in equipmentKeywords.sorted(by: { $0.count > $1.count }) {
            guard lowercased.contains(equipment) else { continue }
            let pattern = NSRegularExpression.escapedPattern(for: equipment)
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(lowercased.startIndex..., in: lowercased)
            guard let match = regex.firstMatch(in: lowercased, range: range),
                  let matchRange = Range(match.range, in: lowercased) else { continue }
            guard !matchedEquipmentRanges.contains(where: { $0.overlaps(matchRange) }) else { continue }
            matchedEquipmentRanges.append(matchRange)

            let hours = nearestHours(in: lowercased, around: match.range) ?? 0
            result.equipmentItems.append(
                ParsedEquipmentSuggestion(description: equipment.capitalized, hoursOperated: hours)
            )
        }

        // If exactly one labor item was found with no hours attached, but a
        // single bare "N hours" mention exists somewhere in the text, apply
        // it — a common phrasing is "two electricians for six hours" where
        // the number sits after the trade word rather than immediately by it.
        if result.laborItems.count == 1, result.laborItems[0].hours == 0,
           let globalHours = firstHoursMention(in: lowercased) {
            result.laborItems[0].hours = globalHours
        }

        return result
    }

    private static func nearestHours(in text: String, around range: NSRange) -> Decimal? {
        let searchStart = max(0, range.location - 40)
        let searchLength = min(text.utf16.count - searchStart, (range.location - searchStart) + range.length + 40)
        guard searchLength > 0, let searchRange = Range(NSRange(location: searchStart, length: searchLength), in: text) else {
            return nil
        }
        let window = String(text[searchRange])
        return firstHoursMention(in: window)
    }

    private static func firstHoursMention(in text: String) -> Decimal? {
        guard let regex = try? NSRegularExpression(
            pattern: "(\\d+(?:\\.\\d+)?)\\s*(?:hours|hrs|hr)\\b",
            options: [.caseInsensitive]
        ) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges >= 2,
              let valueRange = Range(match.range(at: 1), in: text) else { return nil }
        return Decimal(string: String(text[valueRange]))
    }
}
