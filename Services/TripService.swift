import Foundation

struct TripListResult {
    let trips: [Trip]
    let total: Int
    let limit: Int
    let offset: Int
}

actor TripCacheStore {
    static let shared = TripCacheStore()

    private var tripsByID: [String: Trip] = [:]

    func trip(id: String) -> Trip? {
        tripsByID[id]
    }

    func store(trip: Trip) {
        tripsByID[trip.id] = trip
    }

    func store(trips: [Trip]) {
        for trip in trips {
            tripsByID[trip.id] = trip
        }
    }

    func remove(id: String) {
        tripsByID.removeValue(forKey: id)
    }
}

final class AuthService {

    private let network = NetworkManager.shared

    func register(email: String, password: String, name: String?) async throws -> AuthResponse {
        let request = RegisterRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            name: name?.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        let body = try network.encodeBody(request)
        let result: APIResult<AuthResponse> = try await network.request(
            path: "api/auth/register",
            method: .POST,
            body: body,
            requiresAuth: false
        )

        return result.data
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let request = LoginRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )

        let body = try network.encodeBody(request)
        let result: APIResult<AuthResponse> = try await network.request(
            path: "api/auth/login",
            method: .POST,
            body: body,
            requiresAuth: false
        )

        return result.data
    }

    func socialLogin(provider: String, idToken: String, email: String?, name: String?) async throws -> AuthResponse {
        let request = SocialLoginRequest(
            provider: provider,
            idToken: idToken,
            email: email?.trimmingCharacters(in: .whitespacesAndNewlines),
            name: name?.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        let body = try network.encodeBody(request)
        let result: APIResult<AuthResponse> = try await network.request(
            path: "api/auth/social-login",
            method: .POST,
            body: body,
            requiresAuth: false
        )

        return result.data
    }

    func currentUser() async throws -> AuthUser {
        let result: APIResult<AuthUser> = try await network.request(
            path: "api/auth/me",
            method: .GET,
            requiresAuth: true
        )

        return result.data
    }

    func logout() async throws {
        let _: APIResult<[String: Bool]> = try await network.request(
            path: "api/auth/logout",
            method: .POST,
            body: try? network.encodeBody([String: String]()),
            requiresAuth: true
        )
    }
}

final class TripService {

    private let network = NetworkManager.shared
    private let cache = TripCacheStore.shared
    private let maxListLimit = 100

    func generateTrip(destination: String, days: Int, budget: BudgetTier, startCity: String? = nil) async throws -> Trip {
        let normalizedDestination = try validatedDestination(destination)
        let validatedDays = try validatedDays(days)
        let normalizedStartCity = try validatedOptionalDestination(startCity)
        let request = TripGenerateRequest(
            destination: normalizedDestination,
            days: validatedDays,
            budget: budget.rawValue,
            startCity: normalizedStartCity
        )

        let body = try network.encodeBody(request)
        let result: APIResult<Trip> = try await network.request(
            path: "api/generate-trip",
            method: .POST,
            body: body
        )

        await cache.store(trip: result.data)
        return result.data
    }

    func fetchTrips(limit: Int, offset: Int) async throws -> TripListResult {
        let validatedLimit = try validatedLimit(limit)
        let validatedOffset = try validatedOffset(offset)
        let result: APIResult<[Trip]> = try await network.request(
            path: "api/trips",
            method: .GET,
            queryItems: [
                URLQueryItem(name: "limit", value: String(validatedLimit)),
                URLQueryItem(name: "offset", value: String(validatedOffset))
            ]
        )

        await cache.store(trips: result.data)
        let meta = result.meta
        return TripListResult(
            trips: result.data,
            total: meta?.total ?? result.data.count,
            limit: meta?.limit ?? validatedLimit,
            offset: meta?.offset ?? validatedOffset
        )
    }

    func peekCachedTrip(id: String) async -> Trip? {
        await cache.trip(id: id)
    }

    func fetchTrip(id: String, forceRefresh: Bool = false) async throws -> Trip {
        let tripID = try validatedTripID(id)

        if !forceRefresh, let cached = await cache.trip(id: tripID) {
            return cached
        }

        let result: APIResult<Trip> = try await network.request(
            path: "api/trip/\(tripID)",
            method: .GET
        )

        await cache.store(trip: result.data)
        return result.data
    }

