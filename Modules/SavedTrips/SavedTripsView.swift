//
//  SavedTripsView.swift
//  Tripzync
//

import SwiftUI
import Combine

@MainActor
private final class SavedTripsViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var isLoadingInitial = false
    @Published var isLoadingMore = false
    @Published var isRefreshingVisibleList = false
    @Published var error: NetworkError?
    @Published var transientError: NetworkError?

    private let tripService = TripService()
    private let pageSize = 10

    private var total = 0
    private var offset = 0

    var hasMore: Bool {
        trips.count < total
    }

    func loadInitial(force: Bool = false) async {
        if isLoadingInitial { return }
        if !force && !trips.isEmpty { return }

        let hasVisibleData = !trips.isEmpty
        if hasVisibleData {
            isRefreshingVisibleList = true
        }
        isLoadingInitial = true
        error = nil

        defer {
            isLoadingInitial = false
            isRefreshingVisibleList = false
        }

        do {
            let result = try await tripService.fetchTrips(limit: pageSize, offset: 0)
            trips = result.trips.sorted { $0.createdAt > $1.createdAt }
            total = result.total
            offset = trips.count
            transientError = nil
        } catch {
            let mapped = NetworkError.from(error)
            if hasVisibleData {
                transientError = mapped
            } else {
                self.error = mapped
            }
        }
    }

    func refresh() async {
        await loadInitial(force: true)
    }

    func loadMore() async {
        if isLoadingMore || isLoadingInitial || !hasMore { return }

        isLoadingMore = true
        error = nil

        do {
            let result = try await tripService.fetchTrips(limit: pageSize, offset: offset)
            let appended = result.trips.sorted { $0.createdAt > $1.createdAt }
            trips.append(contentsOf: appended)
            total = result.total
            offset = trips.count
            transientError = nil
        } catch {
            transientError = NetworkError.from(error)
        }

        isLoadingMore = false
    }
}

struct SavedTripsView: View {

    @StateObject private var viewModel = SavedTripsViewModel()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            BrandBackground()

            content
                .padding(.horizontal, 20)
                .padding(.top, 14)

            NavigationLink {
                DestinationSearchView()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("New Trip")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .background(BrandPalette.accentGradient)
                .clipShape(Capsule())
                .shadow(color: BrandPalette.accentCoral.opacity(0.35), radius: 14, x: 0, y: 8)
            }
            .padding(.trailing, 18)
            .padding(.bottom, 20)
        }
        .navigationTitle("My Trips")
#if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .tint(BrandPalette.navigationAccent)
        .task {
            await viewModel.loadInitial()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tripsDidChange)) { _ in
            Task {
                await viewModel.refresh()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoadingInitial && viewModel.trips.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(BrandPalette.accentCoral)
                Text("Loading your trips...")
                    .foregroundStyle(BrandPalette.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.error, viewModel.trips.isEmpty {
            VStack(spacing: 12) {
                Text(error.title)
                    .font(.headline)
                    .foregroundStyle(BrandPalette.textPrimary)

                Text(error.userMessage)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BrandPalette.textSecondary)

                Button {
                    Task {
                        await viewModel.loadInitial(force: true)
                    }
                } label: {
                    BrandSecondaryButtonLabel(title: "Retry")
                }
            }
            .brandCard()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.trips.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "airplane.circle")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(BrandPalette.accentCoral)

                Text("No Trips Yet")
                    .font(.headline)
                    .foregroundStyle(BrandPalette.textPrimary)

                Text("Generate your first trip to build your smart timeline.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BrandPalette.textSecondary)
            }
            .brandCard()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Your travel dashboard")
                        .font(.subheadline)
                        .foregroundStyle(BrandPalette.textSecondary)

                    ForEach(viewModel.trips) { trip in
                        NavigationLink {
                            ItineraryView(tripID: trip.id)
                        } label: {
                            TripDashboardCard(trip: trip)
                        }
                        .buttonStyle(.plain)
                    }

                    if viewModel.hasMore {
                        Button {
                            Task {
                                await viewModel.loadMore()
                            }
                        } label: {
                            if viewModel.isLoadingMore {
                                BrandSecondaryButtonLabel(title: "Loading...")
                            } else {
                                BrandSecondaryButtonLabel(title: "Load More")
                            }
                        }
                        .disabled(viewModel.isLoadingMore)
                    }

                    Color.clear.frame(height: 70)
                }
                .padding(.bottom, 8)
            }
            .refreshable {
                await viewModel.refresh()
            }
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    if viewModel.isRefreshingVisibleList {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(BrandPalette.accentCoral)
                            Text("Refreshing trips...")
                                .font(.subheadline)
                                .foregroundStyle(BrandPalette.textPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .brandCard(cornerRadius: 12, padding: 10, fillOpacity: 0.12)
                    }

                    if let transientError = viewModel.transientError {
                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: "wifi.exclamationmark")
                                .foregroundStyle(BrandPalette.accentCoral)
                            Text(transientError.userMessage)
                                .font(.footnote)
                                .foregroundStyle(BrandPalette.textSecondary)
                                .lineLimit(2)
                            Spacer(minLength: 8)
                            Button("Retry") {
                                Task {
                                    await viewModel.refresh()
                                }
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BrandPalette.accentCoral)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .brandCard(cornerRadius: 12, padding: 10, fillOpacity: 0.12)
                    }
                }
                .padding(.top, 6)
            }
        }
    }
}

private struct TripDashboardCard: View {
    let trip: Trip

    private var endDate: Date {
        Calendar.current.date(byAdding: .day, value: max(trip.days - 1, 0), to: trip.createdAt) ?? trip.createdAt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.destination)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text("\(AppDateFormatter.tripDate.string(from: trip.createdAt)) - \(AppDateFormatter.tripDate.string(from: endDate))")
                        .font(.caption)
                        .foregroundStyle(BrandPalette.textSecondary)
                }

                Spacer()

                Text(trip.budgetDisplay)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandPalette.accentCoral)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(BrandPalette.accentRed.opacity(0.2))
                    .clipShape(Capsule())
            }

            Text("\(trip.days) days")
                .font(.footnote)
                .foregroundStyle(BrandPalette.textMuted)

            VStack(spacing: 8) {
                ForEach(Array((trip.sortedItinerary.first?.sortedActivities ?? []).prefix(3).enumerated()), id: \.offset) { index, activity in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(index == 0 ? BrandPalette.accentCoral : Color.white.opacity(0.45))
                            .frame(width: 6, height: 6)
                        Text(activity.time)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandPalette.textSecondary)
                            .frame(width: 70, alignment: .leading)
                        Text(activity.title)
                            .font(.caption)
                            .foregroundStyle(BrandPalette.textPrimary)
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }
        }
        .brandCard(cornerRadius: 20, padding: 16, fillOpacity: 0.08)
    }
}

#Preview {
    NavigationStack {
        SavedTripsView()
    }
}
