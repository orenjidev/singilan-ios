import SwiftUI
import UIKit

@MainActor
enum InvoiceExporter {
    static func csvURL(for invoice: Invoice) throws -> URL {
        let url = temporaryURL(title: invoice.title, extension: "csv")
        try InvoiceOperations.csv(for: invoice).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func pngURL(for invoice: Invoice) throws -> URL {
        let renderer = ImageRenderer(content: InvoiceShareCard(invoice: invoice).frame(width: 390))
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData() else { throw ExportError.renderFailed }
        let url = temporaryURL(title: invoice.title, extension: "png")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func temporaryURL(title: String, extension fileExtension: String) -> URL {
        let safeTitle = title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return FileManager.default.temporaryDirectory
            .appending(path: "\(safeTitle.isEmpty ? "invoice" : safeTitle).\(fileExtension)")
    }

    enum ExportError: LocalizedError {
        case renderFailed
        var errorDescription: String? { "The invoice image could not be generated." }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct InvoiceShareCard: View {
    let invoice: Invoice

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Singilan Na").font(.caption.bold()).foregroundStyle(.green)
                Text(invoice.title).font(.title.bold())
                Text(invoice.total, format: .currency(code: invoice.currency)).font(.largeTitle.bold())
            }

            Divider()
            ForEach(BillSplitter.balances(for: invoice)) { balance in
                HStack {
                    Text(balance.userID).fontWeight(.semibold)
                    Spacer()
                    Text(balance.owed, format: .currency(code: invoice.currency)).fontWeight(.bold)
                }
            }

            if let qr = invoice.paymentQr, let data = dataFromURL(qr), let image = UIImage(data: data) {
                Divider()
                HStack {
                    Image(uiImage: image).resizable().interpolation(.none).frame(width: 110, height: 110)
                    Text(invoice.paymentQrLabel ?? "Payment QR").font(.headline)
                }
            }
        }
        .padding(26)
        .foregroundStyle(.black)
        .background(.white)
    }

    private func dataFromURL(_ value: String) -> Data? {
        guard let comma = value.firstIndex(of: ",") else { return nil }
        return Data(base64Encoded: String(value[value.index(after: comma)...]))
    }
}
