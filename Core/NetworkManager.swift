import Foundation
import Security

enum HTTPMethod: String {
    case GET
    case POST
    case PATCH
    case DELETE
}

struct APIErrorPayload: Decodable {
    let code: String
    let message: String
}

struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let meta: PaginationMeta?
    let error: APIErrorPayload?
}

struct EmptyPayload: Decodable {}

struct APIResult<T: Decodable> {
    let data: T
    let meta: PaginationMeta?
}

enum AppConfiguration {
    static var apiBaseURLString: String {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !configured.isEmpty {
            return configured
        }

        if let injected = ProcessInfo.processInfo.environment["TRIPZYNC_API_BASE_URL"],
           !injected.isEmpty {
            return injected
        }

        return "https://tripzync.onrender.com"
    }
}

final class KeychainTokenStore {
    static let shared = KeychainTokenStore()

    private let service = "com.tripzync.auth"
    private let accessAccount = "access_token"
    private let refreshAccount = "refresh_token"

    private init() {}

    func saveAccessToken(_ token: String) throws {
        try upsert(value: token, account: accessAccount)
    }

    func saveRefreshToken(_ token: String) throws {
        try upsert(value: token, account: refreshAccount)
    }

    func saveTokens(accessToken: String, refreshToken: String?) throws {
        try saveAccessToken(accessToken)
        if let refreshToken, !refreshToken.isEmpty {
            try saveRefreshToken(refreshToken)
        }
    }

    func saveToken(_ token: String) throws {
        try saveAccessToken(token)
    }

    func readAccessToken() -> String? {
        readValue(account: accessAccount)
    }

    func readRefreshToken() -> String? {
        readValue(account: refreshAccount)
    }

    func readToken() -> String? {
        readAccessToken()
    }

    func clearAccessToken() {
        deleteValue(account: accessAccount)
    }

    func clearRefreshToken() {
        deleteValue(account: refreshAccount)
    }

    func clearAllTokens() {
        clearAccessToken()
        clearRefreshToken()
    }

    func clearToken() {
        clearAccessToken()
    }

    private func upsert(value: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        var createQuery = query
        createQuery[kSecValueData as String] = data
        createQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let createStatus = SecItemAdd(createQuery as CFDictionary, nil)
        guard createStatus == errSecSuccess else {
            throw NetworkError.unknown(message: "Unable to save token to Keychain.")
        }
    }

