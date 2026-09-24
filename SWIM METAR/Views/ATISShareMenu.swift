import SwiftUI

#if os(iOS)
import UIKit
#endif

struct ATISShareMenu: View {
    let export: ATISExport

    var body: some View {
        ShareLink(
            "共有",
            item: export.plainText,
            subject: Text(export.title)
        )
#if os(iOS)
        Button("コピー", systemImage: "doc.on.doc") {
            UIPasteboard.general.string = export.plainText
        }
#endif



        Menu("ファイル共有", systemImage: "doc.badge.arrow.up") {
            ShareLink(
                "TXT",
                item: ATISTextFile(export: export),
                preview: SharePreview("\(export.title).txt", icon: Image(systemName: "doc.plaintext"))
            )
            ShareLink(
                "CSV",
                item: ATISCSVFile(export: export),
                preview: SharePreview("\(export.title).csv", icon: Image(systemName: "tablecells"))
            )
#if os(iOS)
            ShareLink(
                "PDF",
                item: ATISPDFFile(export: export),
                preview: SharePreview("\(export.title).pdf", icon: Image(systemName: "doc.richtext"))
            )
#endif
        }

#if os(iOS)
        Button("印刷", systemImage: "printer") {
            printATIS()
        }
#endif
    }

#if os(iOS)
    private func printATIS() {
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = export.title
        printInfo.outputType = .general
        printController.printInfo = printInfo
        printController.printingItem = export.pdfData

        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) {
            printController.present(from: window.bounds, in: window, animated: true)
        } else {
            printController.present(animated: true)
        }
    }
#endif
}
