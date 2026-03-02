import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

struct MainTabView: View {

    enum Tab: Hashable {
        case home
        case itinerary
        case map
        case explore
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
                SavedTripsView()
            }
            .tabItem {
                Label("Itinerary", systemImage: "calendar")
            }
            .tag(Tab.itinerary)

            NavigationStack {
                TripsMapHubView()
            }
            .tabItem {
                Label("Map", systemImage: "map")
            }
            .tag(Tab.map)

            NavigationStack {
                ExploreView()
            }
            .tabItem {
                Label("Explore", systemImage: "safari")
            }
            .tag(Tab.explore)

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
        let isLight = themeManager.isLightModeEnabled
        appearance.backgroundColor = isLight
            ? UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 0.98)
            : UIColor(red: 0.06, green: 0.10, blue: 0.17, alpha: 0.98)
        appearance.shadowColor = isLight
            ? UIColor(red: 0.84, green: 0.89, blue: 0.95, alpha: 1.0)
            : UIColor.white.withAlphaComponent(0.08)

        let neutralIconColor = isLight
            ? UIColor(red: 0.52, green: 0.58, blue: 0.66, alpha: 1.0)
            : UIColor(red: 0.63, green: 0.68, blue: 0.77, alpha: 1.0)
        let activeColor = UIColor(red: 0.17, green: 0.55, blue: 0.93, alpha: 1.0)

        for tabAppearance in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ] {
            tabAppearance.normal.iconColor = neutralIconColor
            tabAppearance.normal.titleTextAttributes = [.foregroundColor: neutralIconColor]
            tabAppearance.selected.iconColor = activeColor
            tabAppearance.selected.titleTextAttributes = [.foregroundColor: activeColor]
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
                        BrandSecondaryButtonLabel(title: "My Itinerary", icon: "calendar")
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

@MainActor
private final class TripsMapHubViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var isLoading = false
    @Published var error: NetworkError?

    private let tripService = TripService()

    func load(force: Bool = false) async {
        if isLoading { return }
        if !force && !trips.isEmpty { return }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let result = try await tripService.fetchTrips(limit: 20, offset: 0)
            trips = result.trips.sorted { $0.createdAt > $1.createdAt }
        } catch {
            self.error = NetworkError.from(error)
        }
    }
}

private struct TripsMapHubView: View {
    @StateObject private var viewModel = TripsMapHubViewModel()

    var body: some View {
        ZStack {
            BrandBackground()

            if viewModel.isLoading && viewModel.trips.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(BrandPalette.accentCoral)
                    Text("Loading map-ready trips...")
                        .foregroundStyle(BrandPalette.textSecondary)
                }
                .brandCard()
                .padding(.horizontal, 24)
            } else if let error = viewModel.error, viewModel.trips.isEmpty {
                VStack(spacing: 12) {
                    Text(error.title)
                        .font(.headline)
                        .foregroundStyle(BrandPalette.textPrimary)
                    Text(error.userMessage)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(BrandPalette.textSecondary)
                    Button {
                        Task { await viewModel.load(force: true) }
                    } label: {
                        BrandSecondaryButtonLabel(title: "Retry")
                    }
                }
                .brandCard()
                .padding(.horizontal, 24)
            } else if viewModel.trips.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "map")
                        .font(.system(size: 34))
                        .foregroundStyle(BrandPalette.accentCoral)
                    Text("No trips available")
                        .font(.headline)
                        .foregroundStyle(BrandPalette.textPrimary)
                    Text("Generate a trip first, then open its route map here.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(BrandPalette.textSecondary)
                }
                .brandCard()
                .padding(.horizontal, 24)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Trip Routes")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(BrandPalette.textPrimary)

                        Text("Open any itinerary on map with exact coordinates.")
                            .font(.subheadline)
                            .foregroundStyle(BrandPalette.textSecondary)

                        ForEach(viewModel.trips) { trip in
                            let activities = trip.sortedItinerary.flatMap { $0.sortedActivities }

                            NavigationLink {
                                MapView(activities: activities, title: trip.destination)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(trip.destination)
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(BrandPalette.textPrimary)
                                        Spacer()
                                        Text("\(activities.count) stops")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(BrandPalette.accentCoral)
                                    }

                                    if let first = activities.first {
                                        Text("Starts at \(first.title)")
                                            .font(.subheadline)
                                            .foregroundStyle(BrandPalette.textSecondary)

                                        Text(String(format: "%.4f, %.4f", first.latitude, first.longitude))
                                            .font(.caption)
                                            .foregroundStyle(BrandPalette.textMuted)
                                    } else {
                                        Text("No mapped activities yet.")
                                            .font(.caption)
                                            .foregroundStyle(BrandPalette.textMuted)
                                    }
                                }
                                .brandCard(cornerRadius: 18, padding: 14, fillOpacity: 0.07)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
                }
                .refreshable {
                    await viewModel.load(force: true)
                }
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }
}

