import Foundation
import Combine
import SwiftUI

@MainActor
final class ThemeManager: ObservableObject {

    private enum StorageKey {
        static let mode = "tripzync.theme.mode"
    }

    enum Mode: String {
        case dark
        case light
    }

    @Published var mode: Mode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: StorageKey.mode)
        }
    }

    init() {
        let storedMode = UserDefaults.standard.string(forKey: StorageKey.mode)
        mode = Mode(rawValue: storedMode ?? "") ?? .dark
    }

    var preferredColorScheme: ColorScheme {
        mode == .light ? .light : .dark
    }

    var isLightModeEnabled: Bool {
        get { mode == .light }
        set { mode = newValue ? .light : .dark }
    }
}

@MainActor
final class AppSession: ObservableObject {

    enum State: Equatable {
        case launching
        case unauthenticated
        case authenticated
    }

    @Published private(set) var state: State = .launching
    @Published private(set) var currentUser: AuthUser?
    @Published private(set) var profilePhotoData: Data?
    @Published var authErrorMessage: String?
    @Published var sessionNoticeMessage: String?
    @Published var isAuthenticating = false

    private let authService: AuthService
    private let tokenStore: KeychainTokenStore
    private let profilePhotoStore: ProfilePhotoStore
    private let userStore: SessionUserStore

    init() {
        self.authService = AuthService()
        self.tokenStore = .shared
        self.profilePhotoStore = .shared
        self.userStore = .shared

        NetworkManager.shared.setUnauthorizedHandler { [weak self] in
            Task { @MainActor in
                self?.forceLogout(reason: "Your session expired. Please sign in again.")
            }
        }
    }

    func bootstrap() async {
        guard state == .launching else { return }

        await NetworkManager.shared.warmUp()

        if tokenStore.readAccessToken() == nil && tokenStore.readRefreshToken() == nil {
            currentUser = nil
            profilePhotoData = nil
            userStore.clear()
            sessionNoticeMessage = nil
            state = .unauthenticated
            return
        }

        if let cachedUser = userStore.load() {
            currentUser = cachedUser
            loadProfilePhoto(for: cachedUser.id)
            state = .authenticated
            await refreshCurrentUser(silentFailure: true)
            return
        }

        await refreshCurrentUser(silentFailure: false)
    }

    func refreshIfNeededOnResume() async {
        guard state == .authenticated else { return }
        await refreshCurrentUser(silentFailure: true)
    }

    func login(email: String, password: String) async {
        isAuthenticating = true
        authErrorMessage = nil
        sessionNoticeMessage = nil

        do {
            let response = try await authService.login(email: email, password: password)
            try tokenStore.saveTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )
            currentUser = response.user
            loadProfilePhoto(for: response.user.id)
            userStore.save(response.user)
            authErrorMessage = nil
            state = .authenticated
        } catch {
            authErrorMessage = NetworkError.from(error).userMessage
            state = .unauthenticated
        }