    private func readValue(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    private func deleteValue(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}

final class NetworkManager {

    static let shared = NetworkManager()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let tokenStore: KeychainTokenStore
    private let baseURL: URL

    private var unauthorizedHandler: (() -> Void)?
    private var refreshTask: Task<Bool, Never>?

    private struct HealthPayload: Decodable {
        let status: String
        let environment: String?
    }

    private init(
        session: URLSession = NetworkManager.makeSession(),
        tokenStore: KeychainTokenStore = .shared,
        baseURLString: String = AppConfiguration.apiBaseURLString
    ) {
        self.session = session
        self.tokenStore = tokenStore

        let configuredURL = URL(string: baseURLString) ?? URL(string: "https://tripzync.onrender.com")!
        self.baseURL = configuredURL

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 90
        configuration.timeoutIntervalForResource = 150
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }

    private func shouldRetry(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet:
            return true
        default:
            return false
        }
    }

    private func sendWithRetry(
        _ request: URLRequest,
        retries: Int = 1
    ) async throws -> (Data, URLResponse) {
        var attempt = 0
        while true {
            do {
                return try await session.data(for: request)
            } catch let error as URLError {
                if attempt < retries && shouldRetry(error) {
                    attempt += 1
                    try? await Task.sleep(nanoseconds: UInt64(250_000_000 * attempt))
                    continue
                }
                throw error
            }
        }
    }

    func setUnauthorizedHandler(_ handler: @escaping () -> Void) {
        unauthorizedHandler = handler
    }

    func encodeBody<T: Encodable>(_ body: T) throws -> Data {
        do {
            return try encoder.encode(body)
        } catch {
            throw NetworkError.decodingError
        }
    }

    func request<T: Decodable>(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        requiresAuth: Bool = true
    ) async throws -> APIResult<T> {
        try await requestInternal(
            path: path,
            method: method,
            queryItems: queryItems,
            body: body,
            requiresAuth: requiresAuth,
            allowTokenRefresh: true
        )
    }

    func request<T: Decodable>(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        requiresAuth: Bool = true,
        allowTokenRefresh: Bool
    ) async throws -> APIResult<T> {
        try await requestInternal(
            path: path,
            method: method,
            queryItems: queryItems,
            body: body,
            requiresAuth: requiresAuth,
            allowTokenRefresh: allowTokenRefresh
        )
    }

    func refreshAccessTokenIfNeeded() async -> Bool {
        await refreshAccessToken()
    }

    func warmUp() async {
        do {
            let _: APIResult<HealthPayload> = try await request(
                path: "health",
                method: .GET,
                requiresAuth: false,
                allowTokenRefresh: false
            )
        } catch {
            // Best effort warm-up call; ignore failures.
        }
    }

    private func requestInternal<T: Decodable>(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem],
        body: Data?,
        requiresAuth: Bool,
        allowTokenRefresh: Bool
    ) async throws -> APIResult<T> {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw NetworkError.invalidURL
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body

        if requiresAuth {
            var token = tokenStore.readAccessToken()
            if (token == nil || token?.isEmpty == true) && allowTokenRefresh {
                let refreshed = await refreshAccessToken()
                if refreshed {
                    token = tokenStore.readAccessToken()
                }
            }

            guard let token, !token.isEmpty else {
                handleUnauthorized()
                throw NetworkError.unauthorized(message: "Please log in to continue.")
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let canRetryRequest = method == .GET && request.httpBody == nil
            let (data, response) = try await sendWithRetry(request, retries: canRetryRequest ? 1 : 0)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            if (200...299).contains(httpResponse.statusCode) {
                do {
                    let envelope = try decoder.decode(APIEnvelope<T>.self, from: data)

                    guard envelope.success, let payload = envelope.data else {
                        let message = envelope.error?.message ?? "Invalid API response payload."
                        throw NetworkError.unknown(message: message)
                    }

                    return APIResult(data: payload, meta: envelope.meta)
                } catch let error as NetworkError {
                    throw error
                } catch {
                    throw NetworkError.decodingError
                }
            }

            let decodedErrorEnvelope = try? decoder.decode(APIEnvelope<EmptyPayload>.self, from: data)
            let backendCode = decodedErrorEnvelope?.error?.code
            let backendMessage = decodedErrorEnvelope?.error?.message

            switch httpResponse.statusCode {
            case 401:
                if requiresAuth && allowTokenRefresh {
                    let refreshed = await refreshAccessToken()
                    if refreshed {
                        return try await requestInternal(
                            path: path,
                            method: method,
                            queryItems: queryItems,
                            body: body,
                            requiresAuth: requiresAuth,
                            allowTokenRefresh: false
                        )
                    }
                }

                handleUnauthorized()
                throw NetworkError.unauthorized(
                    message: backendMessage ?? "Your session expired. Please log in again."
                )
            case 403:
                throw NetworkError.forbidden(
                    message: backendMessage ?? "You don't have permission to access this trip."
                )
            case 404:
                throw NetworkError.notFound(
                    message: backendMessage ?? "Requested resource was not found."
                )
            case 500...599:
                throw NetworkError.serverError(
                    message: backendMessage ?? "Server error. Please try again."
                )
            default:
                throw NetworkError.httpError(
                    statusCode: httpResponse.statusCode,
                    code: backendCode,
                    message: backendMessage ?? "Request failed with status \(httpResponse.statusCode)."
                )
            }
        } catch let error as NetworkError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .cannotFindHost:
                throw NetworkError.connectivity(
                    message: "Unable to resolve backend host. Check API base URL and backend availability."
                )
            case .cannotConnectToHost:
                throw NetworkError.connectivity(
                    message: "Unable to connect to backend at \(baseURL.absoluteString). Ensure the service is reachable."
                )
            case .timedOut:
                throw NetworkError.connectivity(
                    message: "Backend request timed out. Please retry."
                )
            default:
                throw NetworkError.connectivity(message: error.localizedDescription)
            }
        } catch {
            throw NetworkError.unknown(message: error.localizedDescription)
        }
    }

    private func refreshAccessToken() async -> Bool {
        if let refreshTask {
            return await refreshTask.value
        }

        let task = Task { [weak self] () -> Bool in
            guard let self else { return false }
            guard let refreshToken = self.tokenStore.readRefreshToken(), !refreshToken.isEmpty else {
                return false
            }

            do {
                let requestBody = try self.encodeBody(RefreshTokenRequest(refreshToken: refreshToken))
                let result: APIResult<AuthResponse> = try await self.requestInternal(
                    path: "api/auth/refresh",
                    method: .POST,
                    queryItems: [],
                    body: requestBody,
                    requiresAuth: false,
                    allowTokenRefresh: false
                )

                try self.tokenStore.saveTokens(
                    accessToken: result.data.accessToken,
                    refreshToken: result.data.refreshToken
                )
                return true
            } catch {
                self.tokenStore.clearAllTokens()
                return false
            }
        }

        refreshTask = task
        let didRefresh = await task.value
        refreshTask = nil
        return didRefresh
    }

    private func handleUnauthorized() {
        tokenStore.clearAllTokens()
        DispatchQueue.main.async { [weak self] in
            self?.unauthorizedHandler?()
        }
    }
}
