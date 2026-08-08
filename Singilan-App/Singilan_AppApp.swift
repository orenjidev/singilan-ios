//
//  Singilan_AppApp.swift
//  Singilan-App
//
//  Created by ORENJI on 8/7/26.
//

import SwiftUI

@main
struct Singilan_AppApp: App {
    @StateObject private var invoiceStore = InvoiceStore()
    @StateObject private var accountStore = AccountStore()

    var body: some Scene {
        WindowGroup {
            InvoiceListView()
                .environmentObject(invoiceStore)
                .environmentObject(accountStore)
                .task { await accountStore.refresh() }
        }
    }
}
