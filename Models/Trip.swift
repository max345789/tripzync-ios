import Foundation

struct Trip: Codable, Hashable, Identifiable {
    let id: String
    let destination: String
    let startCity: String
    let startLatitude: Double?
    let startLongitude: Double?
    let days: Int
    let budget: String
    let userId: String
    let createdAt: Date
    let updatedAt: Date
    let itinerary: [ItineraryDay]

    var normalizedBudget: BudgetTier {
        BudgetTier.fromBackend(budget)
    }

    var budgetDisplay: String {
        normalizedBudget.displayName
    }

    var sortedItinerary: [ItineraryDay] {
        itinerary.sorted { $0.dayNumber < $1.dayNumber }
    }
}

struct ExploreSpot: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let location: String
    let latitude: Double
    let longitude: Double
    let source: String
}
