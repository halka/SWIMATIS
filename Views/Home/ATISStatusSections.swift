import SwiftUI

struct ATISLoadingSection: View {
    var body: some View {
        Section {
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text("ATISを取得中…")
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
        }
    }
}

struct ATISEmptySection: View {
    let hasRequested: Bool

    var body: some View {
        Section {
            ContentUnavailableView(
                hasRequested ? "ATISが見つかりません" : "ATISを取得",
                systemImage: hasRequested ? "antenna.radiowaves.left.and.right.slash" : "airplane.circle",
                description: Text(
                    hasRequested
                        ? "指定した空港のATISは現在ありません。時間をおいて再度お試しください。"
                        : "上の欄にICAO空港コードを入力してください。"
                )
            )
        }
    }
}
