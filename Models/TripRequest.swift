import Foundation

enum BudgetTier: String, CaseIterable, Codable, Hashable {
    case low
    case moderate
    case luxury

    var displayName: String {
        switch self {
        case .low:
            return "Budget"
        case .moderate:
            return "Moderate"
        case .luxury:
            return "Luxury"
        }
    }

    static func fromDisplayName(_ value: String) -> BudgetTier {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "budget", "low":
            return .low
        case "moderate", "medium":
            return .moderate
        case "luxury", "premium":
            return .luxury
        default:
            return .moderate
        }
    }

    static func fromBackend(_ value: String) -> BudgetTier {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return BudgetTier(rawValue: normalized) ?? .moderate
    }
}

struct TripGenerateRequest: Codable, Hashable {
    let destination: String
    let days: Int
    let budget: String
    let startCity: String?
}

struct TripUpdateRequest: Codable, Hashable {
    let destination: String?
    let days: Int?
    let budget: String?
    let startCity: String?
}

struct TripRegenerateRequest: Codable, Hashable {
    let days: Int?
    let budget: String?
}

struct TripDeleteResponse: Codable, Hashable {
    let id: String
    let deleted: Bool
}

struct AuthUser: Codable, Hashable {
    let id: String
    let email: String
    let name: String?
    let createdAt: Date
    let updatedAt: Date
}

struct RegisterRequest: Codable, Hashable {
    let email: String
    let password: String
    let name: String?
}

struct LoginRequest: Codable, Hashable {
    let email: String
    let password: String
}

struct SocialLoginRequest: Codable, Hashable {
    let provider: String
    let idToken: String
    let email: String?
    let name: String?
}

struct AuthResponse: Codable, Hashable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let expiresIn: String
    let refreshExpiresIn: String?
    let user: AuthUser
}

struct RefreshTokenRequest: Codable, Hashable {
    let refreshToken: String
}

struct PaginationMeta: Codable, Hashable {
    let total: Int?
    let limit: Int?
    let offset: Int?
}
