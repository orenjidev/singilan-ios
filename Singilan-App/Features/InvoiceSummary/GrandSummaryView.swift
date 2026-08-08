import SwiftUI

struct GrandSummaryView: View {
    @EnvironmentObject private var invoiceStore: InvoiceStore
    @State private var shareItems: [Any] = []
    @State private var isSharing = false

    private var openInvoices: [Invoice] { invoiceStore.invoices.filter { $0.status == .open } }
    private var totals: [(String, Decimal)] {
        InvoiceOperations.grandTotals(for: openInvoices).sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(openInvoices.reduce(Decimal.zero) { $0 + $1.total }, format: .currency(code: "PHP"))
                        .font(.largeTitle.bold()).foregroundStyle(.tint)
                    Text("Across \(openInvoices.count) open invoice\(openInvoices.count == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                }.padding(.vertical, 8)
            }

            Section("Combined amounts due") {
                ForEach(totals, id: \.0) { participant, amount in
                    LabeledContent(participant) { Text(amount, format: .currency(code: "PHP")).fontWeight(.semibold) }
                }
            }

            Section("Open invoices") {
                ForEach(openInvoices) { invoice in
                    LabeledContent(invoice.title) { Text(invoice.total, format: .currency(code: invoice.currency)) }
                }
            }
        }
        .navigationTitle("Grand Summary")
        .overlay {
            if openInvoices.isEmpty {
                ContentUnavailableView("No open invoices", systemImage: "sum", description: Text("Set an invoice to Open to include it here."))
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Share", systemImage: "square.and.arrow.up") { shareGrandCSV() }.disabled(openInvoices.isEmpty)
            }
        }
        .sheet(isPresented: $isSharing) { ActivityView(items: shareItems).presentationDetents([.medium, .large]) }
    }

    private func shareGrandCSV() {
        let header = "Participant,Amount Due"
        let rows = totals.map { "\($0.0),\(NSDecimalNumber(decimal: $0.1).stringValue)" }
        let url = FileManager.default.temporaryDirectory.appending(path: "singilan-grand-summary.csv")
        do {
            try ([header] + rows).joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            shareItems = [url]
            isSharing = true
        } catch { invoiceStore.errorMessage = error.localizedDescription }
    }
}
