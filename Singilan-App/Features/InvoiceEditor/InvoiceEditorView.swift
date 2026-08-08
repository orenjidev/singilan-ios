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
        ScrollView {
            VStack(spacing: 17) {
                VStack(alignment: .leading, spacing: 7) {
                    SingilanSectionTitle(text: "Invoice name")
                    TextField("Friday Dinner", text: $invoice.title).singilanField()
                }

                VStack(alignment: .leading, spacing: 7) {
                    SingilanSectionTitle(text: "Status")
                    Picker("Status", selection: $invoice.status) {
                        ForEach(InvoiceStatus.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    SingilanSectionTitle(text: "People")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 13) {
                            ForEach(invoice.participants.indices, id: \.self) { index in
                                VStack(spacing: 5) {
                                    ParticipantAvatar(name: invoice.participants[index], size: 48)
                                    TextField("Name", text: participantBinding(at: index))
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 68)
                                    Button(role: .destructive) {
                                        removeParticipants(at: IndexSet(integer: index))
                                    } label: { Image(systemName: "minus.circle.fill").font(.caption) }
                                }
                            }
                            Button {
                                invoice.participants.append("")
                            } label: {
                                VStack(spacing: 5) {
                                    Image(systemName: "plus")
                                        .font(.title3)
                                        .frame(width: 48, height: 48)
                                        .overlay(Circle().strokeBorder(SingilanTheme.green, style: StrokeStyle(lineWidth: 1.5, dash: [4])))
                                    Text("Add").font(.caption)
                                }
                            }
                            .disabled(invoice.participants.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SingilanSectionTitle(text: "Items")
                    SingilanCard {
                        ForEach(Array(invoice.items.indices), id: \.self) { index in
                            NavigationLink {
                                InvoiceItemEditorView(item: $invoice.items[index], participants: invoice.normalizedParticipants)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(invoice.items[index].name.isEmpty ? "Untitled item" : invoice.items[index].name).fontWeight(.semibold)
                                        Text(assignmentLabel(for: invoice.items[index])).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(invoice.items[index].amount, format: .currency(code: invoice.currency))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(invoice.items[index].isCreditLine ? SingilanTheme.green : .primary)
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                }
                                .padding(14)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { Button("Delete", role: .destructive) { invoice.items.remove(at: index) } }
                            if index < invoice.items.count - 1 { SingilanDivider() }
                        }
                        if !invoice.items.isEmpty { SingilanDivider() }
                        Button("Add item, credit, or charge", systemImage: "plus") {
                            invoice.items.append(InvoiceItem(name: "", shares: shareMapForAllParticipants()))
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SingilanSectionTitle(text: "Charges & payment")
                    SingilanCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Service charge").fontWeight(.semibold)
                                Text("Calculated from regular item subtotal").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            TextField("0", value: $desiredServicePercent, format: .number)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 50)
                            Text("%")
                        }.padding(14)
                        SingilanDivider()
                        if let qrData = paymentQRData, let image = UIImage(data: qrData) {
                            HStack {
                                Image(uiImage: image).resizable().interpolation(.none).scaledToFit().frame(width: 58, height: 58)
                                TextField("GCash, Maya, or bank", text: paymentQRLabel)
                                Button("Remove", role: .destructive) { invoice.paymentQr = nil; invoice.paymentQrLabel = nil }
                            }.padding(14)
                        } else {
                            PhotosPicker(selection: $selectedQRItem, matching: .images) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Payment QR").fontWeight(.semibold).foregroundStyle(.primary)
                                        Text("Shown on the shared bill").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("Add").foregroundStyle(SingilanTheme.green)
                                }.padding(14)
                            }
                        }
                    }
                }

                if !invoice.normalizedParticipants.isEmpty {
                    NavigationLink {
                        InvoiceSummaryView(invoice: invoice)
                    } label: {
                        Text("Review split").fontWeight(.bold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(SingilanTheme.green, in: RoundedRectangle(cornerRadius: 15))
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .singilanCanvas()
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
        invoice.revision += 1
        if invoiceStore.save(invoice), isNew {
            dismiss()
        }
    }

    private func assignmentLabel(for item: InvoiceItem) -> String {
        let names = invoice.participants.filter { item.shares[$0] == true && !$0.isEmpty }
        return names.isEmpty ? "No one selected" : names.joined(separator: ", ")
    }

    private func updateServiceCharge(percent: Decimal) {
        invoice = InvoiceOperations.applyingServiceCharge(percent: percent, to: invoice)
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

#Preview {
    NavigationStack {
        InvoiceEditorView(invoice: Invoice(title: "Friday dinner"))
    }
    .environmentObject(InvoiceStore.preview)
}
