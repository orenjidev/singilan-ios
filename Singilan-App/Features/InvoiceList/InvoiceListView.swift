import SwiftUI

struct InvoiceListView: View {
    @EnvironmentObject private var invoiceStore: InvoiceStore
    @EnvironmentObject private var accountStore: AccountStore
    @State private var isCreatingInvoice = false
    @State private var isShowingAccount = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                SingilanTheme.canvas.ignoresSafeArea()
                if invoiceStore.invoices.isEmpty {
                    ContentUnavailableView(
                        "No invoices yet",
                        systemImage: "doc.text",
                        description: Text("Create a bill and split it with your group.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            HStack(alignment: .bottom) {
                                Text("Singilan Na")
                                    .font(.largeTitle.bold())
                                Spacer()
                                Button { isShowingAccount = true } label: {
                                    ParticipantAvatar(name: accountStore.user?.username ?? "Guest", size: 38)
                                }
                            }

                            HStack(spacing: 9) {
                                NavigationLink(destination: GrandSummaryView()) {
                                    Label("Grand summary", systemImage: "sum")
                                }
                                Spacer()
                                Button("Undo", systemImage: "arrow.uturn.backward") { invoiceStore.undo() }
                                    .disabled(!invoiceStore.canUndo)
                                Button("Redo", systemImage: "arrow.uturn.forward") { invoiceStore.redo() }
                                    .disabled(!invoiceStore.canRedo)
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)

                            SingilanSectionTitle(text: "Your invoices")
                            SingilanCard {
                        ForEach(invoiceStore.invoices) { invoice in
                            NavigationLink(value: invoice) {
                                InvoiceRow(invoice: invoice, needsSync: true)
                            }
                            .buttonStyle(.plain)
                            if invoice.id != invoiceStore.invoices.last?.id { SingilanDivider() }
                        }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                }

                Button {
                    isCreatingInvoice = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(SingilanTheme.green, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                        .shadow(color: SingilanTheme.green.opacity(0.34), radius: 14, y: 8)
                }
                .padding(22)
            }
            .tint(SingilanTheme.green)
            .navigationTitle("")
            .navigationBarHidden(true)
            .navigationDestination(for: Invoice.self) { invoice in
                InvoiceEditorView(invoice: invoice)
            }
            .sheet(isPresented: $isCreatingInvoice) {
                NavigationStack {
                    InvoiceEditorView(invoice: Invoice(title: ""), isNew: true)
                        .environmentObject(invoiceStore)
                }
            }
            .sheet(isPresented: $isShowingAccount) {
                AccountView().environmentObject(accountStore)
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
        HStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.title3)
                .foregroundStyle(SingilanTheme.green)
                .frame(width: 43, height: 43)
                .background(SingilanTheme.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 5) {
                Text(invoice.title).font(.headline)
                Text("\(invoice.normalizedParticipants.count) people · \(invoice.items.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(invoice.total, format: .currency(code: invoice.currency))
                    .fontWeight(.semibold)
                if needsSync {
                    Text(invoice.status.label)
                        .font(.caption2)
                        .foregroundStyle(invoice.status == .open ? .green : .secondary)
                }
            }
        }
        .padding(14)
    }
}

#Preview {
    InvoiceListView()
        .environmentObject(InvoiceStore.preview)
        .environmentObject(AccountStore())
}
