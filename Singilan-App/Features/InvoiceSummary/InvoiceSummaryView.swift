import SwiftUI

struct InvoiceSummaryView: View {
    @EnvironmentObject private var invoiceStore: InvoiceStore
    let invoice: Invoice
    @State private var shareItems: [Any] = []
    @State private var isSharing = false
    @State private var exportError: String?

    private var balances: [ParticipantBalance] { BillSplitter.balances(for: invoice) }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(invoice.title).font(.title2.bold())
                    Text(invoice.total, format: .currency(code: invoice.currency))
                        .font(.largeTitle.bold()).foregroundStyle(.tint)
                    Text("Split between \(invoice.participants.count) people").foregroundStyle(.secondary)
                }.padding(.vertical, 8)
            }

            Section("Amounts due") {
                ForEach(balances) { balance in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(balance.userID.isEmpty ? "Unnamed person" : balance.userID).font(.headline)
                            Spacer()
                            Text(balance.owed, format: .currency(code: invoice.currency)).font(.headline)
                        }
                        if balance.paid != 0 {
                            Text("Paid \(balance.paid, format: .currency(code: invoice.currency)) · Balance \(balance.balance, format: .currency(code: invoice.currency))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 3)
                }
            }

            Section("Items") {
                ForEach(invoice.items) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                            Text(item.isCreditLine ? "Credit" : item.isService ? "Service charge" : "\(NSDecimalNumber(decimal: item.quantity)) × \(NSDecimalNumber(decimal: item.price))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.amount, format: .currency(code: invoice.currency))
                    }
                }
            }

            if invoice.participants.isEmpty {
                ContentUnavailableView("No split yet", systemImage: "person.2.slash", description: Text("Add people to calculate individual amounts."))
            }
        }
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Actions", systemImage: "ellipsis.circle") {
                    Button("Share image", systemImage: "photo") { exportPNG() }
                    Button("Export CSV", systemImage: "tablecells") { exportCSV() }
                    Button("Duplicate", systemImage: "plus.square.on.square") { invoiceStore.duplicate(invoice) }
                }
            }
        }
        .sheet(isPresented: $isSharing) { ActivityView(items: shareItems).presentationDetents([.medium, .large]) }
        .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK") { exportError = nil }
        } message: { Text(exportError ?? "Unknown error") }
    }

    private func exportCSV() {
        do { shareItems = [try InvoiceExporter.csvURL(for: invoice)]; isSharing = true }
        catch { exportError = error.localizedDescription }
    }

    private func exportPNG() {
        do { shareItems = [try InvoiceExporter.pngURL(for: invoice)]; isSharing = true }
        catch { exportError = error.localizedDescription }
    }
}
