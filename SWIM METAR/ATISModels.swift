import Foundation

struct ATISResponse: Decodable, Sendable {
    let errorInfo: [ATISErrorInfo]
    let data: [ATISLocation]?

    enum CodingKeys: String, CodingKey {
        case errorInfo = "error_info"
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        errorInfo = try container.decode([ATISErrorInfo].self, forKey: .errorInfo)

        if errorInfo.first?.errorCode == "0" {
            data = try container.decode([ATISLocation].self, forKey: .data)
        } else {
            data = nil
        }
    }
}

struct ATISErrorInfo: Decodable, Sendable {
    let errorCode: String
    let errorDescription: String

    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case errorDescription = "error_description"
    }
}

struct ATISLocation: Decodable, Identifiable, Sendable {
    let location: String
    let atisInfo: [String]

    var id: String { location }

    enum CodingKeys: String, CodingKey {
        case location
        case atisInfo = "atisinfo"
        case observedAtisInfo = "atisInfo"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        location = try container.decode(String.self, forKey: .location)

        if let specifiedValue = try container.decodeIfPresent(
            [String].self,
            forKey: .atisInfo
        ) {
            atisInfo = specifiedValue
        } else {
            atisInfo = try container.decode(
                [String].self,
                forKey: .observedAtisInfo
            )
        }
    }
}

struct ATISMessage: Identifiable {
    let id: String
    let airport: String
    let rawText: String

    var informationCode: String? {
        let firstLine = rawText.split(whereSeparator: \.isNewline).first.map(String.init)
        return firstLine?.split(separator: " ").last.map(String.init)
    }

    func issuedAt(relativeTo referenceDate: Date) -> Date? {
        guard let timestamp = rawText
            .split(whereSeparator: \.isWhitespace)
            .map({ $0.trimmingCharacters(in: .punctuationCharacters) })
            .first(where: { token in
                token.count == 7
                    && token.last == "Z"
                    && token.dropLast().allSatisfy(\.isNumber)
            })
        else {
            return nil
        }

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

struct SWIMCredentials: Codable, Equatable, Sendable {
    let userID: String
    let password: String
}

enum ATISRequestError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case invalidPayload(String)
    case authenticationFailed
    case authenticationSessionMissing
    case authenticationExpired
    case httpStatus(Int)
    case service(code: String, description: String)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            "リクエストを作成できませんでした。"
        case .invalidResponse:
            "サーバーから解釈できない応答を受信しました。"
        case .invalidPayload(let detail):
            "応答がAPI仕様と一致しません。\n\(detail)"
        case .authenticationFailed:
            "SWIMへのログインに失敗しました。メールアドレスとパスワードを確認してください。"
        case .authenticationSessionMissing:
            "ログイン応答から必要なセッション情報を取得できませんでした。"
        case .authenticationExpired:
            "SWIMの認証セッションが無効です。認証情報を確認して、もう一度お試しください。"
        case .httpStatus(let status):
            "通信に失敗しました（HTTP \(status)）。認証情報とネットワークを確認してください。"
        case .service(let code, let description):
            serviceMessage(code: code, description: description)
        }
    }

    private func serviceMessage(code: String, description: String) -> String {
        switch code {
        case "2":
            return "ICAO 空港コードが指定されていません。"
        case "3":
            return "取得件数が指定されていません。"
        case "4":
            return "存在しない ICAO 空港コードです：\(description)"
        case "5":
            return "指定できる空港数の上限を超えています。"
        case "6":
            return "取得件数は 1〜50 で指定してください：\(description)"
        case "99":
            return "SWIM サービスで予期しないエラーが発生しました。"
        default:
            return "SWIM エラー \(code)：\(description)"
        }
    }
}