        isAuthenticating = false
    }

    func register(email: String, password: String, name: String?) async {
        isAuthenticating = true
        authErrorMessage = nil
        sessionNoticeMessage = nil

        do {
            let response = try await authService.register(email: email, password: password, name: name)
            try tokenStore.saveTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )
            currentUser = response.user
            loadProfilePhoto(for: response.user.id)
            userStore.save(response.user)
            authErrorMessage = nil
            state = .authenticated
        } catch {
            authErrorMessage = NetworkError.from(error).userMessage
            state = .unauthenticated
        }

        isAuthenticating = false
    }

    func socialLogin(provider: String, idToken: String, email: String?, name: String?) async {
        isAuthenticating = true
        authErrorMessage = nil
        sessionNoticeMessage = nil

        do {
            let response = try await authService.socialLogin(
                provider: provider,
                idToken: idToken,
                email: email,
                name: name
            )
            try tokenStore.saveTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )
            currentUser = response.user
            loadProfilePhoto(for: response.user.id)
            userStore.save(response.user)
            authErrorMessage = nil
            state = .authenticated
        } catch {
            authErrorMessage = NetworkError.from(error).userMessage
            state = .unauthenticated
        }

        isAuthenticating = false
    }

    func logout() {
        Task {
            try? await authService.logout()
        }
        tokenStore.clearAllTokens()
        userStore.clear()
        currentUser = nil
        profilePhotoData = nil
        authErrorMessage = nil
        sessionNoticeMessage = nil
        state = .unauthenticated
    }

    func clearSessionNotice() {
        sessionNoticeMessage = nil
    }

    @discardableResult
    func updateProfilePhoto(_ data: Data?) -> Bool {
        guard let user = currentUser else { return false }

        do {
            if let data, !data.isEmpty {
                try profilePhotoStore.savePhotoData(data, for: user.id)
                profilePhotoData = data
            } else {
                try profilePhotoStore.removePhoto(for: user.id)
                profilePhotoData = nil
            }
            return true
        } catch {
            return false
        }
    }

    private func refreshCurrentUser(silentFailure: Bool = false) async {
        do {
            let user = try await authService.currentUser()
            currentUser = user
            loadProfilePhoto(for: user.id)
            userStore.save(user)
            state = .authenticated
            authErrorMessage = nil
        } catch {
            let mappedError = NetworkError.from(error)
            if mappedError.statusCode == 401 {
                tokenStore.clearAllTokens()
                userStore.clear()
                currentUser = nil
                profilePhotoData = nil
                state = .unauthenticated
                sessionNoticeMessage = mappedError.userMessage
                if !silentFailure {
                    authErrorMessage = mappedError.userMessage
                }
                return
            }

            if silentFailure {
                return
            }

            authErrorMessage = mappedError.userMessage
            if currentUser == nil {
                state = .unauthenticated
            }
        }
    }

    private func forceLogout(reason: String) {
        tokenStore.clearAllTokens()
        userStore.clear()
        currentUser = nil
        profilePhotoData = nil
        authErrorMessage = reason
        sessionNoticeMessage = reason
        state = .unauthenticated
    }

    private func loadProfilePhoto(for userID: String) {
        profilePhotoData = profilePhotoStore.loadPhotoData(for: userID)
    }
}

private final class SessionUserStore {
    static let shared = SessionUserStore()

    private let defaults = UserDefaults.standard
    private let key = "tripzync.session.currentUser"

    private init() {}

    func save(_ user: AuthUser) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let encoded = try? encoder.encode(user) else { return }
        defaults.set(encoded, forKey: key)
    }

    func load() -> AuthUser? {
        guard let data = defaults.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AuthUser.self, from: data)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

private final class ProfilePhotoStore {
    static let shared = ProfilePhotoStore()

    private let fileManager = FileManager.default
    private let directoryURL: URL

    private init() {
        let baseDirectory =
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ??
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        directoryURL = baseDirectory.appendingPathComponent("TripzyncProfilePhotos", isDirectory: true)
        try? ensureDirectoryExists()
    }

    func loadPhotoData(for userID: String) -> Data? {
        let url = photoURL(for: userID)
        return try? Data(contentsOf: url)
    }

    func savePhotoData(_ data: Data, for userID: String) throws {
        try ensureDirectoryExists()
        try data.write(to: photoURL(for: userID), options: [.atomic])
    }

    func removePhoto(for userID: String) throws {
        let url = photoURL(for: userID)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func ensureDirectoryExists() throws {
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }

    private func photoURL(for userID: String) -> URL {
        directoryURL.appendingPathComponent("\(safeName(for: userID)).jpg")
    }

    private func safeName(for userID: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mappedScalars = userID.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }
        return String(mappedScalars)
    }
}

@MainActor
final class PreferencesViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var generatedTripID: String?
    @Published var error: NetworkError?

    private let tripService = TripService()

    func generateTrip(destination: String, days: Int, budget: BudgetTier, startCity: String?) async {
        isLoading = true
        error = nil
        generatedTripID = nil

        do {
            let createdTrip = try await tripService.generateTrip(
                destination: destination,
                days: days,
                budget: budget,
                startCity: startCity
            )
            generatedTripID = createdTrip.id
            NotificationCenter.default.post(name: .tripsDidChange, object: nil)
        } catch {
            self.error = NetworkError.from(error)
        }

        isLoading = false
    }
}
