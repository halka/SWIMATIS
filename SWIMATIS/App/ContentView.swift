import SwiftUI

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

#Preview {
    ContentView()
}
