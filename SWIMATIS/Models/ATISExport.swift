import CoreTransferable
import Foundation
import UniformTypeIdentifiers

#if os(iOS)
import CoreText
import UIKit
#endif

struct ATISExport {
    let title: String
    let messages: [ATISMessage]
    let fetchedAt: Date?

    var plainText: String {
        var sections = [title]
        if let fetchedAt {
            sections.append("取得日時: \(fetchedAt.formatted(date: .abbreviated, time: .shortened))")
        }
        sections.append(contentsOf: messages.map(\.rawText))
        return sections.joined(separator: "\n\n")
    }

    var csvText: String {
        let header = "Airport,Information,Issue Time,ATIS"
        let rows = messages.map { message in
            [message.airport, message.informationCode ?? "", message.issueTimeGroup ?? "", message.rawText]
                .map(Self.csvField)
                .joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\r\n")
    }

    nonisolated private static func csvField(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

struct ATISTextFile: Transferable, Sendable {
    let data: Data

    init(export: ATISExport) {
        data = Data(export.plainText.utf8)
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .utf8PlainText) { item in
            item.data
        }
    }
}

struct ATISCSVFile: Transferable, Sendable {
    let data: Data

    init(export: ATISExport) {
        data = Data(export.csvText.utf8)
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { item in
            item.data
        }
    }
}

#if os(iOS)
struct ATISPDFFile: Transferable, Sendable {
    let data: Data

    init(export: ATISExport) {
        data = export.pdfData
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { item in
            item.data
        }
    }
}

extension ATISExport {
    var pdfData: Data {
        let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let printableBounds = pageBounds.insetBy(dx: 42, dy: 42)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let attributedText = NSAttributedString(
            string: plainText,
            attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.black
            ]
        )

        return renderer.pdfData { context in
            var remainingRange = NSRange(location: 0, length: attributedText.length)
            let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
            while remainingRange.length > 0 {
                context.beginPage()
                context.cgContext.saveGState()
                context.cgContext.textMatrix = .identity
                context.cgContext.translateBy(x: 0, y: pageBounds.height)
                context.cgContext.scaleBy(x: 1, y: -1)
                let path = CGPath(rect: printableBounds, transform: nil)
                let frame = CTFramesetterCreateFrame(
                    framesetter,
                    CFRange(location: remainingRange.location, length: remainingRange.length),
                    path,
                    nil
                )
                CTFrameDraw(frame, context.cgContext)
                context.cgContext.restoreGState()
                let visibleRange = CTFrameGetVisibleStringRange(frame)
                guard visibleRange.length > 0 else { break }
                remainingRange.location += visibleRange.length
                remainingRange.length -= visibleRange.length
            }
        }
    }
}
#endif
