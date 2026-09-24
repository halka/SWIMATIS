import Foundation

struct ATISMessage: Identifiable {
    let id: String
    let airport: String
    let rawText: String

    var informationCode: String? {
        let firstLine = rawText.split(whereSeparator: \.isNewline).first.map(String.init)
        return firstLine?.split(separator: " ").last.map(String.init)
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