    func updateTrip(id: String, destination: String?, days: Int?, budget: BudgetTier?, startCity: String? = nil) async throws -> Trip {
        let tripID = try validatedTripID(id)
        let normalizedDestination = try validatedOptionalDestination(destination)
        let validatedDays = try validatedOptionalDays(days)
        let normalizedStartCity = try validatedOptionalDestination(startCity)

        if normalizedDestination == nil, validatedDays == nil, budget == nil, normalizedStartCity == nil {
            throw NetworkError.validation(message: "Provide at least one field to update.")
        }

        let request = TripUpdateRequest(
            destination: normalizedDestination,
            days: validatedDays,
            budget: budget?.rawValue,
            startCity: normalizedStartCity
        )

        let body = try network.encodeBody(request)
        let result: APIResult<Trip> = try await network.request(
            path: "api/trip/\(tripID)",
            method: .PATCH,
            body: body
        )

        await cache.store(trip: result.data)
        return result.data
    }

    func deleteTrip(id: String) async throws {
        let tripID = try validatedTripID(id)
        let _: APIResult<TripDeleteResponse> = try await network.request(
            path: "api/trip/\(tripID)",
            method: .DELETE
        )
        await cache.remove(id: tripID)
    }

    func regenerateTrip(id: String, days: Int? = nil, budget: BudgetTier? = nil) async throws -> Trip {
        let tripID = try validatedTripID(id)
        let validatedDays = try validatedOptionalDays(days)

        let request = TripRegenerateRequest(
            days: validatedDays,
            budget: budget?.rawValue
        )

        let body = try network.encodeBody(request)
        let result: APIResult<Trip> = try await network.request(
            path: "api/trip/\(tripID)/regenerate",
            method: .POST,
            body: body
        )

        await cache.store(trip: result.data)
        return result.data
    }

    func fetchExplore(limit: Int = 12, query: String? = nil) async throws -> [ExploreSpot] {
        let validatedLimit = try validatedLimit(limit)
        var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(validatedLimit))]

        if let query {
            let trimmed = InputValidator.normalize(query)
            if !trimmed.isEmpty {
                items.append(URLQueryItem(name: "q", value: trimmed))
            }
        }

        let result: APIResult<[ExploreSpot]> = try await network.request(
            path: "api/explore",
            method: .GET,
            queryItems: items
        )

        return result.data
    }

    private func validatedTripID(_ id: String) throws -> String {
        let value = InputValidator.normalize(id)
        guard InputValidator.isValidTripID(value) else {
            throw NetworkError.validation(message: "Trip identifier is invalid.")
        }
        return value
    }

    private func validatedDestination(_ destination: String) throws -> String {
        let value = InputValidator.normalize(destination)
        guard !value.isEmpty else {
            throw NetworkError.validation(message: "Destination is required.")
        }
        guard value.count <= 120 else {
            throw NetworkError.validation(message: "Destination must be 120 characters or less.")
        }
        return value
    }

    private func validatedOptionalDestination(_ destination: String?) throws -> String? {
        guard let destination else { return nil }
        let value = InputValidator.normalize(destination)
        guard !value.isEmpty else {
            throw NetworkError.validation(message: "Destination cannot be empty.")
        }
        guard value.count <= 120 else {
            throw NetworkError.validation(message: "Destination must be 120 characters or less.")
        }
        return value
    }

    private func validatedDays(_ days: Int) throws -> Int {
        guard InputValidator.isValidDays(days) else {
            throw NetworkError.validation(message: "Days must be between 1 and 14.")
        }
        return days
    }

    private func validatedOptionalDays(_ days: Int?) throws -> Int? {
        guard let days else { return nil }
        return try validatedDays(days)
    }

    private func validatedLimit(_ value: Int) throws -> Int {
        guard value > 0 && value <= maxListLimit else {
            throw NetworkError.validation(message: "Limit must be between 1 and \(maxListLimit).")
        }
        return value
    }

    private func validatedOffset(_ value: Int) throws -> Int {
        guard value >= 0 else {
            throw NetworkError.validation(message: "Offset must be zero or greater.")
        }
        return value
    }
}
