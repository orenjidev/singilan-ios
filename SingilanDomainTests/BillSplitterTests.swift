import XCTest
@testable import SingilanDomain

final class BillSplitterTests: XCTestCase {
    func testBlankAndDuplicateParticipantsDoNotCrashOrDuplicateBalances() {
        let invoice = Invoice(
            title: "Editing",
            participants: ["", "Ana", "", " Ana ", "Ben", "Ben"],
            items: [InvoiceItem(name: "Meal", price: 100, shares: ["Ana": true, "Ben": true])]
        )

        let balances = BillSplitter.balances(for: invoice)

        XCTAssertEqual(balances.map(\.userID), ["Ana", "Ben"])
        XCTAssertEqual(balances.map(\.owed), [50, 50])
        XCTAssertEqual(BillSplitter.paidStatus(for: invoice).count, 2)
    }

    func testEvenSplitTracksOwedPaidAndBalance() {
        let invoice = Invoice(
            title: "Dinner",
            participants: ["Ana", "Ben"],
            items: [InvoiceItem(
                name: "Meal",
                quantity: 2,
                price: 100,
                shares: ["Ana": true, "Ben": true],
                payments: ["Ana": true]
            )]
        )

        let balances = BillSplitter.balances(for: invoice)
        XCTAssertEqual(balances[0], ParticipantBalance(userID: "Ana", owed: 100, paid: 100))
        XCTAssertEqual(balances[0].balance, 0)
        XCTAssertEqual(balances[1], ParticipantBalance(userID: "Ben", owed: 100, paid: 0))
        XCTAssertEqual(balances[1].balance, -100)
    }

    func testWeightedSplitMatchesWebRulesAndExcludesZeroWeightSharers() {
        let invoice = Invoice(
            title: "Weighted",
            participants: ["Ana", "Ben", "Cal"],
            items: [InvoiceItem(
                name: "Room",
                price: 900,
                shares: ["Ana": true, "Ben": true, "Cal": true],
                weights: ["Ana": 1, "Ben": 2, "Cal": 0]
            )]
        )

        let balances = BillSplitter.balances(for: invoice)
        XCTAssertEqual(balances.map(\.owed), [300, 600, 0])
    }

    func testAllZeroWeightsFallBackToEvenSplit() {
        let invoice = Invoice(
            title: "Fallback",
            participants: ["Ana", "Ben"],
            items: [InvoiceItem(
                name: "Taxi",
                price: 100,
                shares: ["Ana": true, "Ben": true],
                weights: ["Ana": 0, "Ben": 0]
            )]
        )

        XCTAssertEqual(BillSplitter.balances(for: invoice).map(\.owed), [50, 50])
    }

    func testCreditUsesNegativeLineAmountWithoutSpecialCaseMath() {
        let invoice = Invoice(
            title: "Credit",
            participants: ["Ana", "Ben"],
            items: [
                InvoiceItem(name: "Meal", price: 200, shares: ["Ana": true, "Ben": true]),
                InvoiceItem(name: "Ana prepayment", price: -40, shares: ["Ana": true], isCredit: true)
            ]
        )

        XCTAssertEqual(invoice.total, 160)
        XCTAssertEqual(BillSplitter.balances(for: invoice).map(\.owed), [60, 100])
    }

    func testServiceChargeIsSplitLikeAnyOtherLineItem() {
        let invoice = Invoice(
            title: "Service",
            participants: ["Ana", "Ben"],
            items: [
                InvoiceItem(name: "Meal", price: 200, shares: ["Ana": true, "Ben": true]),
                InvoiceItem(name: "Service charge", price: 20, shares: ["Ana": true, "Ben": true], isServiceCharge: true)
            ]
        )

        XCTAssertEqual(invoice.regularSubtotal, 200)
        XCTAssertEqual(invoice.serviceChargeAmount, 20)
        XCTAssertEqual(invoice.serviceChargePercent, 10)
        XCTAssertEqual(BillSplitter.balances(for: invoice).map(\.owed), [110, 110])
    }

    func testPaidStatusIgnoresUnpaidCreditLines() {
        let invoice = Invoice(
            title: "Paid status",
            participants: ["Ana", "Ben"],
            items: [
                InvoiceItem(name: "Meal", price: 100, shares: ["Ana": true, "Ben": true], payments: ["Ana": true]),
                InvoiceItem(name: "Credit", price: -10, shares: ["Ana": true], isCredit: true)
            ]
        )

        XCTAssertEqual(BillSplitter.paidStatus(for: invoice), ["Ana": true, "Ben": false])
    }
}
