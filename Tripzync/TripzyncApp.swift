//
//  TripzyncApp.swift
//  Tripzync
//

import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
#if canImport(FirebaseCore)
        FirebaseApp.configure()
#endif
        return true
    }
}

@main
struct TripzyncApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var session = AppSession()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(session)
                .environmentObject(themeManager)
                .tint(BrandPalette.navigationAccent)
                .preferredColorScheme(themeManager.preferredColorScheme)
                .task {
                    await session.bootstrap()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await session.refreshIfNeededOnResume()
                        }
                    }
                }
        }
    }
}
