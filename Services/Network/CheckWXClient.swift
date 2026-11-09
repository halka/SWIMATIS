import Foundation

struct CheckWXClient {
    private let baseEndpoint = URL(string: "https://api.checkwx.com/v2")!

    func fetchLatestMETAR(airport: String, apiKey: String) async throws -> CheckWXObservation? {
        try await fetchLatestReport(type: .metar, airport: airport, apiKey: apiKey)
    }

    func fetchLatestTAF(airport: String, apiKey: String) async throws -> CheckWXObservation? {
        try await fetchLatestReport(type: .taf, airport: airport, apiKey: apiKey)
    }

    private func fetchLatestReport(
        type: CheckWXReportType,
        airport: String,
        apiKey: String
    ) async throws -> CheckWXObservation? {
        guard !airport.isEmpty, !apiKey.isEmpty else {
            throw CheckWXRequestError.invalidRequest
        }

        let url = baseEndpoint
            .appending(path: type.rawValue)
            .appending(path: airport)
            .appending(path: "short")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CheckWXRequestError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401, 403:
            throw CheckWXRequestError.authenticationFailed
        case 404:
            return nil
        case 429:
            throw CheckWXRequestError.rateLimited
        default:
            throw CheckWXRequestError.httpStatus(httpResponse.statusCode)
        }

        do {
            let payload = try JSONDecoder().decode(CheckWXResponse.self, from: data)
            guard let report = payload.data.first else { return nil }
            return CheckWXObservation(
                airport: report.icao.uppercased(),
                rawText: report.rawText,
                type: type
            )
        } catch {
            throw CheckWXRequestError.invalidPayload
        }
    }
}

enum CheckWXReportType: String, Sendable {
    case metar
    case taf
}

private struct CheckWXResponse: Decodable {
    let data: [CheckWXReport]
}

private struct CheckWXReport: Decodable {
    let icao: String
    let rawText: String

    enum CodingKeys: String, CodingKey {
        case icao
        case rawText = "raw_text"
    }
}

struct CheckWXObservation: Sendable {
    let airport: String
    let rawText: String
    let type: CheckWXReportType
}

enum CheckWXRequestError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case invalidPayload
    case authenticationFailed
    case rateLimited
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            "CheckWX のリクエストを作成できませんでした。"
        case .invalidResponse:
            "CheckWX から解釈できない応答を受信しました。"
        case .invalidPayload:
            "CheckWX の応答が API 仕様と一致しません。"
        case .authenticationFailed:
            "CheckWX API キーが無効です。設定から確認してください。"
        case .rateLimited:
            "CheckWX API の利用上限に達しました。しばらくしてから再試行してください。"
        case .httpStatus(let status):
            "CheckWX との通信に失敗しました（HTTP \(status)）。"
        }
    }
}
