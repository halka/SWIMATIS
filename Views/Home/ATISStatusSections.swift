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
                hasRequested ? "ATIS Not Found" : "Retrive ATIS",
                systemImage: hasRequested ? "antenna.radiowaves.left.and.right.slash" : "airplane.circle",
                description: Text(
                    hasRequested
                        ? "Out of Service."
                        : "Input ICAO 4 Letter Airport Code"
                )
            )
        }
    }
}
