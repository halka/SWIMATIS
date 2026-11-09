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
                hasRequested ? "ATIS Not Found" : "Retrieve ATIS",
                systemImage: hasRequested ? "antenna.radiowaves.left.and.right.slash" : "airplane.circle",
                description: Text(
                    hasRequested
                        ? "No ATIS is currently available for the requested airports."
                        : "Enter one or more four-letter ICAO airport codes."
                )
            )
        }
    }
}
