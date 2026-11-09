import SwiftUI

struct CheckWXSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var model: ATISAppModel
    @State private var apiKey = ""
    @State private var isShowingDeleteConfirmation = false
    @FocusState private var isAPIKeyFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API キー", text: $apiKey)
                        .focused($isAPIKeyFocused)
                        .textContentType(.password)
                        .autocorrectionDisabled()
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .submitLabel(.done)
                        .onSubmit(save)
                } header: {
                    Text("CheckWX API キー")
                } footer: {
                    Text("キーはこの端末の Keychain にのみ保存されます。設定後は、SWIM の状態にかかわらず、入力した各空港の最新 METAR と TAF を取得します。")
                }

                Section {
                    Link("CheckWX で API キーを取得", destination: URL(string: "https://www.checkwxapi.com/")!)
                }

                Section {
                    Button("API キーを保存", action: save)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.glassProminent)
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if model.hasCheckWXAPIKey {
                        Button("保存済みの API キーを削除", role: .destructive) {
                            isShowingDeleteConfirmation = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                apiKey = model.checkWXAPIKey ?? ""
            }
            .onTapGesture {
                isAPIKeyFocused = false
            }
            .navigationTitle("CheckWX")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "保存済みの CheckWX API キーを削除しますか？",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("API キーを削除", role: .destructive) {
                    if model.deleteCheckWXAPIKey() {
                        apiKey = ""
                        dismiss()
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    private func save() {
        isAPIKeyFocused = false
        if model.saveCheckWXAPIKey(apiKey) {
            dismiss()
        }
    }
}
