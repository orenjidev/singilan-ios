import Foundation

struct ParticipantBalance: Identifiable, Hashable {
    let userID: String
    let owed: Decimal
    let paid: Decimal

    var id: String { userID }
    var balance: Decimal { paid - owed }
}

enum BillSplitter {
    /// Direct Swift port of `calculateInvoiceSplit` from the web application.
    static func balances(for invoice: Invoice) -> [ParticipantBalance] {
        let participants = invoice.normalizedParticipants
        var owed = participants.reduce(into: [String: Decimal]()) { $0[$1] = 0 }
        var paid = participants.reduce(into: [String: Decimal]()) { $0[$1] = 0 }

        for item in invoice.items {
            let sharers = participants.filter { item.shares[$0] == true }
            guard !sharers.isEmpty else { continue }

            let weightedSharers = sharers.filter { (item.weights?[$0] ?? 0) > 0 }
            let weightSum = weightedSharers.reduce(Decimal.zero) { $0 + (item.weights?[$1] ?? 0) }

            if !weightedSharers.isEmpty, weightSum > 0 {
                for user in weightedSharers {
                    let share = item.amount * (item.weights?[user] ?? 0) / weightSum
                    owed[user, default: 0] += share
                    if item.payments[user] == true { paid[user, default: 0] += share }
                }
            } else {
                let share = item.amount / Decimal(sharers.count)
                for user in sharers {
                    owed[user, default: 0] += share
                    if item.payments[user] == true { paid[user, default: 0] += share }
                }
            }
        }

        return participants.map {
            ParticipantBalance(userID: $0, owed: owed[$0] ?? 0, paid: paid[$0] ?? 0)
        }
    }

    static func amountsDue(for invoice: Invoice) -> [String: Decimal] {
        balances(for: invoice).reduce(into: [:]) { $0[$1.userID] = $1.owed }
    }

    static func paidStatus(for invoice: Invoice) -> [String: Bool] {
        invoice.normalizedParticipants.reduce(into: [String: Bool]()) { result, participant in
            let hasUnpaidItem = invoice.items.contains {
                $0.shares[participant] == true && $0.payments[participant] != true && !$0.isCreditLine
            }
            result[participant] = !hasUnpaidItem
        }
    }
}
