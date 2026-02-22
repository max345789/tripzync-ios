import Foundation

struct Trip: Codable, Hashable, Identifiable {
    let id: String
    let destination: String
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
