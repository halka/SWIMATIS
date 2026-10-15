import SwiftUI

/// The app's root view owns the shared model and app-wide presentation state.
struct AppRootView: View {
    @State private var model = ATISAppModel()

    var body: some View {
        AppContent(model: model)
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

private struct AppContent: View {
    let model: ATISAppModel

    var body: some View {
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
}

#Preview {
    AppRootView()
}
