import Foundation
import Observation

@MainActor
@Observable
final class ATISAppModel {
    enum LaunchState: Equatable {
        case loading
        case requiresCredentials
        case ready
    }

    var launchState: LaunchState = .loading
    var credentials: SWIMCredentials?
    private(set) var checkWXAPIKey: String?
    var locationsText = "" {
        didSet {
            UserDefaults.standard.set(locationsText, forKey: Self.locationsTextStorageKey)
        }
    }
    var displayCount = 5
    var messages: [ATISMessage] = []
    var resultLocationOrder: [String] = []
    var lastFetchedAt: Date?
    var hasRequested = false
    var isLoading = false
    var errorMessage: String?

    private let keychain = KeychainStore()
    private let client = ATISClient()
    private let checkWXClient = CheckWXClient()
    private static let locationsTextStorageKey = "lastICAOLocationsText"

    func prepare() {
        locationsText = UserDefaults.standard.string(forKey: Self.locationsTextStorageKey) ?? ""

        do {
            credentials = try keychain.loadCredentials()
            checkWXAPIKey = try keychain.loadCheckWXAPIKey()
            launchState = credentials == nil ? .requiresCredentials : .ready
        } catch {
            errorMessage = error.localizedDescription
            launchState = .requiresCredentials
        }
    }

    var hasCheckWXAPIKey: Bool {
        !(checkWXAPIKey?.isEmpty ?? true)
    }

    func saveCheckWXAPIKey(_ value: String) -> Bool {
        let apiKey = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            errorMessage = "CheckWX API キーを入力してください。"
            return false
        }

        do {
            try keychain.saveCheckWXAPIKey(apiKey)
            checkWXAPIKey = apiKey
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteCheckWXAPIKey() -> Bool {
        do {
            try keychain.deleteCheckWXAPIKey()
            checkWXAPIKey = nil
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
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
            var checkWXError: Error?

            func append(_ newMessages: [ATISMessage]) {
                for message in newMessages {
                    if !fetchedLocations.contains(message.airport) {
                        fetchedLocations.append(message.airport)
                    }
                }
                fetchedMessages.append(contentsOf: newMessages)
            }

            for requestedLocation in locations {
                let messageCountBeforeRequest = fetchedMessages.count
                var swimError: Error?

                do {
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
                            append(locationMessages)
                        }
                    case "1", "4":
                        break
                    default:
                        throw ATISRequestError.service(
                            code: result.errorCode,
                            description: result.errorDescription
                        )
                    }
                } catch {
                    swimError = error
                }

                let checkWXResult = await checkWXMessages(for: requestedLocation)
                append(checkWXResult.messages)
                if let error = checkWXResult.error {
                    if error is CancellationError {
                        throw error
                    }
                    checkWXError = checkWXError ?? error
                }

                if fetchedMessages.count == messageCountBeforeRequest,
                   let swimError {
                    throw swimError
                }
            }

            hasRequested = true
            lastFetchedAt = Date()
            resultLocationOrder = fetchedLocations
            messages = fetchedMessages
            if let checkWXError {
                errorMessage = checkWXError.localizedDescription
            }
        } catch is CancellationError {
            return
        } catch {
            clearFetchedResults()
            errorMessage = error.localizedDescription
        }
    }

    func clearResults() {
        clearFetchedResults()
        hasRequested = false
        errorMessage = nil
    }

    private func clearFetchedResults() {
        messages = []
        resultLocationOrder = []
        lastFetchedAt = nil
    }

    private func checkWXMessages(for airport: String) async -> (messages: [ATISMessage], error: Error?) {
        guard let checkWXAPIKey else { return ([], nil) }

        async let metar = checkWXClient.fetchLatestMETAR(airport: airport, apiKey: checkWXAPIKey)
        async let taf = checkWXClient.fetchLatestTAF(airport: airport, apiKey: checkWXAPIKey)

        var observations: [CheckWXObservation] = []
        var firstError: Error?

        do {
            if let observation = try await metar {
                observations.append(observation)
            }
        } catch {
            firstError = error
        }

        do {
            if let observation = try await taf {
                observations.append(observation)
            }
        } catch {
            firstError = firstError ?? error
        }

        let messages = observations.map { observation in
            let source: ATISMessage.Source = switch observation.type {
            case .metar: .checkWXMETAR
            case .taf: .checkWXTAF
            }
            return ATISMessage(
                id: "\(observation.airport)-\(observation.type.rawValue)-\(observation.rawText.hashValue)",
                airport: observation.airport,
                rawText: observation.rawText,
                source: source
            )
        }
        return (messages, firstError)
    }

    var normalizedLocations: [String] {
        var seen = Set<String>()
        return locationsText
            .uppercased()
            .components(separatedBy: CharacterSet(charactersIn: ",、 \n\t"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { code in
                guard
                    code.utf8.count == 4,
                    code.unicodeScalars.allSatisfy({ (65...90).contains($0.value) })
                else {
                    return false
                }
                return seen.insert(code).inserted
            }
    }

    var requestedDisplayCount: Int {
        get { displayCount }
        set { displayCount = min(max(newValue, 1), 50) }
    }
}
