import Observation
import SwiftUI

#if os(iOS)
import UIKit
#endif

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
    var closedLocations: Set<String> = []
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
            var fetchedClosedLocations: Set<String> = []
            let referenceDate = Date()

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
                        let isClosed = location.atisInfo.contains {
                            ATISMessage.isCloseText($0)
                        }
                        let locationMessages = location.atisInfo
                            .enumerated()
                            .map { index, text in
                                let message = ATISMessage(
                                    id: "\(location.location)-\(index)-\(text.hashValue)",
                                    airport: location.location,
                                    rawText: text
                                )
                                return (
                                    sourceIndex: index,
                                    message: message,
                                    issuedAt: message.issuedAt(relativeTo: referenceDate)
                                )
                            }
                            .filter { !$0.message.isCloseMessage }
                            .sorted { first, second in
                                switch (first.issuedAt, second.issuedAt) {
                                case let (firstDate?, secondDate?):
                                    if firstDate == secondDate {
                                        return first.sourceIndex < second.sourceIndex
                                    }
                                    return firstDate > secondDate
                                case (_?, nil):
                                    return true
                                case (nil, _?):
                                    return false
                                case (nil, nil):
                                    return first.sourceIndex < second.sourceIndex
                                }
                            }
                            .map(\.message)
                        guard !locationMessages.isEmpty || isClosed else { continue }
                        fetchedLocations.append(location.location)
                        fetchedMessages.append(contentsOf: locationMessages)
                        if isClosed {
                            fetchedClosedLocations.insert(location.location)
                        }
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
            closedLocations = fetchedClosedLocations
        } catch is CancellationError {
            return
        } catch {
            messages = []
            resultLocationOrder = []
            closedLocations = []
            lastFetchedAt = nil
            errorMessage = error.localizedDescription
        }
    }

    func clearResults() {
        messages = []
        resultLocationOrder = []
        closedLocations = []
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

struct ContentView: View {
    @State private var model = ATISAppModel()

    var body: some View {
        Group {
            switch model.launchState {
            case .loading:
                ProgressView("認証情報を確認中…")
                    .controlSize(.large)
            case .requiresCredentials:
                CredentialsView(model: model, isInitialSetup: true)
            case .ready:
                ATISHomeView(model: model)
            }
        }
        .task {
            guard model.launchState == .loading else { return }
            model.prepare()
        }
        .alert(
            "エラー",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

private struct ATISHomeView: View {
    private enum Appearance: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: Self { self }

        var title: String {
            switch self {
            case .system: "システム設定"
            case .light: "ライト"
            case .dark: "ダーク"
            }
        }

        var systemImage: String {
            switch self {
            case .system: "circle.lefthalf.filled"
            case .light: "sun.max"
            case .dark: "moon"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    @Bindable var model: ATISAppModel
    @State private var isShowingCredentials = false
    @State private var isShowingClearConfirmation = false
    @State private var appearance: Appearance = .system
    @FocusState private var isLocationFieldFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                ATISRequestSection(
                    model: model,
                    isLocationFieldFocused: $isLocationFieldFocused
                )

                if model.isLoading {
                    ATISLoadingSection()
                } else if model.messages.isEmpty && model.closedLocations.isEmpty {
                    ATISEmptySection(hasRequested: model.hasRequested)
                } else {
                    ForEach(groupedMessages, id: \.airport) { group in
                        AirportATISSection(
                            airport: group.airport,
                            messages: group.messages,
                            isClosed: group.isClosed,
                            fetchedAt: model.lastFetchedAt
                        )
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                isLocationFieldFocused = false
            }
            .navigationTitle("ATIS Request Service")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if !model.messages.isEmpty {
                        Menu {
                            Button("再取得", systemImage: "arrow.clockwise") {
                                Task { await model.fetch() }
                            }

                            Button("結果をクリア", systemImage: "trash", role: .destructive) {
                                isShowingClearConfirmation = true
                            }
                        } label: {
                            Label("結果の操作", systemImage: "ellipsis")
                        }
                    }

                    Menu("設定", systemImage: "gearshape") {
                        Picker("外観", selection: $appearance) {
                            ForEach(Appearance.allCases) { option in
                                Label(option.title, systemImage: option.systemImage)
                                    .tag(option)
                            }
                        }

                        Divider()

                        Button("認証情報", systemImage: "person.badge.key") {
                            isShowingCredentials = true
                        }
                    }
                    .accessibilityHint("外観とSWIM WebAPIの認証情報を変更します")
                }
            }
            .preferredColorScheme(appearance.colorScheme)
            .confirmationDialog(
                "取得結果をすべてクリアしますか？",
                isPresented: $isShowingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("すべてクリア", role: .destructive) {
                    model.clearResults()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("表示中のATISが画面から削除されます。この操作は取り消せません。")
            }
            .sheet(isPresented: $isShowingCredentials) {
                CredentialsView(model: model, isInitialSetup: false)
            }
        }
    }

    private var groupedMessages: [
        (airport: String, messages: [ATISMessage], isClosed: Bool)
    ] {
        let messagesByAirport = Dictionary(grouping: model.messages, by: \.airport)
        return model.resultLocationOrder.map { airport in
            (
                airport: airport,
                messages: messagesByAirport[airport] ?? [],
                isClosed: model.closedLocations.contains(airport)
            )
        }
    }
}

private struct ATISRequestSection: View {
    @Bindable var model: ATISAppModel
    let isLocationFieldFocused: FocusState<Bool>.Binding

    var body: some View {
        Section {
            TextField(
                "RJCH, RJTT RJAA",
                text: $model.locationsText,
                axis: .vertical
            )
            .focused(isLocationFieldFocused)
            .atisCodeInputBehavior()
            .accessibilityLabel("ICAO 空港コード")
            .accessibilityHint("複数入力する場合は、カンマまたは空白で区切ります")

            Stepper(value: $model.displayCount, in: 1...50) {
                LabeledContent("表示件数") {
                    Text("\(model.displayCount)")
                        .monospacedDigit()
                        .foregroundStyle(.tint)
                }
            }

            Button {
                isLocationFieldFocused.wrappedValue = false
                Task { await model.fetch() }
            } label: {
                Text("Request")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .disabled(model.isLoading || model.normalizedLocations.isEmpty)
        } header: {
            Text("ICAO空港コードを入力してください。")
        } footer: {
            Text("複数の空港はカンマまたは空白で区切れます。")
        }
    }
}

private struct ATISLoadingSection: View {
    var body: some View {
        Section {
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text("SWIMからATISを取得中…")
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
        }
    }
}

private struct ATISEmptySection: View {
    let hasRequested: Bool

    var body: some View {
        Section {
            ContentUnavailableView(
                hasRequested ? "ATISが見つかりません" : "空港を指定してください",
                systemImage: hasRequested ? "tray" : "airplane.circle",
                description: Text(
                    hasRequested
                        ? "指定した空港のATISは現在ありません。時間をおいて再度お試しください。"
                        : "ICAO空港コードを入力して、ATISを取得します。"
                )
            )
        }
    }
}

private struct AirportATISSection: View {
    let airport: String
    let messages: [ATISMessage]
    let isClosed: Bool
    let fetchedAt: Date?

    @State private var isExpanded = true

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(messages) { message in
                    ATISMessageRow(message: message)
                        .padding(.leading, 4)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "airplane.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(airport)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.blue)

                            if isClosed {
                                Text("CLOSE")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.red)
                            }
                        }

                        if let fetchedAt {
                            Text(
                                "\(messages.count)件, \(fetchedAt.formatted(date: .abbreviated, time: .shortened))取得"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        } else {
                            Text("\(messages.count)件")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 0)

                    Menu {
#if os(iOS)
                        Button("コピー", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = exportText
                        }
#endif

                        ShareLink(
                            "共有",
                            item: exportText,
                            subject: Text("\(airport) ATIS")
                        )

#if os(iOS)
                        Button("印刷", systemImage: "printer") {
                            printATIS()
                        }
#endif
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                    .accessibilityLabel("\(airport)の操作")
                }
                .padding(.vertical, 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .tint(.blue)
            .animation(.snappy, value: isExpanded)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            .accessibilityHint(isExpanded ? "タップして情報を閉じます" : "タップして情報を表示します")
        }
    }

    private var exportText: String {
        ([airport] + messages.map(\.rawText)).joined(separator: "\n\n")
    }

#if os(iOS)
    private func printATIS() {
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "\(airport) ATIS"
        printInfo.outputType = .general

        let formatter = UISimpleTextPrintFormatter(text: exportText)
        formatter.perPageContentInsets = UIEdgeInsets(top: 36, left: 36, bottom: 36, right: 36)

        printController.printInfo = printInfo
        printController.printFormatter = formatter

        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) {
            printController.present(from: window.bounds, in: window, animated: true)
        } else {
            printController.present(animated: true)
        }
    }
#endif
}

private struct ATISMessageRow: View {
    let message: ATISMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let informationCode = message.informationCode {
                HStack(spacing: 8) {
                    Text("Information \(informationCode)")

                    if let issueTimeGroup = message.issueTimeGroup {
                        Text(issueTimeGroup)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .font(.headline)
            }

            Text(message.rawText)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

private struct CredentialsView: View {
    private enum Field: Hashable {
        case userID
        case password
    }

    @Bindable var model: ATISAppModel
    let isInitialSetup: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var userID = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("登録メールアドレス", text: $userID)
                        .focused($focusedField, equals: .userID)
                        .textContentType(.username)
                        .credentialInputBehavior()

                    SecureField("パスワード", text: $password)
                        .focused($focusedField, equals: .password)
                        .textContentType(.password)
                } header: {
                    Text("SWIM API 認証")
                } footer: {
                    Text("認証情報はこの端末の Keychain にのみ保存されます。")
                }

                Section {
                    Button {
                        focusedField = nil
                        if model.saveCredentials(userID: userID, password: password),
                           !isInitialSetup {
                            dismiss()
                        }
                    } label: {
                        Label(
                            isInitialSetup ? "保存して開始" : "認証情報を更新",
                            systemImage: "checkmark.shield.fill"
                        )
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.indigo)
                    .disabled(userID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                focusedField = nil
            }
            .navigationTitle(isInitialSetup ? "セットアップ" : "認証情報")
            .toolbar {
                if !isInitialSetup {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(isInitialSetup)
    }
}

private extension View {
    @ViewBuilder
    func atisCodeInputBehavior() -> some View {
#if os(iOS)
        textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
#else
        autocorrectionDisabled()
#endif
    }

    @ViewBuilder
    func credentialInputBehavior() -> some View {
#if os(iOS)
        textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.emailAddress)
#else
        autocorrectionDisabled()
#endif
    }
}

#Preview {
    ContentView()
}
