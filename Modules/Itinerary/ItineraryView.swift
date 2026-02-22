//
//  ItineraryView.swift
//  Tripzync
//

import CoreLocation
import SwiftUI

struct ItineraryView: View {

    let tripID: String
    let onTripDeleted: (() -> Void)?

    @State private var trip: Trip?
    @State private var isLoading = false
    @State private var error: NetworkError?
    @State private var showEdit = false
    @State private var showDeleteConfirmation = false
    @State private var selectedDayNumber: Int?
    @State private var isRefreshing = false
    @State private var isDeleting = false
    @State private var isRegenerating = false
    @State private var hasLoadedOnce = false

    @Environment(\.dismiss) private var dismiss

    private let tripService = TripService()

    init(tripID: String, onTripDeleted: (() -> Void)? = nil) {
        self.tripID = tripID
        self.onTripDeleted = onTripDeleted
    }

    var body: some View {
        ZStack {
            BrandBackground()

            Group {
                if isLoading && trip == nil {
                    loadingView
                } else if let trip {
                    contentView(trip)
                } else if let error {
                    errorView(error)
                } else {
                    loadingView
                }
            }
        }
        .navigationTitle("Trip Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if trip != nil {
#if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit Plan") {
                        showEdit = true
                    }
                    .foregroundStyle(BrandPalette.navigationAccent)
                }
#else
                ToolbarItem(placement: .automatic) {
                    Button("Edit Plan") {
                        showEdit = true
                    }
                    .foregroundStyle(BrandPalette.navigationAccent)
                }
#endif
            }
        }
        .sheet(isPresented: $showEdit) {
            if let trip {
                NavigationStack {
                    TripEditView(trip: trip) { updatedTrip in
                        self.trip = updatedTrip
                        if selectedDayNumber == nil {
                            selectedDayNumber = updatedTrip.sortedItinerary.first?.dayNumber
                        }
                        NotificationCenter.default.post(name: .tripsDidChange, object: nil)
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete this trip?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(isDeleting ? "Deleting..." : "Delete", role: .destructive) {
                Task {
                    await deleteTrip()
                }
            }
            .disabled(isDeleting)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .task {
            if !hasLoadedOnce {
                hasLoadedOnce = true

                if let cachedTrip = await tripService.peekCachedTrip(id: tripID) {
                    trip = cachedTrip
                    if selectedDayNumber == nil {
                        selectedDayNumber = cachedTrip.sortedItinerary.first?.dayNumber
                    }
                }

                if trip == nil {
                    await loadTrip(forceRefresh: false, showBlockingLoader: true)
                } else {
                    await loadTrip(forceRefresh: true, showBlockingLoader: false)
                }
            }
        }
        .tint(BrandPalette.navigationAccent)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(BrandPalette.accentCoral)
            Text("Loading trip details...")
                .foregroundStyle(BrandPalette.textSecondary)
        }
        .brandCard()
        .padding(.horizontal, 26)
    }

    private func errorView(_ error: NetworkError) -> some View {
        VStack(spacing: 12) {
            Text(error.title)
                .font(.headline)
                .foregroundStyle(BrandPalette.textPrimary)

            Text(error.userMessage)
                .multilineTextAlignment(.center)
                .foregroundStyle(BrandPalette.textSecondary)
                .padding(.horizontal)

            if error.isRetryable || error.statusCode == 404 || error.statusCode == 500 {
                Button {
                    Task {
                        await loadTrip(forceRefresh: true, showBlockingLoader: true)
                    }
                } label: {
                    BrandSecondaryButtonLabel(title: "Retry")
                }
            }
        }
        .brandCard()
        .padding(.horizontal, 24)
    }

    private func contentView(_ trip: Trip) -> some View {
        let dayNumbers = trip.sortedItinerary.map(\.dayNumber)
        let activeDayNumber = selectedDayNumber ?? dayNumbers.first
        let activeDay = trip.sortedItinerary.first { $0.dayNumber == activeDayNumber } ?? trip.sortedItinerary.first
        let activities = activeDay?.sortedActivities ?? []

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(trip.destination)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(BrandPalette.textPrimary)

                Text("\(trip.days) Days • \(trip.budgetDisplay)")
                    .font(.subheadline)
                    .foregroundStyle(BrandPalette.textSecondary)

                Text("Updated \(AppDateFormatter.tripDateTime.string(from: trip.updatedAt))")
                    .font(.caption)
                    .foregroundStyle(BrandPalette.textMuted)

                HStack(spacing: 12) {
                    NavigationLink {
                        MapView(
                            activities: trip.sortedItinerary.flatMap { $0.sortedActivities },
                            title: trip.destination
                        )
                    } label: {
                        BrandSecondaryButtonLabel(title: "View Map", icon: "map")
                    }

                    Button {
                        showEdit = true
                    } label: {
                        BrandPrimaryButtonLabel(title: "Edit Plan", icon: "slider.horizontal.3")
                    }
                }

                Button {
                    Task {
                        await regenerateTrip()
                    }
                } label: {
                    BrandSecondaryButtonLabel(
                        title: isRegenerating ? "Refreshing Plan..." : "Refresh Plan",
                        icon: "arrow.clockwise"
                    )
                }
                .disabled(isRegenerating || isDeleting)
                .opacity((isRegenerating || isDeleting) ? 0.65 : 1)

                if !dayNumbers.isEmpty {
                    Picker("Day", selection: Binding(
                        get: { activeDayNumber ?? dayNumbers[0] },
                        set: { selectedDayNumber = $0 }
                    )) {
                        ForEach(dayNumbers, id: \.self) { day in
                            Text("Day \(day)").tag(day)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(BrandPalette.accentCoral)
                }

                Text("Stay and leave times are estimated to help you reach the next place on time.")
                    .font(.caption)
                    .foregroundStyle(BrandPalette.textMuted)

                VStack(alignment: .leading, spacing: 14) {
                    if activities.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.title3)
                                .foregroundStyle(BrandPalette.accentCoral)
                            Text("No activities for this day")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BrandPalette.textPrimary)
                            Text("Try another day or refresh the itinerary.")
                                .font(.footnote)
                                .foregroundStyle(BrandPalette.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .brandCard(cornerRadius: 16, padding: 14, fillOpacity: 0.09)
                    } else {
                        let timingGuides = activityTimingGuides(for: activities)
                        ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
                            TimelineActivityCard(
                                activity: activity,
                                isLast: index == activities.count - 1,
                                startTimeText: timingGuides[index].startTimeText,
                                durationText: timingGuides[index].stayDurationText,
                                leaveByText: timingGuides[index].leaveByText,
                                travelText: timingGuides[index].travelText
                            )
                        }
                    }
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    BrandSecondaryButtonLabel(
                        title: isDeleting ? "Deleting..." : "Delete Trip",
                        icon: "trash"
                    )
                }
                .disabled(isDeleting)
                .opacity(isDeleting ? 0.65 : 1)

                if let error {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(BrandPalette.accentCoral)
                        Text(error.userMessage)
                            .font(.footnote)
                            .foregroundStyle(BrandPalette.textSecondary)
                            .lineLimit(3)
                    }
                    .brandCard(cornerRadius: 14, padding: 12, fillOpacity: 0.08)
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .refreshable {
            await loadTrip(forceRefresh: true, showBlockingLoader: false)
        }
        .overlay(alignment: .top) {
            if isRefreshing || isRegenerating {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(BrandPalette.accentCoral)
                    Text(isRegenerating ? "Regenerating itinerary..." : "Refreshing trip...")
                        .font(.subheadline)
                        .foregroundStyle(BrandPalette.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .brandCard(cornerRadius: 12, padding: 10, fillOpacity: 0.12)
                .padding(.top, 6)
            }
        }
    }

    private struct ActivityTimingGuide {
        let startTimeText: String
        let stayDurationText: String
        let leaveByText: String?
        let travelText: String?
    }

    private func activityTimingGuides(for activities: [Activity]) -> [ActivityTimingGuide] {
        guard !activities.isEmpty else {
            return []
        }

        var startMinutesByIndex = activities.enumerated().map { index, activity in
            startMinutes(for: activity, fallbackIndex: index)
        }

        for index in 1..<startMinutesByIndex.count {
            startMinutesByIndex[index] = max(startMinutesByIndex[index], startMinutesByIndex[index - 1] + 60)
        }

        let dayEndMinutes = 22 * 60

        return activities.enumerated().map { index, activity in
            let currentStart = startMinutesByIndex[index]
            let hasNext = index < activities.count - 1

            if hasNext {
                let nextActivity = activities[index + 1]
                let nextStart = startMinutesByIndex[index + 1]
                let travelEstimate = estimatedTravel(from: activity, to: nextActivity)
                let availableStay = max(0, nextStart - currentStart - travelEstimate.minutes)
                let stayMinutes = recommendedStayMinutes(available: availableStay, isLast: false)
                let leaveByMinutes = currentStart + stayMinutes

                let travelText: String = {
                    if travelEstimate.distanceKilometers >= 0.3 {
                        return String(format: "Travel ~%d min (%.1f km)", travelEstimate.minutes, travelEstimate.distanceKilometers)
                    }
                    return "Travel ~\(travelEstimate.minutes) min"
                }()

                return ActivityTimingGuide(
                    startTimeText: formatClock(minutesFromMidnight: currentStart),
                    stayDurationText: formatDuration(minutes: stayMinutes),
                    leaveByText: stayMinutes > 0 ? formatClock(minutesFromMidnight: leaveByMinutes) : "Now",
                    travelText: travelText
                )
            }

            let availableStay = max(60, dayEndMinutes - currentStart)
            let stayMinutes = recommendedStayMinutes(available: availableStay, isLast: true)

            return ActivityTimingGuide(
                startTimeText: formatClock(minutesFromMidnight: currentStart),
                stayDurationText: formatDuration(minutes: stayMinutes),
                leaveByText: nil,
                travelText: nil
            )
        }
    }

    private func startMinutes(for activity: Activity, fallbackIndex: Int) -> Int {
        if let parsed = parseClockMinutes(activity.time) {
            return parsed
        }

        switch activity.time.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "morning":
            return 9 * 60
        case "afternoon":
            return 13 * 60
        case "evening":
            return 18 * 60
        default:
            return (9 * 60) + fallbackIndex * 180
        }
    }

    private func parseClockMinutes(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let normalized = trimmed.uppercased()
        let formats = ["H:mm", "HH:mm", "h:mm a", "h a", "h:mma", "ha"]

        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format

            if let date = formatter.date(from: normalized) {
                let components = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: date)
                guard let hour = components.hour, let minute = components.minute else {
                    continue
                }
                return hour * 60 + minute
            }
        }

        return nil
    }

    private func estimatedTravel(from: Activity, to: Activity) -> (minutes: Int, distanceKilometers: Double) {
        let source = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let destination = CLLocation(latitude: to.latitude, longitude: to.longitude)
        let kilometers = max(0, source.distance(from: destination) / 1000)

        let assumedSpeedKmh = 22.0
        let rawMinutes = Int(round((kilometers / assumedSpeedKmh) * 60))
        let boundedMinutes = min(max(rawMinutes, 8), 90)
        return (minutes: boundedMinutes, distanceKilometers: kilometers)
    }

    private func recommendedStayMinutes(available: Int, isLast: Bool) -> Int {
        let safeAvailable = max(0, available)

        if isLast {
            return max(75, min(safeAvailable, 180))
        }

        guard safeAvailable > 0 else {
            return 0
        }

        let target: Int
        switch safeAvailable {
        case 210...:
            target = 150
        case 150...:
            target = 120
        case 105...:
            target = 90
        case 75...:
            target = 60
        case 45...:
            target = 45
        default:
            target = safeAvailable
        }

        return min(target, safeAvailable)
    }

    private func formatDuration(minutes: Int) -> String {
        guard minutes > 0 else {
            return "Quick stop"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 && remainingMinutes > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(remainingMinutes)m"
    }

    private func formatClock(minutesFromMidnight: Int) -> String {
        let minutesInDay = 24 * 60
        let normalizedMinutes = ((minutesFromMidnight % minutesInDay) + minutesInDay) % minutesInDay

        var components = DateComponents()
        components.year = 2001
        components.month = 1
        components.day = 1
        components.hour = normalizedMinutes / 60
        components.minute = normalizedMinutes % 60

        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components) ?? Date()
        return AppDateFormatter.tripTimeOnly.string(from: date)
    }

    private func loadTrip(forceRefresh: Bool, showBlockingLoader: Bool) async {
        if isLoading { return }

        isLoading = showBlockingLoader
        isRefreshing = !showBlockingLoader
        if showBlockingLoader {
            error = nil
        }

        defer {
            isLoading = false
            isRefreshing = false
        }

        do {
            let loadedTrip = try await tripService.fetchTrip(id: tripID, forceRefresh: forceRefresh)
            trip = loadedTrip
            if selectedDayNumber == nil {
                selectedDayNumber = loadedTrip.sortedItinerary.first?.dayNumber
            }
            error = nil
        } catch {
            self.error = NetworkError.from(error)
        }
    }

    private func regenerateTrip() async {
        guard !isRegenerating, let currentTrip = trip else { return }

        isRegenerating = true
        error = nil

        defer {
            isRegenerating = false
        }

        do {
            let regenerated = try await tripService.regenerateTrip(
                id: currentTrip.id,
                days: currentTrip.days,
                budget: currentTrip.normalizedBudget
            )

            trip = regenerated
            if let selectedDayNumber,
               regenerated.sortedItinerary.contains(where: { $0.dayNumber == selectedDayNumber }) {
                self.selectedDayNumber = selectedDayNumber
            } else {
                self.selectedDayNumber = regenerated.sortedItinerary.first?.dayNumber
            }

            NotificationCenter.default.post(name: .tripsDidChange, object: nil)
            Haptics.success()
        } catch {
            self.error = NetworkError.from(error)
            Haptics.error()
        }
    }

    private func deleteTrip() async {
        if isDeleting { return }
        isDeleting = true
        defer {
            isDeleting = false
        }

        do {
            try await tripService.deleteTrip(id: tripID)
            NotificationCenter.default.post(name: .tripsDidChange, object: nil)
            Haptics.success()
            onTripDeleted?()
            dismiss()
        } catch {
            self.error = NetworkError.from(error)
            Haptics.error()
        }
    }

}

