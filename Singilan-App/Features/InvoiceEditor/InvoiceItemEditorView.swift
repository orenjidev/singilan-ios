import SwiftUI

struct InvoiceItemEditorView: View {
    @Binding var item: InvoiceItem
    let participants: [String]

    var body: some View {
        Form {
            Section("Item") {
                TextField("Name", text: $item.name)
                TextField("Description", text: description)
                TextField("Quantity", value: $item.quantity, format: .number)
                    .keyboardType(.decimalPad)
                TextField("Unit price", value: $item.price, format: .number)
                    .keyboardType(.decimalPad)
                Toggle("Credit", isOn: creditBinding)
                Toggle("Service charge", isOn: serviceBinding)
            }

            Section("Shared by") {
                if participants.isEmpty {
                    Text("Add people to the invoice first.").foregroundStyle(.secondary)
                } else {
                    ForEach(participants, id: \.self) { participant in
                        VStack {
                            Button { toggleShare(participant) } label: {
                                HStack {
                                    Text(participant.isEmpty ? "Unnamed person" : participant)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if item.shares[participant] == true { Image(systemName: "checkmark") }
                                }
                            }
                            if item.shares[participant] == true {
                                HStack {
                                    Text("Weight").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    TextField("1", value: weightBinding(for: participant), format: .number)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(maxWidth: 80)
                                }
                            }
                        }
                    }
                }
            }

            if item.isCreditLine == false {
                Section("Payments") {
                    ForEach(participants.filter { item.shares[$0] == true }, id: \.self) { participant in
                        Toggle("\(participant) paid", isOn: paymentBinding(for: participant))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .singilanCanvas()
        .tint(SingilanTheme.green)
        .navigationTitle(item.name.isEmpty ? "New Item" : item.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var description: Binding<String> {
        Binding(get: { item.description ?? "" }, set: { item.description = $0.isEmpty ? nil : $0 })
    }

    private var creditBinding: Binding<Bool> {
        Binding(get: { item.isCreditLine }, set: { enabled in
            item.isCredit = enabled ? true : nil
            if enabled {
                item.isServiceCharge = nil
                item.price = -abs(item.price)
                item.payments = [:]
            } else {
                item.price = abs(item.price)
            }
        })
    }

    private var serviceBinding: Binding<Bool> {
        Binding(get: { item.isService }, set: { enabled in
            item.isServiceCharge = enabled ? true : nil
            if enabled {
                item.isCredit = nil
                item.price = abs(item.price)
            }
        })
    }

    private func toggleShare(_ participant: String) {
        if item.isCreditLine {
            item.shares = participants.reduce(into: [:]) { $0[$1] = ($1 == participant) }
            item.payments = [:]
            item.weights = nil
            return
        }
        let selected = item.shares[participant] == true
        item.shares[participant] = !selected
        if selected {
            item.payments.removeValue(forKey: participant)
            item.weights?.removeValue(forKey: participant)
        }
    }

    private func weightBinding(for participant: String) -> Binding<Decimal> {
        Binding(get: { item.weights?[participant] ?? 0 }, set: { value in
            if item.weights == nil { item.weights = [:] }
            item.weights?[participant] = max(value, 0)
        })
    }

    private func paymentBinding(for participant: String) -> Binding<Bool> {
        Binding(get: { item.payments[participant] == true }, set: { item.payments[participant] = $0 })
    }
}
