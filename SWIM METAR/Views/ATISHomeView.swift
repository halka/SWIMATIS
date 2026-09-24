import SwiftUI

struct ATISHomeView: View {
    @Bindable var model: ATISAppModel
    @State private var isShowingCredentials = false
    @State private var isShowingClearConfirmation = false
    @AppStorage("appAppearance") private var appearance: AppAppearance = .system
    @FocusState private var isLocationFieldFocused: Bool

    private var groupedMessages: [(airport: String, messages: [ATISMessage])] {
        let messagesByAirport = Dictionary(grouping: model.messages, by: \.airport)
        return model.resultLocationOrder.map { airport in
            (
                airport: airport,
                messages: messagesByAirport[airport] ?? []
            )
        }
    }

    private var allResultsExport: ATISExport {
        ATISExport(
            title: "ATIS取得結果",
            messages: model.messages,
            fetchedAt: model.lastFetchedAt
        )
    }

    var body: some View {
        NavigationStack {
            List {
                ATISRequestSection(
                    model: model,
                    isLocationFieldFocused: $isLocationFieldFocused
                )

                if model.isLoading {
                    ATISLoadingSection()
                } else if model.messages.isEmpty {
                    ATISEmptySection(hasRequested: model.hasRequested)
                } else {
                    ForEach(groupedMessages, id: \.airport) { group in
                        AirportATISSection(
                            airport: group.airport,
                            messages: group.messages,
                            fetchedAt: model.lastFetchedAt
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                isLocationFieldFocused = false
            }
            .navigationTitle("WXREQ")
            .navigationSubtitle("SWIM ATIS Request Service")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if !model.messages.isEmpty {
                        Menu {
                            ATISShareMenu(export: allResultsExport)
                        } label: {
                            Label("すべて共有", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityHint("表示中のすべてのATISを共有または書き出します")

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

                    Menu("設定", systemImage: "ellipsis.circle") {
                        Picker("外観", selection: $appearance) {
                            ForEach(AppAppearance.allCases) { option in
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
}
