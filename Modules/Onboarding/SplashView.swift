//
//  SplashView.swift
//  Tripzync
//

import SwiftUI

struct SplashView: View {

    @EnvironmentObject private var session: AppSession

    var body: some View {
        Group {
            switch session.state {
            case .launching:
                ZStack {
                    BrandBackground()

                    VStack(spacing: 18) {
                        ProgressView()
                            .tint(BrandPalette.accentCoral)

                        Text("Preparing your planning workspace...")
                            .font(.footnote)
                            .foregroundStyle(BrandPalette.textSecondary)
                    }
                    .padding(24)
                    .brandCard(cornerRadius: 24, padding: 20, fillOpacity: 0.08)
                    .padding(.horizontal, 26)
                }
            case .unauthenticated:
                OnboardingView()
            case .authenticated:
                MainTabView()
            }
        }
        .tint(BrandPalette.navigationAccent)
    }
}

#Preview {
    SplashView()
        .environmentObject(AppSession())
        .environmentObject(ThemeManager())
}
