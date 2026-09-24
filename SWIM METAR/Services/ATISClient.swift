import Foundation

struct ATISClient {
    private let loginEndpoint = URL(string: "https://top.swim.mlit.go.jp/swim/webapi/login")!
    private let atisEndpoint = URL(string: "https://web.swim.mlit.go.jp/f2atrq/web/FLV402001")!

    func fetch(
        locations: [String],
        displayCount: Int,
        credentials: SWIMCredentials
    ) async throws -> ATISResponse {
        guard (1...50).contains(displayCount), !locations.isEmpty else {
            throw ATISRequestError.invalidRequest
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        let cookieStorage = HTTPCookieStorage()
        configuration.httpCookieStorage = cookieStorage
        let urlSession = URLSession(configuration: configuration)

        let swimSession = try await authenticate(
            credentials: credentials,
            urlSession: urlSession,
            cookieStorage: cookieStorage
        )

        var components = URLComponents(url: atisEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "location", value: locations.joined(separator: ",")),
            URLQueryItem(name: "dispcnt", value: String(displayCount))
        ]
        guard let url = components?.url else {
            throw ATISRequestError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(swimSession.cookieHeader, forHTTPHeaderField: "Cookie")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ATISRequestError.invalidResponse
        }
        guard httpResponse.statusCode != 401, httpResponse.statusCode != 403 else {
            throw ATISRequestError.authenticationExpired
        }
        guard httpResponse.statusCode == 200 else {
            throw ATISRequestError.httpStatus(httpResponse.statusCode)
        }
        guard
            httpResponse.url?.scheme == atisEndpoint.scheme,
            httpResponse.url?.host == atisEndpoint.host,
            httpResponse.url?.path == atisEndpoint.path
        else {
            throw ATISRequestError.authenticationExpired
        }

        return try decodeATISResponse(data, response: httpResponse)
    }

    private func authenticate(
        credentials: SWIMCredentials,
        urlSession: URLSession,
        cookieStorage: HTTPCookieStorage
    ) async throws -> SWIMSession {
        struct LoginRequest: Encodable {
            let id: String
            let password: String
        }

        var request = URLRequest(url: loginEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "application/json; charset=UTF-8",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = try JSONEncoder().encode(
            LoginRequest(id: credentials.userID, password: credentials.password)
        )

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ATISRequestError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ATISRequestError.authenticationFailed
        }

        var values = cookieValues(from: httpResponse)
        for cookie in cookieStorage.cookies ?? [] {
            if cookie.name == "MSMSI" || cookie.name == "MSMAI" {
                values[cookie.name] = cookie.value
            }
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let value = json["MSMSI"] as? String {
                values["MSMSI"] = value
            }
            if let value = json["MSMAI"] as? String {
                values["MSMAI"] = value
            }
        }

        guard
            let msmsi = values["MSMSI"], !msmsi.isEmpty,
            let msmai = values["MSMAI"], !msmai.isEmpty
        else {
            throw ATISRequestError.authenticationSessionMissing
        }

        return SWIMSession(msmsi: msmsi, msmai: msmai)
    }

    private func decodeATISResponse(
        _ data: Data,
        response: HTTPURLResponse
    ) throws -> ATISResponse {
        let firstByte = data.first { byte in
            ![9, 10, 13, 32].contains(byte)
        }
        if firstByte == Character("<").asciiValue {
            throw ATISRequestError.authenticationExpired
        }

        do {
            return try JSONDecoder().decode(ATISResponse.self, from: data)
        } catch {
            let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? "不明"
            let structure = responseStructure(in: data)
            let responseURL = response.url?.absoluteString ?? "不明"
            throw ATISRequestError.invalidPayload(
                "URL: \(responseURL)\nContent-Type: \(contentType)、\(data.count) bytes\n"
                    + "\(decodingDetail(error))\n\(structure)"
            )
        }
    }

    private func responseStructure(in data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let dictionary = object as? [String: Any]
        else {
            return "JSON構造: オブジェクトではありません"
        }

        let topKeys = dictionary.keys.sorted().joined(separator: ", ")
        let errorCodes = (dictionary["error_info"] as? [[String: Any]])?
            .compactMap { $0["error_code"] as? String }
            .joined(separator: ", ") ?? "取得不能"
        let firstDataKeys = (dictionary["data"] as? [[String: Any]])?
            .first?
            .keys
            .sorted()
            .joined(separator: ", ") ?? "なし"

        return """
        トップレベルキー: \(topKeys)
        error_code: \(errorCodes)
        data[0]のキー: \(firstDataKeys)
        認証Cookie: MSMSI/MSMAI取得済み
        """
    }

    private func decodingDetail(_ error: Error) -> String {
        let path: ([CodingKey]) -> String = { codingPath in
            let value = codingPath.map(\.stringValue).joined(separator: ".")
            return value.isEmpty ? "ルート" : value
        }

        switch error {
        case DecodingError.keyNotFound(let key, let context):
            return "キー「\(key.stringValue)」がありません（\(path(context.codingPath))）。"
        case DecodingError.valueNotFound(_, let context):
            return "値がありません（\(path(context.codingPath))）。"
        case DecodingError.typeMismatch(_, let context):
            return "値の型が異なります（\(path(context.codingPath))）。"
        case DecodingError.dataCorrupted(let context):
            return "JSONが破損しています（\(path(context.codingPath))）。"
        default:
            return error.localizedDescription
        }
    }

    private func cookieValues(from response: HTTPURLResponse) -> [String: String] {
        let headerFields = response.allHeaderFields.reduce(into: [String: String]()) {
            guard let key = $1.key as? String, let value = $1.value as? String else {
                return
            }
            $0[key] = value
        }

        return HTTPCookie.cookies(
            withResponseHeaderFields: headerFields,
            for: loginEndpoint
        ).reduce(into: [String: String]()) {
            if $1.name == "MSMSI" || $1.name == "MSMAI" {
                $0[$1.name] = $1.value
            }
        }
    }
}

private struct SWIMSession: Sendable {
    let msmsi: String
    let msmai: String

    var cookieHeader: String {
        "MSMSI=\(msmsi); MSMAI=\(msmai)"
    }
}
