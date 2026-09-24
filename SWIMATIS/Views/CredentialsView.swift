import SwiftUI

struct CredentialsView: View {
    private enum Field: Hashable {
        case userID
        case password
    }

    @Environment(\.dismiss) private var dismiss

    @Bindable var model: ATISAppModel
    let isInitialSetup: Bool

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
                        .submitLabel(.done)
                        .onSubmit(saveCredentials)
                } header: {
                    Text("SWIM API 認証")
                } footer: {
                    Text("認証情報はこの端末の Keychain にのみ保存されます。")
                }

                Section {
                    Button(action: saveCredentials) {
                        Text(
                            isInitialSetup ? "保存して開始" : "認証情報を更新"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(userID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                focusedField = nil
            }
            .navigationTitle(isInitialSetup ? "セットアップ" : "認証情報")
            .navigationBarTitleDisplayMode(.inline)
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

    private func saveCredentials() {
        guard !userID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty else { return }

        focusedField = nil
        if model.saveCredentials(userID: userID, password: password),
           !isInitialSetup {
            dismiss()
        }
    }
}

private extension View {
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
