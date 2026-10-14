import Foundation
import Security

/// Project URL and publishable (anon) key from a git-ignored `Supabase.plist` in the app bundle.
/// The anon key is public by design; authority comes from database RLS. A service-role key must never be bundled.
struct SupabaseConfig: Sendable, Equatable {
    let url: URL
    let anonKey: String

    static func bundled(_ bundle: Bundle = .main) -> SupabaseConfig? {
        guard let file = bundle.url(forResource: "Supabase", withExtension: "plist"),
              let values = NSDictionary(contentsOf: file) as? [String: String],
              let raw = values["SUPABASE_URL"], let url = URL(string: raw), url.scheme == "https",
              let key = values["SUPABASE_ANON_KEY"], !key.isEmpty, !key.contains("service_role") else { return nil }
        return SupabaseConfig(url: url, anonKey: key)
    }
}

struct CommunitySession: Codable, Sendable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userID: UUID
}

enum CommunityError: LocalizedError, Equatable {
    case signedOut, notFound, forbidden, invalidInput(String), server(String), offline

    var errorDescription: String? {
        switch self {
        case .signedOut: "Sign in to do this."
        case .notFound: "That item is no longer available."
        case .forbidden: "You don't have permission to do that."
        case .invalidInput(let message): message
        case .server(let message): message
        case .offline: "You're offline. Nothing was changed; try again when connected."
        }
    }
}

