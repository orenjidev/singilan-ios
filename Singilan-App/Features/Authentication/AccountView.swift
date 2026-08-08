import SwiftUI

struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountStore: AccountStore
    @State private var username = ""
    @State private var code = ""

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
                            Task { if await accountStore.login(username: username, code: code) { dismiss() } }
                        } label: {
                            Text(accountStore.isWorking ? "Signing in…" : "Sign in")
                                .fontWeight(.bold).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).frame(height: 52)
                                .background(SingilanTheme.green, in: RoundedRectangle(cornerRadius: 15))
                        }
                        .disabled(accountStore.isWorking || username.count < 3 || code.count != 6)
                    } else {
                        Button("Sign out", role: .destructive) { Task { await accountStore.logout() } }
                            .buttonStyle(.bordered)
                    }

                    SingilanSectionTitle(text: "Cloud backup")
                    SingilanCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Invoice synchronization").fontWeight(.semibold)
                                Text("Available after backend v1 is deployed").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Off").foregroundStyle(.secondary)
                        }.padding(14)
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
        }
    }
}
