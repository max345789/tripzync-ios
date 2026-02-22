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
    private let account = "access_token"

    private init() {}

    func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
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

    func readToken() -> String? {
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

    func clearToken() {
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

    private init(
        session: URLSession = .shared,
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
            guard let token = tokenStore.readToken(), !token.isEmpty else {
                DispatchQueue.main.async { [weak self] in
                    self?.unauthorizedHandler?()
                }
                throw NetworkError.unauthorized(message: "Please log in to continue.")
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: request)

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
                tokenStore.clearToken()
                DispatchQueue.main.async { [weak self] in
                    self?.unauthorizedHandler?()
                }
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
}
