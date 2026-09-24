import SwiftUI

struct ATISRequestSection: View {
    @Bindable var model: ATISAppModel
    let isLocationFieldFocused: FocusState<Bool>.Binding

    var body: some View {
        Section {
            TextField(
                "例: RJCH, RJTT, RJAA",
                text: $model.locationsText,
                axis: .vertical
            )
            .focused(isLocationFieldFocused)
            .atisCodeInputBehavior()
            .submitLabel(.search)
            .onSubmit(requestATIS)
            .accessibilityLabel("ICAO 空港コード")
            .accessibilityHint("複数空港指定時はカンマまたは空白で区切る")

            Stepper(value: $model.displayCount, in: 1...50) {
                LabeledContent("表示件数") {
                    Text("\(model.displayCount)")
                        .monospacedDigit()
                        .foregroundStyle(.tint)
                }
            }

            Button(action: requestATIS) {
                Text("ATISを取得")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .disabled(model.isLoading || model.normalizedLocations.isEmpty)
        } header: {
            Text("4文字のICAO空港コードを入力。")
        } footer: {
            Text("複数空港指定時はカンマまたは空白を挟むこと。")
        }
    }

    private func requestATIS() {
        isLocationFieldFocused.wrappedValue = false
        Task { await model.fetch() }
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
}
