import Foundation
import XCTest
@testable import SingilanDomain

final class LocalInvoiceRepositoryTests: XCTestCase {
    func testSaveUpdateSortAndDeleteRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "singilan-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalInvoiceRepository(fileURL: directory.appending(path: "invoices.json"))

        let older = Invoice(title: "Older", updatedAt: Date(timeIntervalSince1970: 100))
        var newer = Invoice(title: "Newer", updatedAt: Date(timeIntervalSince1970: 200))
        try repository.save(older)
        try repository.save(newer)
        XCTAssertEqual(try repository.getAll().map(\.title), ["Newer", "Older"])

        newer.title = "Updated"
        newer.status = .open
        try repository.save(newer)
        XCTAssertEqual(try repository.getAll().first?.title, "Updated")
        XCTAssertEqual(try repository.getAll().first?.status, .open)

        try repository.delete(id: older.id)
        XCTAssertEqual(try repository.getAll().map(\.id), [newer.id])
    }

    func testDatesArePersistedAsISO8601Strings() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "singilan-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appending(path: "invoices.json")
        let repository = LocalInvoiceRepository(fileURL: fileURL)
        try repository.save(Invoice(title: "ISO date"))

        let json = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(json.contains("T"))
        XCTAssertTrue(json.contains("Z"))
    }
}
