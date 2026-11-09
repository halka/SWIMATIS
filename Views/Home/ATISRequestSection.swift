import SwiftUI

struct ATISRequestSection: View {
    @Bindable var model: ATISAppModel
    let isLocationFieldFocused: FocusState<Bool>.Binding

    var body: some View {
        Section {
            TextField(
                "Example: RJCH,RJTT,RJGG RJOO",
                text: $model.locationsText,
                axis: .vertical
            )
            .focused(isLocationFieldFocused)
            .atisCodeInputBehavior()
            .submitLabel(.search)
            .onSubmit(requestATIS)
            .accessibilityLabel("ICAO 空港コード")
            .accessibilityHint("複数空港指定時はカンマまたは空白、改行で区切る")
            
            LabeledContent("表示件数") {
                TextField("1–50", value: $model.requestedDisplayCount, format: .number)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 64)
                    .displayCountInputBehavior()
                    .accessibilityLabel("1空港あたりの表示件数")
                    .accessibilityHint("1から50までの数字を入力")
            }
            Button(action: requestATIS) {
                Text("ATISを取得")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .disabled(model.isLoading || model.normalizedLocations.isEmpty)
        }
//        } header: {
//            Text("4文字のICAO空港コードを入力。")
//        } footer: {
//            Text("複数空港指定時はカンマまたは空白を挟むこと。")
//        }
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

    @ViewBuilder
    func displayCountInputBehavior() -> some View {
#if os(iOS)
        keyboardType(.numberPad)
#endif
    }
}

#if os(iOS)

#endif