@MainActor
private final class ExploreViewModel: ObservableObject {
    @Published var spots: [ExploreSpot] = []
    @Published var isLoading = false
    @Published var error: NetworkError?

    private let tripService = TripService()

    func load(force: Bool = false) async {
        if isLoading { return }
        if !force && !spots.isEmpty { return }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            spots = try await tripService.fetchExplore(limit: 12)
        } catch {
            self.error = NetworkError.from(error)
        }
    }
}

private struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()

    var body: some View {
        ZStack {
            BrandBackground()

            if viewModel.isLoading && viewModel.spots.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(BrandPalette.accentCoral)
                    Text("Loading personalized spots...")
                        .foregroundStyle(BrandPalette.textSecondary)
                }
                .brandCard()
                .padding(.horizontal, 24)
            } else if let error = viewModel.error, viewModel.spots.isEmpty {
                VStack(spacing: 12) {
                    Text(error.title)
                        .font(.headline)
                        .foregroundStyle(BrandPalette.textPrimary)
                    Text(error.userMessage)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(BrandPalette.textSecondary)
                    Button {
                        Task { await viewModel.load(force: true) }
                    } label: {
                        BrandSecondaryButtonLabel(title: "Retry")
                    }
                }
                .brandCard()
                .padding(.horizontal, 24)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Explore")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(BrandPalette.textPrimary)

                        Text("Discover your next adventure from real route history and hidden picks.")
                            .font(.subheadline)
                            .foregroundStyle(BrandPalette.textSecondary)

                        HStack(spacing: 8) {
                            ChipLabel(title: "All", isActive: true)
                            ChipLabel(title: "History", isActive: false)
                            ChipLabel(title: "Hidden Gems", isActive: false)
                        }

                        if viewModel.spots.isEmpty {
                            Text("No recommendations yet. Generate a trip to unlock Explore.")
                                .font(.subheadline)
                                .foregroundStyle(BrandPalette.textSecondary)
                                .brandCard(cornerRadius: 16, padding: 14, fillOpacity: 0.08)
                        } else {
                            ForEach(viewModel.spots) { spot in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(spot.subtitle.uppercased())
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Color.white.opacity(0.86))

                                    Text(spot.title)
                                        .font(.title2.weight(.bold))
                                        .foregroundStyle(.white)

                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.and.ellipse")
                                        Text(spot.location)
                                        Spacer()
                                        Text(String(format: "%.3f, %.3f", spot.latitude, spot.longitude))
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.white.opacity(0.92))
                                }
                                .frame(maxWidth: .infinity, minHeight: 144, alignment: .bottomLeading)
                                .padding(16)
                                .background(gradient(for: spot))
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 22)
                }
                .refreshable {
                    await viewModel.load(force: true)
                }
            }
        }
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }

    private func gradient(for spot: ExploreSpot) -> LinearGradient {
        if spot.source == "trip_history" {
            return LinearGradient(
                colors: [Color(red: 0.16, green: 0.49, blue: 0.85), Color(red: 0.07, green: 0.16, blue: 0.34)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color(red: 0.58, green: 0.67, blue: 0.82), Color(red: 0.28, green: 0.36, blue: 0.52)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct ChipLabel: View {
    let title: String
    let isActive: Bool

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isActive ? .white : BrandPalette.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isActive {
                        BrandPalette.accentGradient
                    } else {
                        LinearGradient(colors: [Color.white.opacity(0.45), Color.white.opacity(0.24)], startPoint: .leading, endPoint: .trailing)
                    }
                }
            )
            .clipShape(Capsule())
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppSession())
        .environmentObject(ThemeManager())
}
