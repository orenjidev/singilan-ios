import Foundation

enum InvoiceOperations {
    static func duplicate(_ invoice: Invoice, now: Date = .now) -> Invoice {
        var copy = invoice
        copy.id = UUID().uuidString
        copy.title += " (copy)"
        copy.status = .draft
        copy.createdAt = now
        copy.updatedAt = now
        copy.revision = 0
        copy.shareSlug = nil
        copy.items = copy.items.map { item in
            var copy = item
            copy.id = UUID().uuidString
            copy.payments = [:]
            return copy
        }
        return copy
    }

    static func grandTotals(for invoices: [Invoice]) -> [String: Decimal] {
        var totals: [String: Decimal] = [:]
        for invoice in invoices where invoice.status == .open {
            for balance in BillSplitter.balances(for: invoice) {
                totals[balance.userID, default: 0] += balance.owed
            }
        }
        return totals
    }

    static func csv(for invoice: Invoice) -> String {
        var lines = [
            "Invoice,\(escape(invoice.title))",
            "Status,\(escape(invoice.status.rawValue))",
            "Created,\(escape(ISO8601DateFormatter().string(from: invoice.createdAt)))",
            "",
            "Participants",
            "Name,Paid,Owed,Balance"
        ]

        let balances = Dictionary(uniqueKeysWithValues: BillSplitter.balances(for: invoice).map { ($0.userID, $0) })
        for participant in invoice.participants {
            let row = balances[participant] ?? ParticipantBalance(userID: participant, owed: 0, paid: 0)
            lines.append([escape(participant), amount(row.paid), amount(row.owed), amount(row.balance)].joined(separator: ","))
        }

        lines += ["", "Items", "Name,Amount,Shared With,Type"]
        for item in invoice.items {
            let sharedWith = invoice.participants.filter { item.shares[$0] == true }.joined(separator: "; ")
            let type = item.isCreditLine ? "credit" : item.isService ? "service" : "item"
            lines.append([escape(item.name), amount(item.amount), escape(sharedWith), type].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func amount(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue.contains(".")
            ? String(format: "%.2f", NSDecimalNumber(decimal: value).doubleValue)
            : "\(NSDecimalNumber(decimal: value).stringValue).00"
    }
}
