import Foundation

enum InvoiceStatus: String, Codable, CaseIterable, Identifiable {
    case open
    case close
    case draft

    var id: Self { self }
    var label: String { self == .close ? "Closed" : rawValue.capitalized }
}

struct InvoiceItem: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var description: String?
    var quantity: Decimal
    var price: Decimal
    var shares: [String: Bool]
    var payments: [String: Bool]
    var isServiceCharge: Bool?
    var isCredit: Bool?
    var weights: [String: Decimal]?

    init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        quantity: Decimal = 1,
        price: Decimal = 0,
        shares: [String: Bool] = [:],
        payments: [String: Bool] = [:],
        isServiceCharge: Bool? = nil,
        isCredit: Bool? = nil,
        weights: [String: Decimal]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.quantity = quantity
        self.price = price
        self.shares = shares
        self.payments = payments
        self.isServiceCharge = isServiceCharge
        self.isCredit = isCredit
        self.weights = weights
    }

    var amount: Decimal { price * quantity }
    var isService: Bool { isServiceCharge == true }
    var isCreditLine: Bool { isCredit == true }
}

struct Invoice: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var createdBy: String
    var createdAt: Date
    var status: InvoiceStatus
    var participants: [String]
    var items: [InvoiceItem]
    var paymentQr: String?
    var paymentQrLabel: String?

    // Additive native metadata. Older web clients safely ignore these fields.
    var updatedAt: Date
    var revision: Int
    var currency: String
    var shareSlug: String?

    private enum CodingKeys: String, CodingKey {
        case id, title, createdBy, createdAt, status, participants, items
        case paymentQr, paymentQrLabel, updatedAt, revision, currency, shareSlug
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        createdBy: String = "guest",
        createdAt: Date = .now,
        status: InvoiceStatus = .draft,
        participants: [String] = [],
        items: [InvoiceItem] = [],
        paymentQr: String? = nil,
        paymentQrLabel: String? = nil,
        updatedAt: Date = .now,
        revision: Int = 0,
        currency: String = "PHP",
        shareSlug: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.status = status
        self.participants = participants
        self.items = items
        self.paymentQr = paymentQr
        self.paymentQrLabel = paymentQrLabel
        self.updatedAt = updatedAt
        self.revision = revision
        self.currency = currency
        self.shareSlug = shareSlug
    }

    var total: Decimal { items.reduce(0) { $0 + $1.amount } }
    var regularSubtotal: Decimal {
        items.filter { !$0.isService && !$0.isCreditLine }.reduce(0) { $0 + $1.amount }
    }

    var serviceChargeAmount: Decimal {
        items.filter(\.isService).reduce(0) { $0 + $1.amount }
    }

    var serviceChargePercent: Decimal {
        guard regularSubtotal != 0 else { return 0 }
        return serviceChargeAmount / regularSubtotal * 100
    }

    /// Participant names that are safe to use as dictionary and SwiftUI IDs.
    /// Empty and repeated names can exist temporarily while the editor is open.
    var normalizedParticipants: [String] {
        var seen = Set<String>()
        return participants.compactMap { rawName in
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seen.insert(name).inserted else { return nil }
            return name
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy) ?? "guest"
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        status = try container.decode(InvoiceStatus.self, forKey: .status)
        participants = try container.decode([String].self, forKey: .participants)
        items = try container.decode([InvoiceItem].self, forKey: .items)
        paymentQr = try container.decodeIfPresent(String.self, forKey: .paymentQr)
        paymentQrLabel = try container.decodeIfPresent(String.self, forKey: .paymentQrLabel)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 0
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "PHP"
        shareSlug = try container.decodeIfPresent(String.self, forKey: .shareSlug)
    }
}