/// Minimal Supabase Auth + PostgREST client over URLSession. Sessions live in the Keychain.
actor SupabaseClient {
    private let config: SupabaseConfig
    private let session: URLSession
    private let keychainAccount: String
    private var current: CommunitySession?

    init(config: SupabaseConfig, session: URLSession = .shared, keychainAccount: String = "supabase-session") {
        self.config = config
        self.session = session
        self.keychainAccount = keychainAccount
        current = Keychain.read(account: keychainAccount).flatMap { try? JSONDecoder().decode(CommunitySession.self, from: $0) }
    }

    var userID: UUID? { current?.userID }

    // MARK: Auth

    private struct AuthResponse: Decodable {
        struct User: Decodable { let id: UUID }
        let access_token: String?
        let refresh_token: String?
        let expires_in: Double?
        let user: User?
    }

    func signUp(email: String, password: String, username: String) async throws -> CommunitySession {
        try await authenticate(path: "auth/v1/signup", body: ["email": email, "password": password, "data": ["username": username]])
    }

    func signIn(email: String, password: String) async throws -> CommunitySession {
        try await authenticate(path: "auth/v1/token?grant_type=password", body: ["email": email, "password": password])
    }

    func signOut() async {
        if let token = current?.accessToken {
            var request = URLRequest(url: config.url.appending(path: "auth/v1/logout"))
            request.httpMethod = "POST"
            request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await session.data(for: request)
        }
        store(nil)
    }

    func validSession() async throws -> CommunitySession? {
        guard let existing = current else { return nil }
        guard existing.expiresAt.timeIntervalSinceNow < 60 else { return existing }
        do {
            return try await authenticate(path: "auth/v1/token?grant_type=refresh_token", body: ["refresh_token": existing.refreshToken])
        } catch CommunityError.offline {
            throw CommunityError.offline
        } catch {
            store(nil) // revoked or expired refresh token: sign out rather than act with a stale identity
            return nil
        }
    }

    private func authenticate(path: String, body: [String: Any]) async throws -> CommunitySession {
        var request = URLRequest(url: URL(string: path, relativeTo: config.url)!)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await send(request)
        try Self.check(response, data)
        let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
        guard let access = decoded.access_token, let refresh = decoded.refresh_token, let user = decoded.user else {
            throw CommunityError.server("Account created, but email confirmation is required before signing in.")
        }
        let session = CommunitySession(accessToken: access, refreshToken: refresh, expiresAt: Date().addingTimeInterval(decoded.expires_in ?? 3600), userID: user.id)
        store(session)
        return session
    }

    private func store(_ session: CommunitySession?) {
        current = session
        if let session, let data = try? JSONEncoder().encode(session) { Keychain.write(data, account: keychainAccount) }
        else { Keychain.delete(account: keychainAccount) }
    }

    // MARK: PostgREST

    struct Page<Row: Decodable & Sendable>: Sendable { let rows: [Row]; let total: Int? }

    func select<Row: Decodable & Sendable>(_ table: String, query: [URLQueryItem], count: Bool = false, as: Row.Type = Row.self) async throws -> Page<Row> {
        var request = try await restRequest(table, query: query)
        if count { request.setValue("count=exact", forHTTPHeaderField: "Prefer") }
        let (data, response) = try await send(request)
        try Self.check(response, data)
        let total = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Range")?.split(separator: "/").last.flatMap { Int($0) }
        return Page(rows: try Self.decoder.decode([Row].self, from: data), total: total)
    }

    /// Insert or upsert JSON rows; returns representation rows when requested.
    @discardableResult
    func insert<Row: Decodable & Sendable>(_ table: String, select: String, _ body: [String: Any], upsertOn conflict: String? = nil, returning: Row.Type = Row.self) async throws -> [Row] {
        var query = [URLQueryItem(name: "select", value: select)]
        if let conflict { query.append(URLQueryItem(name: "on_conflict", value: conflict)) }
        var request = try await restRequest(table, query: query, method: "POST")
        request.setValue(conflict == nil ? "return=representation" : "return=representation,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await send(request)
        try Self.check(response, data)
        return try Self.decoder.decode([Row].self, from: data)
    }

    func delete(_ table: String, query: [URLQueryItem]) async throws {
        let request = try await restRequest(table, query: query, method: "DELETE")
        let (data, response) = try await send(request)
        try Self.check(response, data)
    }

    func rpc(_ function: String, _ body: [String: Any]) async throws {
        var request = try await restRequest("rpc/\(function)", query: [], method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await send(request)
        try Self.check(response, data)
    }

    func rpcValue<Value: Decodable>(_ function: String, as: Value.Type) async throws -> Value {
        var request = try await restRequest("rpc/\(function)", query: [], method: "POST")
        request.httpBody = Data("{}".utf8)
        let (data, response) = try await send(request)
        try Self.check(response, data)
        return try Self.decoder.decode(Value.self, from: data)
    }

    private func restRequest(_ path: String, query: [URLQueryItem], method: String = "GET") async throws -> URLRequest {
        var components = URLComponents(url: config.url.appending(path: "rest/v1/\(path)"), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        // PostgREST filters need literal '+' kept out of the space encoding.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        let token = try await validSession()?.accessToken ?? config.anonKey
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do { return try await session.data(for: request) }
        catch let error as URLError where [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost].contains(error.code) {
            throw CommunityError.offline
        }
    }

    private static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw CommunityError.server("No response from the server.") }
        guard !(200..<300).contains(http.statusCode) else { return }
        let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let message = (body?["message"] ?? body?["msg"] ?? body?["error_description"]) as? String ?? "Server error \(http.statusCode)."
        switch http.statusCode {
        case 401, 403: throw message.lowercased().contains("invalid login") ? CommunityError.invalidInput("Email or password is incorrect.") : CommunityError.forbidden
        case 404: throw CommunityError.notFound
        case 400, 409, 422:
            if message.contains("profiles_username_key") || message.lowercased().contains("already registered") {
                throw CommunityError.invalidInput("That username or email is already in use.")
            }
            throw CommunityError.invalidInput(message)
        default: throw CommunityError.server(message)
        }
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            for format in [Date.ISO8601FormatStyle(includingFractionalSeconds: true), .init()] {
                if let date = try? Date(raw, strategy: format) { return date }
            }
            // Postgres timestamptz may use a space separator and a short offset.
            let normalized = raw.replacingOccurrences(of: " ", with: "T").replacingOccurrences(of: #"([+-]\d{2})$"#, with: "$1:00", options: .regularExpression)
            if let date = (try? Date(normalized, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))) ?? (try? Date(normalized, strategy: .iso8601)) { return date }
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Unrecognised date \(raw)")
        }
        return decoder
    }()
}

private enum Keychain {
    private static let service = "com.thirdspace.app.community"

    static func read(account: String) -> Data? {
        var result: AnyObject?
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: account, kSecReturnData as String: true]
        return SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess ? result as? Data : nil
    }

    static func write(_ data: Data, account: String) {
        delete(account: account)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: account, kSecValueData as String: data,
                                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func delete(account: String) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] as CFDictionary)
    }
}
