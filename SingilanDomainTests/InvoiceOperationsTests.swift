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

    func testSyncUploadsNewerLocalAndDownloadsCloudOnlyInvoice() async {
        let now = Date()
        let local = Invoice(id: "shared", title: "Local newest", updatedAt: now)
        let remoteOld = Invoice(id: "shared", title: "Remote old", updatedAt: now.addingTimeInterval(-60))
        let remoteOnly = Invoice(id: "remote", title: "From cloud", updatedAt: now)
        let repository = LocalInvoiceRepository(fileURL: nil, seed: [local])
        let cloud = MockCloudInvoiceService(invoices: [remoteOld, remoteOnly])
        let store = InvoiceStore(repository: repository)

        let succeeded = await store.synchronize(using: cloud)
        let updatedTitles = await cloud.updatedTitles()

        XCTAssertTrue(succeeded)
        XCTAssertEqual(Set(store.invoices.map(\.id)), ["shared", "remote"])
        XCTAssertEqual(updatedTitles, ["Local newest"])
    }

    func testSyncPropagatesPersistedDeletionWithoutResurrectingInvoice() async throws {
        let invoice = Invoice(id: "deleted", title: "Delete me")
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let tombstoneURL = directory.appending(path: "deleted.json")
        let repository = LocalInvoiceRepository(fileURL: nil, seed: [invoice])
        let cloud = MockCloudInvoiceService(invoices: [invoice])
        let store = InvoiceStore(repository: repository, scope: "account-1", tombstoneURL: tombstoneURL)

        store.delete(invoice)
        XCTAssertTrue(store.invoices.isEmpty)
        let succeeded = await store.synchronize(using: cloud)
        let deletedIDs = await cloud.deletedIDs()

        XCTAssertTrue(succeeded)
        XCTAssertTrue(store.invoices.isEmpty)
        XCTAssertEqual(deletedIDs, ["deleted"])
    }

    func testUndoDeletionAlsoRestoresCloudTombstoneState() async {
        let invoice = Invoice(id: "restored", title: "Restore me")
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let repository = LocalInvoiceRepository(fileURL: nil, seed: [invoice])
        let cloud = MockCloudInvoiceService(invoices: [invoice])
        let store = InvoiceStore(
            repository: repository,
            scope: "account-1",
            tombstoneURL: directory.appending(path: "deleted.json")
        )

        store.delete(invoice)
        store.undo()
        let succeeded = await store.synchronize(using: cloud)
        let deletedIDs = await cloud.deletedIDs()

        XCTAssertTrue(succeeded)
        XCTAssertEqual(store.invoices.map(\.id), ["restored"])
        XCTAssertTrue(deletedIDs.isEmpty)
    }

    func testServiceChargeUsesRegularItemSubtotalsAsWeights() {
        let invoice = Invoice(
            title: "Weighted service",
            participants: ["Ana", "Ben", "Cal"],
            items: [
                InvoiceItem(name: "Ana meal", price: 200, shares: ["Ana": true]),
                InvoiceItem(name: "Shared meal", price: 200, shares: ["Ana": true, "Ben": true])
            ]
        )

        let charged = InvoiceOperations.applyingServiceCharge(percent: 10, to: invoice)
        let service = try! XCTUnwrap(charged.items.first(where: \.isService))

        XCTAssertEqual(service.amount, 40)
        XCTAssertEqual(service.shares, ["Ana": true, "Ben": true, "Cal": false])
        XCTAssertEqual(service.weights, ["Ana": 300, "Ben": 100])
        let balances = BillSplitter.balances(for: charged)
        XCTAssertEqual(balances.first(where: { $0.userID == "Ana" })?.owed, 330)
        XCTAssertEqual(balances.first(where: { $0.userID == "Ben" })?.owed, 110)
        XCTAssertEqual(balances.first(where: { $0.userID == "Cal" })?.owed, 0)
    }
}

private actor MockCloudInvoiceService: CloudInvoiceServicing {
    private var invoices: [Invoice]
    private var updates: [Invoice] = []
    private var deletions: [String] = []

    init(invoices: [Invoice]) { self.invoices = invoices }

    func getAll() async throws -> [Invoice] { invoices }
    func create(_ invoice: Invoice) async throws -> Invoice {
        invoices.append(invoice)
        return invoice
    }
    func update(_ invoice: Invoice) async throws -> Invoice {
        updates.append(invoice)
        return invoice
    }
    func delete(id: String) async throws {
        deletions.append(id)
        invoices.removeAll { $0.id == id }
    }
    func updatedTitles() -> [String] { updates.map(\.title) }
    func deletedIDs() -> [String] { deletions }
}
