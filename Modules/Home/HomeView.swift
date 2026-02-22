import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

struct MainTabView: View {

    enum Tab: Hashable {
        case home
        case plan
        case trips
        case profile
    }

    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedTab: Tab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(Tab.home)

            NavigationStack {
                DestinationSearchView()
            }
            .tabItem {
                Label("Plan", systemImage: "map.fill")
            }
            .tag(Tab.plan)

            NavigationStack {
                SavedTripsView()
            }
            .tabItem {
                Label("Trips", systemImage: "list.bullet.rectangle")
            }
            .tag(Tab.trips)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
            .tag(Tab.profile)
        }
        .tint(BrandPalette.navigationAccent)
        .onAppear {
            applyTabBarAppearance()
        }
        .onChange(of: themeManager.isLightModeEnabled) { _, _ in
            applyTabBarAppearance()
        }
    }

    private func applyTabBarAppearance() {
#if os(iOS)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.08, green: 0.09, blue: 0.10, alpha: 0.98)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.08)

        let neutralIconColor = UIColor(red: 0.62, green: 0.64, blue: 0.68, alpha: 1)

        for tabAppearance in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ] {
            tabAppearance.normal.iconColor = neutralIconColor
            tabAppearance.normal.titleTextAttributes = [.foregroundColor: neutralIconColor]
            tabAppearance.selected.iconColor = neutralIconColor
            tabAppearance.selected.titleTextAttributes = [.foregroundColor: neutralIconColor]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
#endif
    }
}

struct HomeView: View {

    @EnvironmentObject private var session: AppSession
    @State private var currentDate = Date()
    @State private var profileIconRefreshToken = UUID()
    private let clockTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var displayName: String {
        guard let rawName = session.currentUser?.name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawName.isEmpty else {
            return "Traveler"
        }
        return rawName
    }

    private var initials: String {
        let words = displayName
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
            .joined()
        return words.isEmpty ? "T" : words
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: currentDate)
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }

    private var currentTimeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, h:mm a"
        return formatter.string(from: currentDate)
    }

    var body: some View {
        ZStack {
            BrandBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(greetingText)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(BrandPalette.textPrimary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)
                                .allowsTightening(true)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(displayName)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(BrandPalette.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Text(currentTimeText)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(BrandPalette.textMuted)
                        }

                        Spacer()

                        NavigationLink {
                            ProfileView()
                        } label: {
                            homeProfileIcon
                                .id(profileIconRefreshToken)
                        }
                        .buttonStyle(.plain)
                    }
                    .brandCard(cornerRadius: 22, padding: 16, fillOpacity: 0.09)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 0) {
                            Text("Plan ")
                                .foregroundStyle(BrandPalette.textPrimary)
                            Text("Smarter")
                                .foregroundStyle(BrandPalette.accentCoral)
                            Text(".")
                                .foregroundStyle(BrandPalette.textPrimary)
                        }
                        HStack(spacing: 0) {
                            Text("Travel ")
                                .foregroundStyle(BrandPalette.textPrimary)
                            Text("Better")
                                .foregroundStyle(BrandPalette.accentCoral)
                            Text(".")
                                .foregroundStyle(BrandPalette.textPrimary)
                        }
                    }
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .lineSpacing(4)

                    Text("Tripzync converts your travel ideas into structured daily plans.")
                        .font(.body.weight(.medium))
                        .foregroundStyle(BrandPalette.textSecondary)

                    if let user = session.currentUser {
                        Text("Signed in as \(user.email)")
                            .font(.footnote)
                            .foregroundStyle(BrandPalette.textMuted)
                    }

                    NavigationLink {
                        DestinationSearchView()
                    } label: {
                        BrandPrimaryButtonLabel(title: "Start Planning", icon: "sparkles")
                    }

                    NavigationLink {
                        SavedTripsView()
                    } label: {
                        BrandSecondaryButtonLabel(title: "View Preview", icon: "rectangle.stack")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Trusted Planning Core")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(BrandPalette.textPrimary)

                        VStack(spacing: 10) {
                            HomeTrustItem(icon: "clock.arrow.trianglehead.counterclockwise.rotate.90", title: "Smart Day Sequencing")
                            HomeTrustItem(icon: "hourglass.bottomhalf.filled", title: "Time-Balanced Itineraries")
                            HomeTrustItem(icon: "person.fill", title: "Designed for Every Traveler")
                        }
                    }
                    .brandCard()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Everything You Need to Plan Efficiently")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(BrandPalette.textPrimary)

                        VStack(spacing: 12) {
                            HomeFeatureCard(title: "Create Trip", subtitle: "Destination, dates, and daily planning windows.", icon: "square.and.pencil")
                            HomeFeatureCard(title: "Select Interests", subtitle: "Culture, food, nature, history, shopping, entertainment.", icon: "square.grid.2x2")
                            HomeFeatureCard(title: "Trip Timeline", subtitle: "Structured activities with day switching and map context.", icon: "timeline.selection")
                        }
                    }
                    .brandCard()
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Tripzync")
        .toolbarTitleDisplayMode(.inline)
        .onAppear {
            currentDate = Date()
        }
        .onReceive(clockTimer) { value in
            currentDate = value
        }
        .onChange(of: session.profilePhotoData) { _, _ in
            profileIconRefreshToken = UUID()
        }
    }

    @ViewBuilder
    private var homeProfileIcon: some View {
        if let data = session.profilePhotoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 62, height: 62)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
        } else {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 62, height: 62)
                Text(initials)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BrandPalette.textPrimary)
            }
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
        }
    }
}

private struct HomeTrustItem: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandPalette.accentCoral)
                .frame(width: 24)

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(BrandPalette.textSecondary)

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

private struct HomeFeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(BrandPalette.accentGradient)
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandPalette.textPrimary)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(BrandPalette.textSecondary)
            }

            Spacer()
        }
        .brandCard(cornerRadius: 16, padding: 12, fillOpacity: 0.06)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppSession())
        .environmentObject(ThemeManager())
}
