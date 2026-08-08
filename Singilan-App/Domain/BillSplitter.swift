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
        var owed = Dictionary(uniqueKeysWithValues: invoice.participants.map { ($0, Decimal.zero) })
        var paid = Dictionary(uniqueKeysWithValues: invoice.participants.map { ($0, Decimal.zero) })

        for item in invoice.items {
            let sharers = invoice.participants.filter { item.shares[$0] == true }
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

        return invoice.participants.map {
            ParticipantBalance(userID: $0, owed: owed[$0] ?? 0, paid: paid[$0] ?? 0)
        }
    }

    static func amountsDue(for invoice: Invoice) -> [String: Decimal] {
        Dictionary(uniqueKeysWithValues: balances(for: invoice).map { ($0.userID, $0.owed) })
    }

    static func paidStatus(for invoice: Invoice) -> [String: Bool] {
        Dictionary(uniqueKeysWithValues: invoice.participants.map { participant in
            let hasUnpaidItem = invoice.items.contains {
                $0.shares[participant] == true && $0.payments[participant] != true && !$0.isCreditLine
            }
            return (participant, !hasUnpaidItem)
        })
    }
}
