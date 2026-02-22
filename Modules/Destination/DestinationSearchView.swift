import SwiftUI
import MapKit

struct DestinationSearchView: View {

    @State private var startCity = ""
    @State private var destination = ""
    @State private var startDate = Calendar.current.startOfDay(for: Date())
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    @State private var dayStartTime = Date()
    @State private var dayEndTime = Calendar.current.date(byAdding: .hour, value: 8, to: Date()) ?? Date()

    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var resolvedStartCoordinate: CLLocationCoordinate2D?
    @State private var resolvedStartTitle = ""
    @State private var resolvedDestinationCoordinate: CLLocationCoordinate2D?
    @State private var resolvedDestinationTitle = ""
    @State private var isResolvingStart = false
    @State private var isResolvingDestination = false
    @State private var startLookupTask: Task<Void, Never>?
    @State private var destinationLookupTask: Task<Void, Never>?
    @FocusState private var focusedField: Field?

    private enum Field {
        case startCity
        case destination
    }

    private var normalizedStartCity: String {
        startCity.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedDestination: String {
        destination.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDateRangeValid: Bool {
        endDate >= startDate
    }

    private var plannedDays: Int {
        let from = Calendar.current.startOfDay(for: startDate)
        let to = Calendar.current.startOfDay(for: endDate)
        let diff = Calendar.current.dateComponents([.day], from: from, to: to).day ?? 0
        return max(1, min(14, diff + 1))
    }

    private var canContinue: Bool {
        !normalizedStartCity.isEmpty &&
        !normalizedDestination.isEmpty &&
        isDateRangeValid &&
        !isResolving &&
        resolvedStartCoordinate != nil &&
        resolvedDestinationCoordinate != nil
    }

    private var isResolving: Bool {
        isResolvingStart || isResolvingDestination
    }

    private var shouldShowLookupError: Bool {
        if isResolving { return false }
        if !normalizedStartCity.isEmpty && resolvedStartCoordinate == nil { return true }
        if !normalizedDestination.isEmpty && resolvedDestinationCoordinate == nil { return true }
        return false
    }

    private var routeDistanceText: String? {
        guard let start = resolvedStartCoordinate, let destination = resolvedDestinationCoordinate else {
            return nil
        }

        let from = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let to = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        let kilometers = from.distance(from: to) / 1000
        if kilometers < 1 {
            return "< 1 km"
        }

        return String(format: "%.0f km", kilometers)
    }

    private var disabledReason: String? {
        if normalizedStartCity.isEmpty {
            return "Enter a start city."
        }
        if normalizedDestination.isEmpty {
            return "Enter a destination city."
        }
        if !isDateRangeValid {
            return "Fix the date range to continue."
        }
        if isResolving {
            return "Resolving locations..."
        }
        if resolvedStartCoordinate == nil || resolvedDestinationCoordinate == nil {
            return "Enter precise city names so route points can be mapped."
        }
        return nil
    }

    var body: some View {
        ZStack {
            BrandBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Create Trip")
                        .font(.system(size: 33, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text("Set your start city, destination, date range, and day schedule. Tripzync will convert it into an optimized timeline.")
                        .font(.body.weight(.medium))
                        .foregroundStyle(BrandPalette.textSecondary)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Route")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandPalette.textPrimary)

                        TextField("Start city", text: $startCity)
                            .textFieldStyle(BrandFieldStyle())
                            .disableAutocorrection(true)
#if os(iOS)
                            .submitLabel(.next)
#endif
                            .focused($focusedField, equals: .startCity)
                            .onSubmit {
                                focusedField = .destination
                            }
                            .onChange(of: startCity) { _, _ in
                                resolveStartCityPreview()
                            }

                        TextField("Destination city", text: $destination)
                            .textFieldStyle(BrandFieldStyle())
                            .disableAutocorrection(true)
#if os(iOS)
                            .submitLabel(.done)
#endif
                            .focused($focusedField, equals: .destination)
                            .onChange(of: destination) { _, _ in
                                resolveDestinationPreview()
                            }

                        if !normalizedStartCity.isEmpty && !normalizedDestination.isEmpty {
                            Button {
                                let oldStart = startCity
                                startCity = destination
                                destination = oldStart
                                resolveStartCityPreview()
                                resolveDestinationPreview()
                                Haptics.success()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Swap Start & Destination")
                                }
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(BrandPalette.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Start date")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BrandPalette.textSecondary)
                                DatePicker("", selection: $startDate, displayedComponents: [.date])
                                    .labelsHidden()
                                    .tint(BrandPalette.accentCoral)
                                    .colorScheme(.dark)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("End date")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BrandPalette.textSecondary)
                                DatePicker("", selection: $endDate, displayedComponents: [.date])
                                    .labelsHidden()
                                    .tint(BrandPalette.accentCoral)
                                    .colorScheme(.dark)
                            }
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Daily start")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BrandPalette.textSecondary)
                                DatePicker("", selection: $dayStartTime, displayedComponents: [.hourAndMinute])
                                    .labelsHidden()
                                    .tint(BrandPalette.accentCoral)
                                    .colorScheme(.dark)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Daily end")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BrandPalette.textSecondary)
                                DatePicker("", selection: $dayEndTime, displayedComponents: [.hourAndMinute])
                                    .labelsHidden()
                                    .tint(BrandPalette.accentCoral)
                                    .colorScheme(.dark)
                            }
                        }

                        if isDateRangeValid {
                            Text("Planning window: \(plannedDays) days")
                                .font(.caption)
                                .foregroundStyle(BrandPalette.textSecondary)
                        } else {
                            Text("End date must be after start date.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BrandPalette.accentCoral)
                        }
                    }
                    .brandCard()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Route Preview")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(BrandPalette.textPrimary)

                            Spacer()

                            if isResolving {
                                ProgressView()
                                    .tint(BrandPalette.accentCoral)
                                    .scaleEffect(0.85)
                            }
                        }

                        if !normalizedStartCity.isEmpty || !normalizedDestination.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                if !normalizedStartCity.isEmpty {
                                    Label(
                                        "From: \(resolvedStartTitle.isEmpty ? normalizedStartCity : resolvedStartTitle)",
                                        systemImage: "location.fill"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(BrandPalette.textSecondary)
                                }

                                if !normalizedDestination.isEmpty {
                                    Label(
                                        "To: \(resolvedDestinationTitle.isEmpty ? normalizedDestination : resolvedDestinationTitle)",
                                        systemImage: "mappin.and.ellipse"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(BrandPalette.textSecondary)
                                }

                                if let routeDistanceText {
                                    Label(
                                        "Approx route distance: \(routeDistanceText)",
                                        systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(BrandPalette.textMuted)
                                }
                            }
                        }

                        Map(position: $mapPosition) {
                            if let resolvedStartCoordinate {
                                Marker(
                                    "Start: \(resolvedStartTitle.isEmpty ? normalizedStartCity : resolvedStartTitle)",
                                    coordinate: resolvedStartCoordinate
                                )
                                .tint(BrandPalette.accentCoral)
                            }

                            if let resolvedDestinationCoordinate {
                                Marker(
                                    "Destination: \(resolvedDestinationTitle.isEmpty ? normalizedDestination : resolvedDestinationTitle)",
                                    coordinate: resolvedDestinationCoordinate
                                )
                            }
                        }
                        .frame(height: 230)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            if shouldShowLookupError {
                                ContentUnavailableView(
                                    "Location Not Found",
                                    systemImage: "mappin.slash",
                                    description: Text("Try a more specific start city or destination.")
                                )
                                .foregroundStyle(BrandPalette.textSecondary)
                            }
                        }
                    }
                    .brandCard()

                    NavigationLink {
                        PreferencesView(
                            destination: normalizedDestination,
                            startCity: normalizedStartCity,
                            suggestedDays: plannedDays,
                            startDate: startDate,
                            endDate: endDate,
                            dayStartTime: dayStartTime,
                            dayEndTime: dayEndTime
                        )
                    } label: {
                        BrandPrimaryButtonLabel(title: "Continue", icon: "arrow.right")
                    }
                    .disabled(!canContinue)
                    .opacity(canContinue ? 1 : 0.6)

                    if let disabledReason, !canContinue {
                        Text(disabledReason)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(BrandPalette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Create Trip")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .tint(BrandPalette.navigationAccent)
        .onDisappear {
            startLookupTask?.cancel()
            destinationLookupTask?.cancel()
        }
        .onAppear {
            focusedField = .startCity
        }
    }

    private func resolveStartCityPreview() {
        startLookupTask?.cancel()

        let query = normalizedStartCity
        guard !query.isEmpty else {
            isResolvingStart = false
            resolvedStartCoordinate = nil
            resolvedStartTitle = ""
            updateMapCamera()
            return
        }

        startLookupTask = Task {
            isResolvingStart = true
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

            if let mapItem = await lookupMapItem(query: query),
               let coordinate = coordinate(from: mapItem) {
                resolvedStartCoordinate = coordinate
                resolvedStartTitle = mapItem.name ?? query
            } else {
                resolvedStartCoordinate = nil
                resolvedStartTitle = ""
            }

            updateMapCamera()
            isResolvingStart = false
        }
    }

    private func resolveDestinationPreview() {
        destinationLookupTask?.cancel()

        let query = normalizedDestination
        guard !query.isEmpty else {
            isResolvingDestination = false
            resolvedDestinationCoordinate = nil
            resolvedDestinationTitle = ""
            updateMapCamera()
            return
        }

        destinationLookupTask = Task {
            isResolvingDestination = true
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

            if let mapItem = await lookupMapItem(query: query),
               let coordinate = coordinate(from: mapItem) {
                resolvedDestinationCoordinate = coordinate
                resolvedDestinationTitle = mapItem.name ?? query
            } else {
                resolvedDestinationCoordinate = nil
                resolvedDestinationTitle = ""
            }

            updateMapCamera()
            isResolvingDestination = false
        }
    }

    private func lookupMapItem(query: String) async -> MKMapItem? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.first
        } catch {
            return nil
        }
    }

    private func coordinate(from mapItem: MKMapItem) -> CLLocationCoordinate2D? {
        mapItem.location.coordinate
    }

    private func updateMapCamera() {
        switch (resolvedStartCoordinate, resolvedDestinationCoordinate) {
        case let (start?, destination?):
            let minLat = min(start.latitude, destination.latitude)
            let maxLat = max(start.latitude, destination.latitude)
            let minLon = min(start.longitude, destination.longitude)
            let maxLon = max(start.longitude, destination.longitude)

            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )

            let latDelta = max((maxLat - minLat) * 1.8, 0.2)
            let lonDelta = max((maxLon - minLon) * 1.8, 0.2)

            mapPosition = .region(
                MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
                )
            )

        case let (start?, nil):
            mapPosition = .region(
                MKCoordinateRegion(
                    center: start,
                    span: MKCoordinateSpan(latitudeDelta: 0.22, longitudeDelta: 0.22)
                )
            )

        case let (nil, destination?):
            mapPosition = .region(
                MKCoordinateRegion(
                    center: destination,
                    span: MKCoordinateSpan(latitudeDelta: 0.22, longitudeDelta: 0.22)
                )
            )

        case (nil, nil):
            mapPosition = .automatic
        }
    }
}

#Preview {
    NavigationStack {
        DestinationSearchView()
    }
}
