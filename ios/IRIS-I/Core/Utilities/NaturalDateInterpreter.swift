//
//  NaturalDateInterpreter.swift
//  IRIS-I
//
//  Deterministic natural-language date and time parser for iOS.
//  Converts phrases like "tomorrow at 4:30 PM", "in 45 minutes", "next Monday at 10 AM",
//  and ISO date strings into authoritative Date and DateComponents.
//

import Foundation

public struct ParsedNaturalDate: Sendable {
    public let date: Date
    public let dateComponents: DateComponents
    public let isTimeSpecified: Bool
}

public struct NaturalDateInterpreter: Sendable {
    public static func parse(_ text: String, referenceDate: Date = Date()) -> ParsedNaturalDate? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }

        let calendar = Calendar.current

        // 1. Check relative offsets: "in X minutes", "in X hours", "in X days"
        if let offsetDate = parseRelativeOffset(trimmed, referenceDate: referenceDate) {
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: offsetDate)
            return ParsedNaturalDate(date: offsetDate, dateComponents: comps, isTimeSpecified: true)
        }

        // 2. Check "tomorrow" patterns
        if trimmed.contains("tomorrow") {
            var targetDay = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
            let (hour, minute, hasTime) = extractTime(from: trimmed) ?? (9, 0, false)
            var comps = calendar.dateComponents([.year, .month, .day], from: targetDay)
            comps.hour = hour
            comps.minute = minute
            comps.second = 0
            if let date = calendar.date(from: comps) {
                return ParsedNaturalDate(date: date, dateComponents: comps, isTimeSpecified: hasTime)
            }
        }

        // 3. Check "today" or "tonight"
        if trimmed.contains("today") || trimmed.contains("tonight") {
            let defaultHour = trimmed.contains("tonight") ? 20 : 18
            let (hour, minute, hasTime) = extractTime(from: trimmed) ?? (defaultHour, 0, false)
            var comps = calendar.dateComponents([.year, .month, .day], from: referenceDate)
            comps.hour = hour
            comps.minute = minute
            comps.second = 0
            if let date = calendar.date(from: comps) {
                return ParsedNaturalDate(date: date, dateComponents: comps, isTimeSpecified: hasTime)
            }
        }

        // 4. Try NSDataDetector for general natural dates
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            if let firstMatch = matches.first, let detectedDate = firstMatch.date {
                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: detectedDate)
                let hasTime = firstMatch.timeZone != nil || trimmed.contains("at") || trimmed.contains("pm") || trimmed.contains("am")
                return ParsedNaturalDate(date: detectedDate, dateComponents: comps, isTimeSpecified: hasTime)
            }
        }

        // 5. Try ISO8601 & standard formatters
        let formatters: [String] = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd",
            "MM/dd/yyyy HH:mm",
            "MM/dd/yyyy h:mm a"
        ]

        for fmt in formatters {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = fmt
            if let parsed = df.date(from: text) {
                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: parsed)
                return ParsedNaturalDate(date: parsed, dateComponents: comps, isTimeSpecified: fmt.contains("HH") || fmt.contains("h:mm"))
            }
        }

        return nil
    }

    private static func parseRelativeOffset(_ text: String, referenceDate: Date) -> Date? {
        let calendar = Calendar.current
        let pattern = #"in\s+(\d+)\s*(min|minute|minutes|hour|hours|hr|hrs|day|days)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        guard let match = matches.first, match.numberOfRanges >= 3 else { return nil }

        let valueStr = nsText.substring(with: match.range(at: 1))
        let unitStr = nsText.substring(with: match.range(at: 2)).lowercased()
        guard let value = Int(valueStr) else { return nil }

        if unitStr.hasPrefix("min") {
            return calendar.date(byAdding: .minute, value: value, to: referenceDate)
        } else if unitStr.hasPrefix("hour") || unitStr.hasPrefix("hr") {
            return calendar.date(byAdding: .hour, value: value, to: referenceDate)
        } else if unitStr.hasPrefix("day") {
            return calendar.date(byAdding: .day, value: value, to: referenceDate)
        }

        return nil
    }

    private static func extractTime(from text: String) -> (hour: Int, minute: Int, hasTime: Bool)? {
        // Look for expressions like "at 4:30 pm", "at 5pm", "4pm", "9:00 am"
        let pattern = #"(\d{1,2})(?::(\d{2}))?\s*(am|pm)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            let hourStr = nsText.substring(with: match.range(at: 1))
            guard var hour = Int(hourStr), hour >= 1 && hour <= 24 else { continue }

            var minute = 0
            if match.range(at: 2).location != NSNotFound {
                let minStr = nsText.substring(with: match.range(at: 2))
                minute = Int(minStr) ?? 0
            }

            var hasMeridiem = false
            if match.numberOfRanges >= 4 && match.range(at: 3).location != NSNotFound {
                let meridiem = nsText.substring(with: match.range(at: 3)).lowercased()
                hasMeridiem = true
                if meridiem == "pm" && hour < 12 {
                    hour += 12
                } else if meridiem == "am" && hour == 12 {
                    hour = 0
                }
            }

            return (hour, minute, true)
        }

        if text.contains("morning") {
            return (9, 0, true)
        } else if text.contains("afternoon") {
            return (14, 0, true)
        } else if text.contains("evening") {
            return (18, 0, true)
        } else if text.contains("night") {
            return (21, 0, true)
        }

        return nil
    }
}

