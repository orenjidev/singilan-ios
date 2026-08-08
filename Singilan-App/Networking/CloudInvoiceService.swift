import Foundation

struct CloudInvoiceService: CloudInvoiceServicing, Sendable {
    let client: APIClient

    func getAll() async throws -> [Invoice] {
        try await client.send("api/v1/invoices")
    }

    func get(id: String) async throws -> Invoice {
        try await client.send("api/v1/invoices/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)")
    }

    @discardableResult
    func create(_ invoice: Invoice) async throws -> Invoice {
        try await client.send("api/v1/invoices", method: "POST", body: invoice)
    }

    @discardableResult
    func update(_ invoice: Invoice) async throws -> Invoice {
        try await client.send("api/v1/invoices/\(invoice.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? invoice.id)", method: "PUT", body: invoice)
    }

    func delete(id: String) async throws {
        try await client.sendWithoutResponse(
            "api/v1/invoices/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)",
            method: "DELETE"
        )
    }
}
