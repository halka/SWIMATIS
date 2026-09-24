import Foundation
import Observation

@MainActor
@Observable
final class ATISAppModel {
    enum LaunchState {
        case loading
        case requiresCredentials
        case ready
    }

    var launchState: LaunchState = .loading
    var credentials: SWIMCredentials?
    var locationsText = ""
    var displayCount = 5
    var messages: [ATISMessage] = []
    var resultLocationOrder: [String] = []
    var lastFetchedAt: Date?
    var hasRequested = false
    var isLoading = false
    var errorMessage: String?

    private let keychain = KeychainStore()
    private let client = ATISClient()

    func prepare() {
        do {
            credentials = try keychain.loadCredentials()
            launchState = credentials == nil ? .requiresCredentials : .ready
        } catch {
            errorMessage = error.localizedDescription
            launchState = .requiresCredentials
        }
    }

    func saveCredentials(userID: String, password: String) -> Bool {
        let value = SWIMCredentials(
            userID: userID.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
        guard !value.userID.isEmpty, !value.password.isEmpty else {
            errorMessage = "登録メールアドレスとパスワードを入力してください。"
            return false
        }

        do {
            try keychain.save(value)
            credentials = value
            launchState = .ready
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func fetch() async {
        guard let credentials else {
            launchState = .requiresCredentials
            return
        }

        let locations = normalizedLocations
        guard !locations.isEmpty else {
            errorMessage = "ICAO 空港コードを1件以上入力してください。"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var fetchedMessages: [ATISMessage] = []
            var fetchedLocations: [String] = []

            for requestedLocation in locations {
                let response = try await client.fetch(
                    locations: [requestedLocation],
                    displayCount: displayCount,
                    credentials: credentials
                )

                guard let result = response.errorInfo.first else {
                    throw ATISRequestError.invalidPayload("error_info が空です。")
                }

                switch result.errorCode {
                case "0":
                    for location in response.data ?? [] {
                        let locationMessages = location.atisInfo
                            .enumerated()
                            .map { index, text in
                                ATISMessage(
                                    id: "\(location.location)-\(index)-\(text.hashValue)",
                                    airport: location.location,
                                    rawText: text
                                )
                            }
                        guard !locationMessages.isEmpty else { continue }
                        fetchedLocations.append(location.location)
                        fetchedMessages.append(contentsOf: locationMessages)
                    }
                case "1", "4":
                    continue
                default:
                    throw ATISRequestError.service(
                        code: result.errorCode,
                        description: result.errorDescription
                    )
                }
            }

            hasRequested = true
            lastFetchedAt = Date()
            resultLocationOrder = fetchedLocations
            messages = fetchedMessages
        } catch is CancellationError {
            return
        } catch {
            messages = []
            resultLocationOrder = []
            lastFetchedAt = nil
            errorMessage = error.localizedDescription
        }
    }

    func clearResults() {
        messages = []
        resultLocationOrder = []
        lastFetchedAt = nil
        hasRequested = false
        errorMessage = nil
    }

    var normalizedLocations: [String] {
        var seen = Set<String>()
        return locationsText
            .uppercased()
            .components(separatedBy: CharacterSet(charactersIn: ",、 \n\t"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { code in
                guard code.count == 4, code.allSatisfy({ $0.isLetter }) else {
                    return false
                }
                return seen.insert(code).inserted
            }
    }
}
