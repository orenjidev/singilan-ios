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
        ScrollView {
            VStack(spacing: 17) {
                SingilanCard {
                    VStack(spacing: 5) {
                    Text(openInvoices.reduce(Decimal.zero) { $0 + $1.total }, format: .currency(code: "PHP"))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                    Text("Across \(openInvoices.count) open invoice\(openInvoices.count == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(22)
                }

                SingilanSectionTitle(text: "Combined amounts due")
                SingilanCard {
                ForEach(totals, id: \.0) { participant, amount in
                    HStack(spacing: 12) {
                        ParticipantAvatar(name: participant, size: 39)
                        Text(participant).fontWeight(.semibold)
                        Spacer()
                        Text(amount, format: .currency(code: "PHP")).fontWeight(.bold)
                    }.padding(14)
                    if participant != totals.last?.0 { SingilanDivider() }
                }
                }

                SingilanSectionTitle(text: "By invoice")
                SingilanCard {
                ForEach(openInvoices) { invoice in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(invoice.title).fontWeight(.semibold)
                            Text("Open · \(invoice.normalizedParticipants.count) people").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(invoice.total, format: .currency(code: invoice.currency)).fontWeight(.semibold)
                    }.padding(14)
                    if invoice.id != openInvoices.last?.id { SingilanDivider() }
                }
                }
            }
            .padding(16)
        }
        .singilanCanvas()
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
