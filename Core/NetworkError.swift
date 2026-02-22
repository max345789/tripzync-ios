import Foundation

enum NetworkError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case decodingError
    case validation(message: String)
    case unauthorized(message: String)
    case forbidden(message: String)
    case notFound(message: String)
    case serverError(message: String)
    case httpError(statusCode: Int, code: String?, message: String)
    case connectivity(message: String)
    case unknown(message: String)

    var statusCode: Int? {
        switch self {
        case .unauthorized:
            return 401
        case .forbidden:
            return 403
        case .notFound:
            return 404
        case .serverError:
            return 500
        case .httpError(let statusCode, _, _):
            return statusCode
        default:
            return nil
        }
    }

    var userMessage: String {
        switch self {
        case .invalidURL:
            return "The server URL is invalid."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .decodingError:
            return "Failed to parse server response."
        case .validation(let message):
            return message
        case .unauthorized(let message):
            return message
        case .forbidden(let message):
            return message
        case .notFound(let message):
            return message
        case .serverError(let message):
            return message
        case .httpError(_, _, let message):
            return message
        case .connectivity(let message):
            return message
        case .unknown(let message):
            return message
        }
    }

    var isRetryable: Bool {
        switch self {
        case .connectivity, .serverError:
            return true
        case .httpError(let statusCode, _, _):
            return statusCode >= 500
        default:
            return false
        }
    }

    var title: String {
        switch statusCode {
        case 401:
            return "Session Expired"
        case 403:
            return "Permission Denied"
        case 404:
            return "Not Found"
        case 500:
            return "Server Error"
        default:
            if case .validation = self {
                return "Invalid Input"
            }
            return "Something Went Wrong"
        }
    }

    static func from(_ error: Error) -> NetworkError {
        if let networkError = error as? NetworkError {
            return networkError
        }

        let nsError = error as NSError
        if nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(EPERM) {
            return .connectivity(
                message: "Network access is blocked by app sandbox settings. Restart the app after enabling outgoing network access."
            )
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotFindHost:
                return .connectivity(
                    message: "Cannot find backend host. Verify API_BASE_URL and ensure the backend URL is reachable."
                )
            case .cannotConnectToHost:
                return .connectivity(
                    message: "Cannot connect to backend. Verify backend health and network access, then retry."
                )
            case .timedOut:
                return .connectivity(
                    message: "Request timed out. Check backend health and network, then retry."
                )
            case .notConnectedToInternet:
                return .connectivity(
                    message: "No network connection detected. Connect to a network and retry."
                )
            default:
                return .connectivity(message: urlError.localizedDescription)
            }
        }

        if nsError.localizedDescription.localizedCaseInsensitiveContains("operation not permitted") {
            return .connectivity(
                message: "Operation not permitted by system network policy. Restart the app and verify backend is reachable."
            )
        }

        return .unknown(message: error.localizedDescription)
    }
}