private struct TimelineActivityCard: View {
    let activity: Activity
    let isLast: Bool
    let startTimeText: String
    let durationText: String
    let leaveByText: String?
    let travelText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 0) {
                    Circle()
                        .fill(BrandPalette.accentGradient)
                        .frame(width: 12, height: 12)

                    if !isLast {
                        Rectangle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 2, height: 65)
                            .padding(.top, 4)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(activity.time)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandPalette.accentCoral)

                        Spacer()

                        Text(durationText)
                            .font(.caption)
                            .foregroundStyle(BrandPalette.textSecondary)
                    }

                    Text(activity.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text(activity.description)
                        .font(.subheadline)
                        .foregroundStyle(BrandPalette.textSecondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start: \(startTimeText)")
                        Text("Recommended stay: \(durationText)")
                        if let leaveByText {
                            Text("Leave by: \(leaveByText)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(BrandPalette.textSecondary)

                    Text(String(format: "%.5f, %.5f", activity.latitude, activity.longitude))
                        .font(.caption2)
                        .foregroundStyle(BrandPalette.textMuted)
                }
                .brandCard(cornerRadius: 16, padding: 12, fillOpacity: 0.07)
            }

            if !isLast, let travelText {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(BrandPalette.accentCoral)
                    Text(travelText)
                        .font(.caption)
                        .foregroundStyle(BrandPalette.textSecondary)
                }
                .padding(.leading, 24)
            }
        }
    }
}

