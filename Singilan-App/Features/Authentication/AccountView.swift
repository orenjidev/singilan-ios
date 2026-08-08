import SwiftUI

struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var invoiceStore: InvoiceStore
    @State private var username = ""
    @State private var code = ""
    @State private var isChoosingGuestMigration = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 17) {
                    SingilanCard {
                        VStack(spacing: 9) {
                            ParticipantAvatar(name: accountStore.user?.username ?? "Guest", size: 58)
                            Text(accountStore.user?.username ?? "Guest mode").font(.headline)
                            Text(accountStore.user == nil ? "Bills are safely stored on this iPhone" : "Connected to Singilan Na cloud")
                                .font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity).padding(22)
                    }

                    if accountStore.user == nil {
                        VStack(alignment: .leading, spacing: 8) {
                            SingilanSectionTitle(text: "Sign in")
                            TextField("Username", text: $username).textInputAutocapitalization(.never).singilanField()
                            SecureField("6-digit code", text: $code).keyboardType(.numberPad).singilanField()
                        }
                        Button {
                            Task {
                                if await accountStore.login(username: username, code: code) {
                                    if invoiceStore.isGuestScope && !invoiceStore.invoices.isEmpty {
                                        isChoosingGuestMigration = true
                                    } else {
                                        await connectToSignedInAccount(migrateGuestInvoices: false)
                                    }
                                }
                            }
                        } label: {
                            Text(accountStore.isWorking ? "Signing in…" : "Sign in")
                                .fontWeight(.bold).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).frame(height: 52)
                                .background(SingilanTheme.green, in: RoundedRectangle(cornerRadius: 15))
                        }
                        .disabled(accountStore.isWorking || username.count < 3 || code.count != 6)
                    } else {
                        Button("Sign out", role: .destructive) {
                            Task {
                                invoiceStore.switchScope(to: InvoiceStore.guestScope, migrateCurrent: false)
                                await accountStore.logout()
                            }
                        }
                            .buttonStyle(.bordered)
                    }

                    SingilanSectionTitle(text: "Cloud backup")
                    SingilanCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Invoice synchronization").fontWeight(.semibold)
                                if let lastSyncAt = invoiceStore.lastSyncAt {
                                    Text("Last synced \(lastSyncAt, format: .relative(presentation: .named))").font(.caption).foregroundStyle(.secondary)
                                } else {
                                    Text(accountStore.user == nil ? "Sign in to sync invoices" : "Ready to synchronize").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if invoiceStore.isSyncing { ProgressView() }
                            else { Text(accountStore.user == nil ? "Off" : "Ready").foregroundStyle(.secondary) }
                        }.padding(14)
                    }
                    if accountStore.user != nil {
                        Button("Sync now", systemImage: "arrow.triangle.2.circlepath") {
                            Task { _ = await invoiceStore.synchronize(using: CloudInvoiceService(client: APIClient(baseURL: AppEnvironment.apiBaseURL))) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(invoiceStore.isSyncing)
                    }
                }.padding(16)
            }
            .singilanCanvas()
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .alert("Account error", isPresented: Binding(get: { accountStore.errorMessage != nil }, set: { if !$0 { accountStore.errorMessage = nil } })) {
                Button("OK") { accountStore.errorMessage = nil }
            } message: { Text(accountStore.errorMessage ?? "Unknown error") }
            .confirmationDialog(
                "Move guest invoices to this account?",
                isPresented: $isChoosingGuestMigration,
                titleVisibility: .visible
            ) {
                Button("Move guest invoices") { Task { await connectToSignedInAccount(migrateGuestInvoices: true) } }
                Button("Keep guest invoices separate") { Task { await connectToSignedInAccount(migrateGuestInvoices: false) } }
                Button("Cancel", role: .cancel) { Task { await accountStore.logout() } }
            } message: {
                Text("Keeping them separate prevents invoices from one account being uploaded to another account.")
            }
        }
    }

    private func connectToSignedInAccount(migrateGuestInvoices: Bool) async {
        guard let user = accountStore.user else { return }
        invoiceStore.switchScope(to: user.id, migrateCurrent: migrateGuestInvoices)
        _ = await invoiceStore.synchronize(using: CloudInvoiceService(client: APIClient(baseURL: AppEnvironment.apiBaseURL)))
    }
}
