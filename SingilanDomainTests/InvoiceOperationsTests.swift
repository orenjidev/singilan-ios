import Foundation
import XCTest
@testable import SingilanDomain

final class InvoiceOperationsTests: XCTestCase {
    func testDecodesExistingWebInvoiceWithoutNativeMetadata() throws {
        let json = #"{"id":"web-1","title":"Web Bill","createdBy":"user-1","createdAt":"2026-08-08T02:00:00Z","status":"open","participants":["Ana"],"items":[{"id":"item-1","name":"Meal","quantity":1,"price":100,"shares":{"Ana":true},"payments":{}}]}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let invoice = try decoder.decode(Invoice.self, from: Data(json.utf8))
        XCTAssertEqual(invoice.id, "web-1")
        XCTAssertEqual(invoice.updatedAt, invoice.createdAt)
        XCTAssertEqual(invoice.revision, 0)
        XCTAssertEqual(invoice.currency, "PHP")
    }

    func testDuplicateResetsIdentityStatusShareAndPayments() {
        let original = Invoice(
            id: "original",
            title: "Dinner",
            status: .open,
            participants: ["Ana"],
            items: [InvoiceItem(id: "item", name: "Meal", price: 100, shares: ["Ana": true], payments: ["Ana": true])],
            revision: 9,
            shareSlug: "public-slug"
        )
        let date = Date(timeIntervalSince1970: 123)
        let copy = InvoiceOperations.duplicate(original, now: date)

        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertNotEqual(copy.items[0].id, original.items[0].id)
        XCTAssertEqual(copy.title, "Dinner (copy)")
        XCTAssertEqual(copy.status, .draft)
        XCTAssertEqual(copy.createdAt, date)
        XCTAssertEqual(copy.revision, 0)
        XCTAssertNil(copy.shareSlug)
        XCTAssertEqual(copy.items[0].payments, [:])
        XCTAssertEqual(copy.items[0].shares, original.items[0].shares)
    }

    func testGrandTotalsIncludeOnlyOpenInvoices() {
        let item = InvoiceItem(name: "Meal", price: 100, shares: ["Ana": true, "Ben": true])
        let open = Invoice(title: "Open", status: .open, participants: ["Ana", "Ben"], items: [item])
        let closed = Invoice(title: "Closed", status: .close, participants: ["Ana", "Ben"], items: [item])
        XCTAssertEqual(InvoiceOperations.grandTotals(for: [open, closed]), ["Ana": 50, "Ben": 50])
    }

    func testCSVContainsWebCompatibleSectionsAndEscaping() {
        let invoice = Invoice(
            title: "Dinner, Friday",
            status: .open,
            participants: ["Ana", "Ben"],
            items: [InvoiceItem(name: "Meal", price: 100, shares: ["Ana": true, "Ben": true])]
        )
        let csv = InvoiceOperations.csv(for: invoice)
        XCTAssertTrue(csv.contains("Invoice,\"Dinner, Friday\""))
        XCTAssertTrue(csv.contains("Name,Paid,Owed,Balance"))
        XCTAssertTrue(csv.contains("Ana,0.00,50.00,-50.00"))
        XCTAssertTrue(csv.contains("Name,Amount,Shared With,Type"))
        XCTAssertTrue(csv.contains("Meal,100.00,Ana; Ben,item"))
    }
}

@MainActor
final class InvoiceStoreHistoryTests: XCTestCase {
    func testUndoAndRedoRestoreRepositorySnapshots() {
        let repository = LocalInvoiceRepository(fileURL: nil)
        let store = InvoiceStore(repository: repository)
        let invoice = Invoice(title: "Dinner")

        XCTAssertTrue(store.save(invoice))
        XCTAssertEqual(store.invoices.count, 1)
        store.undo()
        XCTAssertTrue(store.invoices.isEmpty)
        store.redo()
        XCTAssertEqual(store.invoices.map(\.title), ["Dinner"])
    }
}
