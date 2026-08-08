import Foundation
import Combine

struct SingilanUser: Codable, Equatable, Sendable {
    let id: String
    let username: String

    private enum CodingKeys: String, CodingKey { case id, username }

    init(id: String, username: String) {
        self.id = id
        self.username = username
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        username = try container.decode(String.self, forKey: .username)
        if let stringID = try? container.decode(String.self, forKey: .id) {
            id = stringID
        } else {
            id = String(try container.decode(Int.self, forKey: .id))
        }
    }
}

private struct LoginRequest: Encodable { let username: String; let code: String }

struct AuthenticationService: Sendable {
    let client: APIClient

    func login(username: String, code: String) async throws -> SingilanUser {
        try await client.send("api/auth/login", method: "POST", body: LoginRequest(username: username, code: code))
    }

    func currentUser() async throws -> SingilanUser {
        try await client.send("api/auth/me")
    }

    func logout() async throws {
        let _: LogoutResponse = try await client.send("api/auth/logout", method: "POST")
    }
}

private struct LogoutResponse: Decodable { let ok: Bool? }

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var user: SingilanUser?
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    private let authentication: AuthenticationService

    init(authentication: AuthenticationService? = nil) {
        self.authentication = authentication ?? AuthenticationService(client: APIClient(baseURL: AppEnvironment.apiBaseURL))
    }

    func refresh() async {
        do { user = try await authentication.currentUser() }
        catch { user = nil }
    }

    func login(username: String, code: String) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            user = try await authentication.login(username: username, code: code)
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func logout() async {
        isWorking = true
        defer { isWorking = false }
        do { try await authentication.logout(); user = nil }
        catch { errorMessage = error.localizedDescription }
    }
}
