import SwiftUI

struct InvoiceSummaryView: View {
    @EnvironmentObject private var invoiceStore: InvoiceStore
    let invoice: Invoice
    @State private var shareItems: [Any] = []
    @State private var isSharing = false
    @State private var exportError: String?

    private var balances: [ParticipantBalance] { BillSplitter.balances(for: invoice) }

    var body: some View {
        ScrollView {
            VStack(spacing: 17) {
                SingilanCard {
                    VStack(spacing: 5) {
                        Text(invoice.title).font(.subheadline).foregroundStyle(.secondary)
                        Text(invoice.total, format: .currency(code: invoice.currency))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                        if invoice.serviceChargeAmount > 0 {
                            Text("Includes \(invoice.serviceChargeAmount, format: .currency(code: invoice.currency)) service charge")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.frame(maxWidth: .infinity).padding(22)
                }

                SingilanSectionTitle(text: "Amounts due")
                SingilanCard {
                ForEach(balances) { balance in
                    HStack(spacing: 12) {
                        ParticipantAvatar(name: balance.userID, size: 39)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(balance.userID).fontWeight(.semibold)
                            Text(balance.paid == 0 ? "Amount due" : "Paid \(balance.paid, format: .currency(code: invoice.currency))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(balance.owed, format: .currency(code: invoice.currency)).fontWeight(.bold)
                    }.padding(14)
                    if balance.id != balances.last?.id { SingilanDivider() }
                }
                }

                SingilanSectionTitle(text: "Items")
                SingilanCard {
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
                    .padding(14)
                    if item.id != invoice.items.last?.id { SingilanDivider() }
                }
                }

                HStack(spacing: 9) {
                    actionButton("Share", icon: "square.and.arrow.up") { exportPNG() }
                    actionButton("CSV", icon: "tablecells") { exportCSV() }
                    actionButton("Duplicate", icon: "plus.square.on.square") { invoiceStore.duplicate(invoice) }
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .singilanCanvas()
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

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.title3).foregroundStyle(SingilanTheme.green)
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(SingilanTheme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SingilanTheme.border))
        }
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
