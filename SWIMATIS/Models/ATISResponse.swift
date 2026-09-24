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
        data = if errorInfo.first?.errorCode == "0" {
            try container.decode([ATISLocation].self, forKey: .data)
        } else {
            nil
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

        if let specifiedValue = try container.decodeIfPresent([String].self, forKey: .atisInfo) {
            atisInfo = specifiedValue
        } else {
            atisInfo = try container.decode([String].self, forKey: .observedAtisInfo)
        }
    }
}
