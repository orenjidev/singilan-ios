import SwiftUI

struct InvoiceListView: View {
    @EnvironmentObject private var invoiceStore: InvoiceStore
    @State private var isCreatingInvoice = false

    var body: some View {
        NavigationStack {
            Group {
                if invoiceStore.invoices.isEmpty {
                    ContentUnavailableView(
                        "No invoices yet",
                        systemImage: "doc.text",
                        description: Text("Create a bill and split it with your group.")
                    )
                } else {
                    List {
                        ForEach(invoiceStore.invoices) { invoice in
                            NavigationLink(value: invoice) {
                                InvoiceRow(invoice: invoice, needsSync: true)
                            }
                            .swipeActions(edge: .leading) {
                                Button("Duplicate", systemImage: "plus.square.on.square") {
                                    invoiceStore.duplicate(invoice)
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete(perform: invoiceStore.delete)
                    }
                }
            }
            .navigationTitle("Singilan Na")
            .navigationDestination(for: Invoice.self) { invoice in
                InvoiceEditorView(invoice: invoice)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: GrandSummaryView()) {
                        Label("Grand summary", systemImage: "sum")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New invoice", systemImage: "plus") {
                        isCreatingInvoice = true
                    }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Undo", systemImage: "arrow.uturn.backward") { invoiceStore.undo() }
                        .disabled(!invoiceStore.canUndo)
                    Spacer()
                    Button("Redo", systemImage: "arrow.uturn.forward") { invoiceStore.redo() }
                        .disabled(!invoiceStore.canRedo)
                }
            }
            .sheet(isPresented: $isCreatingInvoice) {
                NavigationStack {
                    InvoiceEditorView(invoice: Invoice(title: ""), isNew: true)
                        .environmentObject(invoiceStore)
                }
            }
            .alert("Couldn’t update invoices", isPresented: errorBinding) {
                Button("OK") { invoiceStore.errorMessage = nil }
            } message: {
                Text(invoiceStore.errorMessage ?? "Unknown error")
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { invoiceStore.errorMessage != nil },
            set: { if !$0 { invoiceStore.errorMessage = nil } }
        )
    }
}

private struct InvoiceRow: View {
    let invoice: Invoice
    let needsSync: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(invoice.title).font(.headline)
                Text(invoice.updatedAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(invoice.total, format: .currency(code: invoice.currency))
                    .fontWeight(.semibold)
                if needsSync {
                    Label(invoice.status.label, systemImage: invoice.status == .open ? "circle.fill" : "circle")
                        .font(.caption2)
                        .foregroundStyle(invoice.status == .open ? .green : .secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    InvoiceListView()
        .environmentObject(InvoiceStore.preview)
}
