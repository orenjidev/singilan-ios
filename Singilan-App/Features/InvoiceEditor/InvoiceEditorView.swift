import SwiftUI
import PhotosUI

struct InvoiceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var invoiceStore: InvoiceStore
    @State private var invoice: Invoice
    @State private var errorMessage: String?
    @State private var selectedQRItem: PhotosPickerItem?
    @State private var desiredServicePercent: Decimal
    let isNew: Bool

    init(invoice: Invoice, isNew: Bool = false) {
        _invoice = State(initialValue: invoice)
        _desiredServicePercent = State(initialValue: invoice.serviceChargePercent)
        self.isNew = isNew
    }

    var body: some View {
        Form {
            Section("Invoice") {
                TextField("Title", text: $invoice.title)
                Picker("Status", selection: $invoice.status) {
                    ForEach(InvoiceStatus.allCases) { status in
                        Text(status.label).tag(status)
                    }
                }
                LabeledContent("Total") {
                    Text(invoice.total, format: .currency(code: invoice.currency))
                }
                TextField("Service charge %", value: $desiredServicePercent, format: .number)
                    .keyboardType(.decimalPad)
            }

            Section("People") {
                ForEach(invoice.participants.indices, id: \.self) { index in
                    TextField("Name", text: participantBinding(at: index))
                }
                .onDelete(perform: removeParticipants)
                Button("Add person", systemImage: "person.badge.plus") {
                    invoice.participants.append("")
                }
                .disabled(invoice.participants.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            }

            Section("Items") {
                ForEach($invoice.items) { $item in
                    NavigationLink {
                        InvoiceItemEditorView(item: $item, participants: invoice.normalizedParticipants)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name.isEmpty ? "Untitled item" : item.name)
                                Text(assignmentLabel(for: item))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.amount, format: .currency(code: "PHP"))
                                .foregroundStyle(item.isCreditLine ? .green : .primary)
                        }
                    }
                }
                .onDelete { invoice.items.remove(atOffsets: $0) }
                Button("Add item", systemImage: "plus") {
                    invoice.items.append(InvoiceItem(name: "", shares: shareMapForAllParticipants()))
                }
            }

            Section("Payment QR") {
                if let qrData = paymentQRData, let image = UIImage(data: qrData) {
                    HStack {
                        Image(uiImage: image)
                            .resizable().interpolation(.none).scaledToFit().frame(maxHeight: 150)
                        Spacer()
                        Button("Remove", role: .destructive) {
                            invoice.paymentQr = nil
                            invoice.paymentQrLabel = nil
                        }
                    }
                    TextField("Label (GCash, Maya, bank)", text: paymentQRLabel)
                } else {
                    PhotosPicker(selection: $selectedQRItem, matching: .images) {
                        Label("Choose payment QR", systemImage: "qrcode.viewfinder")
                    }
                }
            }

            if !invoice.participants.isEmpty {
                Section("Split preview") {
                    ForEach(BillSplitter.balances(for: invoice)) { balance in
                        LabeledContent(balance.userID.isEmpty ? "Unnamed person" : balance.userID) {
                            Text(balance.owed, format: .currency(code: invoice.currency))
                                .fontWeight(.semibold)
                        }
                    }

                    NavigationLink("View full summary") {
                        InvoiceSummaryView(invoice: invoice)
                    }
                }
            }
        }
        .navigationTitle(isNew ? "New Invoice" : invoice.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(invoice.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .alert("Couldn’t save invoice", isPresented: errorBinding) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .onChange(of: selectedQRItem) { _, item in
            guard let item else { return }
            Task { await loadPaymentQR(item) }
        }
        .onChange(of: desiredServicePercent) { _, percent in
            updateServiceCharge(percent: max(percent, 0))
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func save() {
        normalizeParticipantsAndAssignments()
        updateServiceCharge(percent: desiredServicePercent)
        invoice.updatedAt = .now
        if invoiceStore.save(invoice), isNew {
            dismiss()
        }
    }

    private func assignmentLabel(for item: InvoiceItem) -> String {
        let names = invoice.participants.filter { item.shares[$0] == true && !$0.isEmpty }
        return names.isEmpty ? "No one selected" : names.joined(separator: ", ")
    }

    private func updateServiceCharge(percent: Decimal) {
        invoice.items.removeAll(identifiedByServiceCharge: true)
        guard percent > 0, invoice.regularSubtotal > 0 else { return }
        invoice.items.append(InvoiceItem(
            name: "Service charge",
            price: invoice.regularSubtotal * percent / 100,
            shares: shareMapForAllParticipants(),
            isServiceCharge: true
        ))
    }

    private func participantBinding(at index: Int) -> Binding<String> {
        Binding(get: { invoice.participants[index] }, set: { newName in
            let oldName = invoice.participants[index]
            invoice.participants[index] = newName
            for itemIndex in invoice.items.indices {
                if let value = invoice.items[itemIndex].shares.removeValue(forKey: oldName) {
                    invoice.items[itemIndex].shares[newName] = value
                }
                if let value = invoice.items[itemIndex].payments.removeValue(forKey: oldName) {
                    invoice.items[itemIndex].payments[newName] = value
                }
                if let value = invoice.items[itemIndex].weights?.removeValue(forKey: oldName) {
                    invoice.items[itemIndex].weights?[newName] = value
                }
            }
        })
    }

    private func removeParticipants(at offsets: IndexSet) {
        let removed = offsets.map { invoice.participants[$0] }
        invoice.participants.remove(atOffsets: offsets)
        for index in invoice.items.indices {
            removed.forEach {
                invoice.items[index].shares.removeValue(forKey: $0)
                invoice.items[index].payments.removeValue(forKey: $0)
                invoice.items[index].weights?.removeValue(forKey: $0)
            }
        }
    }

    private func shareMapForAllParticipants() -> [String: Bool] {
        invoice.normalizedParticipants.reduce(into: [:]) { $0[$1] = true }
    }

    private func normalizeParticipantsAndAssignments() {
        let original = invoice.participants
        let normalized = invoice.normalizedParticipants

        for itemIndex in invoice.items.indices {
            var shares: [String: Bool] = [:]
            var payments: [String: Bool] = [:]
            var weights: [String: Decimal] = [:]

            for oldName in original {
                let name = oldName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard normalized.contains(name) else { continue }
                shares[name] = (shares[name] == true) || (invoice.items[itemIndex].shares[oldName] == true)
                payments[name] = (payments[name] == true) || (invoice.items[itemIndex].payments[oldName] == true)
                if let weight = invoice.items[itemIndex].weights?[oldName] {
                    weights[name] = max(weights[name] ?? 0, weight)
                }
            }

            invoice.items[itemIndex].shares = shares
            invoice.items[itemIndex].payments = payments
            invoice.items[itemIndex].weights = weights.isEmpty ? nil : weights
        }
        invoice.participants = normalized
    }

    private var paymentQRLabel: Binding<String> {
        Binding(get: { invoice.paymentQrLabel ?? "" }, set: { invoice.paymentQrLabel = $0.isEmpty ? nil : $0 })
    }

    private var paymentQRData: Data? {
        guard let value = invoice.paymentQr, let comma = value.firstIndex(of: ",") else { return nil }
        return Data(base64Encoded: String(value[value.index(after: comma)...]))
    }

    private func loadPaymentQR(_ item: PhotosPickerItem) async {
        do {
            guard let source = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: source),
                  let data = image.pngData(),
                  data.count <= 2_000_000 else {
                errorMessage = "Choose a QR image smaller than 2 MB."
                return
            }
            invoice.paymentQr = "data:image/png;base64,\(data.base64EncodedString())"
            if invoice.paymentQrLabel == nil { invoice.paymentQrLabel = "Payment QR" }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension Array where Element == InvoiceItem {
    mutating func removeAll(identifiedByServiceCharge: Bool) {
        removeAll { $0.isServiceCharge == identifiedByServiceCharge }
    }
}

#Preview {
    NavigationStack {
        InvoiceEditorView(invoice: Invoice(title: "Friday dinner"))
    }
    .environmentObject(InvoiceStore.preview)
}
