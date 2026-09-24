import Foundation

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