private struct TripEditView: View {

    let trip: Trip
    let onUpdated: (Trip) -> Void

    @State private var destination: String
    @State private var days: Int
    @State private var budgetTier: BudgetTier
    @State private var isSaving = false
    @State private var error: NetworkError?

    @State private var previewDayNumber: Int
    @State private var previewActivities: [Activity]

    @Environment(\.dismiss) private var dismiss

    private let tripService = TripService()

    init(trip: Trip, onUpdated: @escaping (Trip) -> Void) {
        self.trip = trip
        self.onUpdated = onUpdated

        let firstDay = trip.sortedItinerary.first?.dayNumber ?? 1
        let firstActivities = trip.sortedItinerary.first?.sortedActivities ?? []

        _destination = State(initialValue: trip.destination)
        _days = State(initialValue: trip.days)
        _budgetTier = State(initialValue: BudgetTier.fromBackend(trip.budget))
        _previewDayNumber = State(initialValue: firstDay)
        _previewActivities = State(initialValue: firstActivities)
    }

    var body: some View {
        ZStack {
            BrandBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Edit Plan")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandPalette.textPrimary)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Trip")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(BrandPalette.textPrimary)

                        TextField("Destination", text: $destination)
                            .textFieldStyle(BrandFieldStyle())

                        HStack {
                            Text("Days")
                                .foregroundStyle(BrandPalette.textSecondary)
                            Spacer()
                            Text("\(days)")
                                .foregroundStyle(BrandPalette.textPrimary)
                                .fontWeight(.semibold)
                        }

                        Stepper("", value: $days, in: 1...14)
                            .labelsHidden()
                            .tint(BrandPalette.accentCoral)

                        Picker("Budget", selection: $budgetTier) {
                            ForEach(BudgetTier.allCases, id: \.self) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(BrandPalette.accentCoral)
                    }
                    .brandCard()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Timeline Reorder")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(BrandPalette.textPrimary)

                        Picker("Day", selection: $previewDayNumber) {
                            ForEach(trip.sortedItinerary.map(\.dayNumber), id: \.self) { day in
                                Text("Day \(day)").tag(day)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(BrandPalette.accentCoral)
                        .onChange(of: previewDayNumber) { _, newValue in
                            previewActivities = trip.sortedItinerary.first(where: { $0.dayNumber == newValue })?.sortedActivities ?? []
                        }

                        List {
                            ForEach(previewActivities) { activity in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(activity.time)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(BrandPalette.accentCoral)

                                        Text(activity.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(BrandPalette.textPrimary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Image(systemName: "line.3.horizontal")
                                        .foregroundStyle(BrandPalette.textMuted)
                                }
                                .listRowBackground(Color.clear)
                            }
                            .onMove { source, destination in
                                previewActivities.move(fromOffsets: source, toOffset: destination)
                            }
                            .onDelete { offsets in
                                previewActivities.remove(atOffsets: offsets)
                            }
                        }
#if os(iOS)
                        .scrollContentBackground(.hidden)
#endif
                        .frame(height: min(CGFloat(max(previewActivities.count, 1)) * 64 + 10, 320))
                        .environment(\.editMode, .constant(.active))
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        Text("Drag handles to reorder. Swipe to delete entries in this preview list.")
                            .font(.caption)
                            .foregroundStyle(BrandPalette.textMuted)
                    }
                    .brandCard()

                    if let error {
                        Text(error.userMessage)
                            .font(.footnote)
                            .foregroundStyle(BrandPalette.accentCoral)
                            .brandCard(cornerRadius: 14, padding: 12, fillOpacity: 0.1)
                    }

                    HStack(spacing: 12) {
                        Button {
                            dismiss()
                        } label: {
                            BrandSecondaryButtonLabel(title: "Cancel")
                        }

                        Button {
                            Task {
                                await saveChanges()
                            }
                        } label: {
                            BrandPrimaryButtonLabel(title: "Save", icon: "checkmark", isLoading: isSaving)
                        }
                        .disabled(isSaving || destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity((isSaving || destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.6 : 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .tint(BrandPalette.navigationAccent)
    }

    private func saveChanges() async {
        if isSaving { return }

        isSaving = true
        error = nil

        do {
            let updatedTrip = try await tripService.updateTrip(
                id: trip.id,
                destination: destination,
                days: days,
                budget: budgetTier
            )
            onUpdated(updatedTrip)
            Haptics.success()
            dismiss()
        } catch {
            self.error = NetworkError.from(error)
            Haptics.error()
        }

        isSaving = false
    }
}

#Preview {
    NavigationStack {
        ItineraryView(tripID: "preview")
    }
}
