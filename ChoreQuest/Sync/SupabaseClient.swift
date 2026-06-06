import Foundation

/// Tiny hand-rolled Supabase REST client (no SDK → keeps zero third-party deps).
/// Handles anonymous auth + token refresh (persisted in Keychain so the same
/// anonymous user — and thus household membership — survives relaunches), plus
/// PostgREST upsert/select and RPC. An `actor` so session state is race-free.
actor SupabaseClient {
    static let shared = SupabaseClient()

    struct Session: Codable {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
        var userId: UUID?
    }

    enum SupabaseError: LocalizedError {
        case http(Int, String)
        case noData
        var errorDescription: String? {
            switch self {
            case .http(let code, let msg): return "Supabase \(code): \(msg)"
            case .noData: return "No data from Supabase"
            }
        }
    }

    private let sessionKey = "supabase.session"
    private var session: Session?

    init() {
        if let data = Keychain.get(sessionKey),
           let saved = try? JSONDecoder().decode(Session.self, from: data) {
            session = saved
        }
    }

    var currentUserId: UUID? { session?.userId }

    func signOut() {
        session = nil
        Keychain.delete(sessionKey)
    }

    // MARK: - Auth

    private struct AuthResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Int?
        let expiresAt: Int?
        struct User: Decodable { let id: UUID }
        let user: User?
    }

    private func persist(_ newSession: Session) {
        session = newSession
        if let data = try? JSONEncoder().encode(newSession) {
            Keychain.set(data, for: sessionKey)
        }
    }

    private func decodeAuth(_ data: Data) throws -> AuthResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AuthResponse.self, from: data)
    }

    private func makeSession(_ response: AuthResponse) -> Session {
        let expiry: Date
        if let at = response.expiresAt {
            expiry = Date(timeIntervalSince1970: TimeInterval(at))
        } else {
            expiry = Date().addingTimeInterval(TimeInterval(response.expiresIn ?? 3600))
        }
        return Session(accessToken: response.accessToken,
                       refreshToken: response.refreshToken,
                       expiresAt: expiry,
                       userId: response.user?.id)
    }

    func signInAnonymously() async throws {
        var req = URLRequest(url: SupabaseConfig.authURL.appendingPathComponent("signup"))
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["data": [:]])
        persist(makeSession(try decodeAuth(try await send(req))))
    }

    private func refreshSession() async throws {
        guard let refreshToken = session?.refreshToken else {
            try await signInAnonymously(); return
        }
        var comps = URLComponents(url: SupabaseConfig.authURL.appendingPathComponent("token"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])
        do {
            persist(makeSession(try decodeAuth(try await send(req))))
        } catch {
            // Refresh token expired/invalid → fall back to a fresh anonymous user.
            try await signInAnonymously()
        }
    }

    /// Returns a valid access token, signing in / refreshing as needed.
    @discardableResult
    func ensureSession() async throws -> String {
        if session == nil { try await signInAnonymously() }
        if let current = session, current.expiresAt <= Date().addingTimeInterval(60) {
            try await refreshSession()
        }
        guard let token = session?.accessToken else { throw SupabaseError.noData }
        return token
    }

    // MARK: - HTTP

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseError.noData }
        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    private func authedRequest(_ url: URL, method: String) async throws -> URLRequest {
        let token = try await ensureSession()
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }

    // MARK: - PostgREST

    /// Upsert rows (insert or merge on the primary key).
    func upsert<T: Encodable>(_ rows: [T], into table: String, onConflict: String = "uuid") async throws {
        guard !rows.isEmpty else { return }
        var comps = URLComponents(url: SupabaseConfig.restURL.appendingPathComponent(table),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "on_conflict", value: onConflict)]
        var req = try await authedRequest(comps.url!, method: "POST")
        req.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try SupabaseCoding.encoder().encode(rows)
        _ = try await send(req)
    }

    func select<T: Decodable>(_ type: T.Type, from table: String, query: [URLQueryItem]) async throws -> [T] {
        var comps = URLComponents(url: SupabaseConfig.restURL.appendingPathComponent(table),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = query
        let req = try await authedRequest(comps.url!, method: "GET")
        return try SupabaseCoding.decoder().decode([T].self, from: try await send(req))
    }

    /// Calls a Postgres function that returns a single `households` row. Tolerates
    /// PostgREST returning either a single object or a one-element array.
    func householdRPC(_ function: String, args: [String: String] = [:]) async throws -> RemoteHousehold {
        let url = SupabaseConfig.restURL.appendingPathComponent("rpc").appendingPathComponent(function)
        var req = try await authedRequest(url, method: "POST")
        req.httpBody = try JSONSerialization.data(withJSONObject: args)
        let data = try await send(req)
        let decoder = SupabaseCoding.decoder()
        if let row = try? decoder.decode(RemoteHousehold.self, from: data) { return row }
        guard let first = try decoder.decode([RemoteHousehold].self, from: data).first else {
            throw SupabaseError.noData
        }
        return first
    }
}
