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
            let response = try await client.fetch(
                locations: locations,
                displayCount: displayCount,
                credentials: credentials
            )
            hasRequested = true

            guard let result = response.errorInfo.first else {
                throw ATISRequestError.invalidPayload("error_info が空です。")
            }

            switch result.errorCode {
            case "0":
                lastFetchedAt = Date()
                messages = (response.data ?? []).flatMap { location in
                    location.atisInfo.enumerated().map { index, text in
                        ATISMessage(
                            id: "\(location.location)-\(index)-\(text.hashValue)",
                            airport: location.location,
                            rawText: text
                        )
                    }
                }
            case "1":
                lastFetchedAt = Date()
                messages = []
            default:
                throw ATISRequestError.service(
                    code: result.errorCode,
                    description: result.errorDescription
                )
            }
        } catch is CancellationError {
            return
        } catch {
            messages = []
            lastFetchedAt = nil
            errorMessage = error.localizedDescription
        }
    }

    func clearResults() {
        messages = []
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

    var body: some View {
        NavigationStack {
            List {
                requestSection

                if model.isLoading {
                    loadingSection
                } else if model.messages.isEmpty {
                    emptySection
                } else {
                    resultsSection
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("ATIS リクエストサービス")
            .navigationBarTitleDisplayMode(.inline)
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

                    Menu {
                        Picker("外観", selection: $appearance) {
                            ForEach(Appearance.allCases) { option in
                                Label(option.title, systemImage: option.systemImage)
                                    .tag(option)
                            }
                        }
                    } label: {
                        Label("外観", systemImage: appearance.systemImage)
                    }
                    .accessibilityHint("ライトモードとダークモードを切り替えます")

                    Button("認証情報", systemImage: "person.badge.key") {
                        isShowingCredentials = true
                    }
                    .accessibilityHint("SWIM WebAPIの認証情報を変更します")
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

    private var requestSection: some View {
        Section {
            TextField(
                "ICAO AIRPORT CODE. e.g. RJCH",
                text: $model.locationsText,
                axis: .vertical
            )
            .atisCodeInputBehavior()
            .accessibilityLabel("ICAO 空港コード")

            Stepper(value: $model.displayCount, in: 1...50) {
                LabeledContent("表示件数") {
                    Text("\(model.displayCount)")
                        .monospacedDigit()
                        .foregroundStyle(.tint)
                }
            }

            Button {
                Task { await model.fetch() }
            } label: {
                Text("リクエスト")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .disabled(model.isLoading || model.normalizedLocations.isEmpty)
        } header: {
        } footer: {
            Text("空港コードICAOで入力。複数の空港を指定する際はカンマ、空白で区切る。")
        }
    }

    private var loadingSection: some View {
        Section {
            HStack(spacing: 12) {
                ProgressView()
                Text("SWIMからATISを取得中…")
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
        }
    }

    private var emptySection: some View {
        Section {
            ContentUnavailableView(
                model.hasRequested ? "該当する空港のATISはありません" : "空港を指定してください",
                systemImage: model.hasRequested ? "tray" : "airplane.circle",
                description: Text(
                    model.hasRequested
                        ? "指定した条件に該当するATISはありません。"
                        : "ICAO 空港コードを入力"
                )
            )
        }
    }

    private var resultsSection: some View {
        ForEach(groupedMessages, id: \.airport) { group in
            AirportATISSection(
                airport: group.airport,
                messages: group.messages,
                fetchedAt: model.lastFetchedAt
            )
        }
    }

    private var groupedMessages: [(airport: String, messages: [ATISMessage])] {
        Dictionary(grouping: model.messages, by: \.airport)
            .map { (airport: $0.key, messages: $0.value) }
            .sorted { $0.airport < $1.airport }
    }
}

private struct AirportATISSection: View {
    let airport: String
    let messages: [ATISMessage]
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
                HStack(spacing: 12) {
                    Image(systemName: "airplane.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(airport)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.blue)

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
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .tint(.blue)
            .animation(.snappy, value: isExpanded)
            .listRowSeparator(.hidden)
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
                Text("Information \(informationCode)")
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
    @Bindable var model: ATISAppModel
    let isInitialSetup: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var userID = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("登録メールアドレス", text: $userID)
                        .textContentType(.username)
                        .credentialInputBehavior()

                    SecureField("パスワード", text: $password)
                        .textContentType(.password)
                } header: {
                    Text("SWIM API 認証")
                } footer: {
                    Text("認証情報はこの端末の Keychain にのみ保存されます。")
                }

                Section {
                    Button {
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
