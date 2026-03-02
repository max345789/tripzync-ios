import SwiftUI

private struct TripDestination: Identifiable, Hashable {
    let id: String
}

struct PreferencesView: View {
    let destination: String
    let startCity: String?
    let startDate: Date?
    let endDate: Date?
    let dayStartTime: Date?
    let dayEndTime: Date?

    @State private var days: Int
    @State private var budgetTier: BudgetTier = .moderate
    @State private var selectedInterests: Set<String> = ["Culture", "Food"]
    @StateObject private var viewModel = PreferencesViewModel()
    @State private var tripDestination: TripDestination?

    private let interestOptions = ["Culture", "Food", "Nature", "History", "Shopping", "Entertainment"]

    private var canGeneratePlan: Bool {
        !viewModel.isLoading && !selectedInterests.isEmpty
    }

    init(
        destination: String,
        startCity: String? = nil,
        suggestedDays: Int = 3,
        startDate: Date? = nil,
        endDate: Date? = nil,
        dayStartTime: Date? = nil,
        dayEndTime: Date? = nil
    ) {
        self.destination = destination
        self.startCity = startCity
        self.startDate = startDate
        self.endDate = endDate
        self.dayStartTime = dayStartTime
        self.dayEndTime = dayEndTime
        _days = State(initialValue: max(1, min(14, suggestedDays)))
    }

    var body: some View {
        ZStack {
            BrandBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Select Interests")
                        .font(.system(size: 33, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text("Choose what matters most. Tripzync uses this context to shape a realistic day flow.")
                        .font(.body.weight(.medium))
                        .foregroundStyle(BrandPalette.textSecondary)

                    VStack(alignment: .leading, spacing: 10) {
                        if let startCity,
                           !startCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Start: \(startCity)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BrandPalette.textSecondary)
                        }

                        Text(destination)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(BrandPalette.textPrimary)

                        if let startDate, let endDate {
                            Text("\(AppDateFormatter.tripDate.string(from: startDate)) - \(AppDateFormatter.tripDate.string(from: endDate))")
                                .font(.subheadline)
                                .foregroundStyle(BrandPalette.textSecondary)
                        }

                        if let dayStartTime, let dayEndTime {
                            Text("Daily window: \(AppDateFormatter.tripTimeOnly.string(from: dayStartTime)) - \(AppDateFormatter.tripTimeOnly.string(from: dayEndTime))")
                                .font(.caption)
                                .foregroundStyle(BrandPalette.textMuted)
                        }
                    }
                    .brandCard()

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(interestOptions, id: \.self) { interest in
                            InterestTile(
                                title: interest,
                                isSelected: selectedInterests.contains(interest)
                            )
                            .onTapGesture {
                                if selectedInterests.contains(interest) {
                                    selectedInterests.remove(interest)
                                } else {
                                    selectedInterests.insert(interest)
                                }
                            }
                        }
                    }

                    Text("\(selectedInterests.count) interests selected")
                        .font(.caption)
                        .foregroundStyle(BrandPalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Trip Settings")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(BrandPalette.textPrimary)

                        VStack(alignment: .leading, spacing: 8) {
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
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Budget")
                                .foregroundStyle(BrandPalette.textSecondary)

                            Picker("Budget", selection: $budgetTier) {
                                ForEach(BudgetTier.allCases, id: \.self) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                            .tint(BrandPalette.accentCoral)
                        }
                    }
                    .brandCard()

                    Button {
                        Task {
                            await viewModel.generateTrip(
                                destination: destination,
                                days: days,
                                budget: budgetTier,
                                startCity: startCity
                            )
                            if viewModel.error == nil, viewModel.generatedTripID != nil {
                                Haptics.success()
                            } else if viewModel.error != nil {
                                Haptics.error()
                            }
                        }
                    } label: {
                        BrandPrimaryButtonLabel(title: "Generate Plan", icon: "wand.and.stars")
                    }
                    .disabled(!canGeneratePlan)
                    .opacity(canGeneratePlan ? 1 : 0.65)

                    if selectedInterests.isEmpty {
                        Text("Select at least one interest to generate a plan.")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(BrandPalette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let error = viewModel.error {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(error.title)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(BrandPalette.accentCoral)

                            Text(error.userMessage)
                                .font(.subheadline)
                                .foregroundStyle(BrandPalette.textSecondary)

                            if error.isRetryable || error.statusCode == 500 {
                                Button {
                                    Task {
                                        await viewModel.generateTrip(
                                            destination: destination,
                                            days: days,
                                            budget: budgetTier,
                                            startCity: startCity
                                        )
                                    }
                                } label: {
                                    BrandSecondaryButtonLabel(title: "Retry")
                                }
                            }
                        }
                        .brandCard(cornerRadius: 16, padding: 14, fillOpacity: 0.09)
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .allowsHitTesting(!viewModel.isLoading)

            if viewModel.isLoading {
                GeneratingOverlayView()
                    .transition(.opacity)
            }
        }
        .navigationTitle("Interests")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .tint(BrandPalette.navigationAccent)
        .onChange(of: viewModel.generatedTripID) { _, newValue in
            if let newValue {
                tripDestination = TripDestination(id: newValue)
            }
        }
        .navigationDestination(item: $tripDestination) { destination in
            ItineraryView(tripID: destination.id)
        }
    }
}

private struct InterestTile: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? BrandPalette.accentCoral : BrandPalette.textMuted)

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(BrandPalette.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? BrandPalette.accentRed.opacity(0.24) : Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? BrandPalette.accentCoral.opacity(0.8) : Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: isSelected ? BrandPalette.accentCoral.opacity(0.24) : .clear, radius: 10, x: 0, y: 5)
    }
}

private struct GeneratingOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.48)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Circle()
                    .fill(BrandPalette.accentGradient)
                    .frame(width: 70, height: 70)
                    .blur(radius: 26)
                    .overlay {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                    }

                Text("Generating your smart day plan…")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(BrandPalette.textPrimary)

                Text("This usually takes a few seconds.")
                    .font(.footnote)
                    .foregroundStyle(BrandPalette.textSecondary)
            }
            .padding(24)
            .brandCard(cornerRadius: 22, padding: 20, fillOpacity: 0.12)
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    NavigationStack {
        PreferencesView(destination: "Paris")
    }
}
