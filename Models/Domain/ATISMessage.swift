import Foundation

struct ATISMessage: Identifiable {
    enum Source: String, Sendable {
        case swim
        case checkWXMETAR
        case checkWXTAF

        var displayName: String {
            switch self {
            case .swim: "SWIM ATIS"
            case .checkWXMETAR: "CheckWX METAR"
            case .checkWXTAF: "CheckWX TAF"
            }
        }

        var reportName: String? {
            switch self {
            case .swim: nil
            case .checkWXMETAR: "METAR"
            case .checkWXTAF: "TAF"
            }
        }
    }

    let id: String
    let airport: String
    let rawText: String
    let source: Source

    init(id: String, airport: String, rawText: String, source: Source = .swim) {
        self.id = id
        self.airport = airport
        self.rawText = rawText
        self.source = source
    }

    var informationCode: String? {
        if let reportName = source.reportName { return reportName }
        guard !isClosed else { return nil }

        let firstLine = rawText.split(whereSeparator: \.isNewline).first.map(String.init)
        let informationCode = firstLine?.split(separator: " ").last.map(String.init)
        
        guard informationCode?.count == 1 else {
            return "🚫"
        }
        return informationCode
    }

    var issueTimeGroup: String? {
        rawText
            .split(whereSeparator: \.isWhitespace)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .first { token in
                token.count == 7
                    && token.last == "Z"
                    && token.dropLast().allSatisfy(\.isNumber)
            }
    }

    var isClosed: Bool {
        rawText
            .split(whereSeparator: \.isWhitespace)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).uppercased() }
            .contains("CLOSE")
    }

    func issuedAt(relativeTo referenceDate: Date) -> Date? {
        guard let timestamp = issueTimeGroup else { return nil }

        let digits = timestamp.dropLast()
        guard
            let day = Int(digits.prefix(2)),
            let hour = Int(digits.dropFirst(2).prefix(2)),
            let minute = Int(digits.suffix(2)),
            (1...31).contains(day),
            (0...23).contains(hour),
            (0...59).contains(minute)
        else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let referenceMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: referenceDate)
        )

        return [-1, 0, 1]
            .compactMap { monthOffset -> Date? in
                guard
                    let referenceMonth,
                    let month = calendar.date(byAdding: .month, value: monthOffset, to: referenceMonth)
                else {
                    return nil
                }

                var components = calendar.dateComponents([.year, .month], from: month)
                components.day = day
                components.hour = hour
                components.minute = minute
                components.timeZone = calendar.timeZone
                guard let date = calendar.date(from: components) else { return nil }

                let validated = calendar.dateComponents([.day, .hour, .minute], from: date)
                guard
                    validated.day == day,
                    validated.hour == hour,
                    validated.minute == minute
                else {
                    return nil
                }
                return date
            }
            .min { first, second in
                abs(first.timeIntervalSince(referenceDate)) < abs(second.timeIntervalSince(referenceDate))
            }
    }
}
