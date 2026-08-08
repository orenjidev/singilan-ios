import Foundation

struct APIError: Error, Decodable, LocalizedError {
    struct Detail: Decodable {
        let code: String
        let message: String
    }

    let error: Detail
    var errorDescription: String? { error.message }
}

protocol AccessTokenProviding: Sendable {
    func accessToken() async throws -> String?
}

struct APIClient: Sendable {
    let baseURL: URL
    let session: URLSession
    let tokenProvider: (any AccessTokenProviding)?

    init(
        baseURL: URL,
        session: URLSession = .shared,
        tokenProvider: (any AccessTokenProviding)? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
    }

    func send<Response: Decodable>(
        _ path: String,
        method: String = "GET",
        body: (any Encodable)? = nil
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = try await tokenProvider?.accessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONEncoder.api.encode(AnyEncodable(body))
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let apiError = try? JSONDecoder.api.decode(APIError.self, from: data) {
                throw apiError
            }
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder.api.decode(Response.self, from: data)
    }
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void
    init(_ value: any Encodable) { encodeValue = value.encode }
    func encode(to encoder: Encoder) throws { try encodeValue(encoder) }
}

private extension JSONEncoder {
    static var api: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var api: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
