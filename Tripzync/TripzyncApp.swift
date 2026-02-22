//
//  TripzyncApp.swift
//  Tripzync
//

import SwiftUI

@main
struct TripzyncApp: App {
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
