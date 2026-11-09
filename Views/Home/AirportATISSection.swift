import SwiftUI

struct AirportATISSection: View {
    let airport: String
    let messages: [ATISMessage]
    let fetchedAt: Date?

    @State private var isExpanded = true

    private var export: ATISExport {
        ATISExport(title: "\(airport) ATIS", messages: messages, fetchedAt: fetchedAt)
    }

    private var firstMessage: ATISMessage? {
        messages.first
    }

    private var informationCode: String {
        guard let firstMessage else { return "—" }
        if let reportName = firstMessage.source.reportName { return reportName }
        guard !firstMessage.isClosed else { return "—" }
        return firstMessage.informationCode ?? "—"
    }

    private var statusText: String {
        guard let firstMessage else { return "—" }
        return firstMessage.isClosed ? "CLOSE" : firstMessage.issueTimeGroup ?? "—"
    }

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(messages) { message in
                    ATISMessageRow(message: message, fetchedAt: fetchedAt)
                        .padding(.leading, 4)
                }
            } label: {
                HStack(spacing: 10) {
                    Text(informationCode)
                        .font(firstMessage?.source.reportName == nil ? .largeTitle.weight(.bold).monospaced() : .title2.weight(.bold).monospaced())
                        .foregroundStyle(.tint)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel(firstMessage?.source.displayName ?? "ATIS情報コード")
                        .accessibilityValue(informationCode)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(airport)
                                .font(.title.weight(.bold))
                                .foregroundStyle(.primary)

                            Text(statusText)
                                .font(.title2.italic())
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        if let fetchedAt {
                            Text(
                                "\(messages.count)件・\(fetchedAt.formatted(date: .abbreviated, time: .shortened)) 取得"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        } else {
                            Text("\(messages.count)件")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 0)

                    Menu {
                        ATISShareMenu(export: export)
                    } label: {
                        Label("共有", systemImage: "square.and.arrow.up")
                            .font(.title2)
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("\(airport)のATISを共有")
                }
                .padding(.vertical, 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .tint(.blue)
            .animation(.snappy, value: isExpanded)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            .accessibilityHint(isExpanded ? "タップして情報を閉じます" : "タップして情報を表示します")
        }
    }

}

private struct ATISMessageRow: View {
    let message: ATISMessage
    let fetchedAt: Date?

    private var export: ATISExport {
        ATISExport(
            title: "\(message.airport) WEATHER",
            messages: [message],
            fetchedAt: fetchedAt
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message.rawText)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            if message.source.reportName != nil {
                Label(message.source.displayName, systemImage: "cloud.sun")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Menu {
                    ATISShareMenu(export: export)
                } label: {
                    Label("共有", systemImage: "square.and.arrow.up")
                        .font(.title3)
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .controlSize(.regular)
                .accessibilityLabel("\(message.airport)のこのATISを共有")
                .accessibilityHint("共有方法または書き出し形式を選びます")
            }
        }
        .padding(.vertical, 6)
        .contextMenu {
            ATISShareMenu(export: export)
        }
    }
}
