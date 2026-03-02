import Foundation
import CoreLocation

struct Activity: Codable, Hashable, Identifiable {
    let time: String
    let title: String
    let description: String
    let latitude: Double
    let longitude: Double
    let durationMinutes: Int?
    let travelToNextMinutes: Int?
    let travelToNextKm: Double?
    let travelMode: String?

    var id: String {
        "\(time)-\(title)-\(latitude)-\(longitude)"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct ItineraryDay: Codable, Hashable, Identifiable {
    let dayNumber: Int
    let activities: [Activity]

    var id: Int {
        dayNumber
    }

    var sortedActivities: [Activity] {
        activities.sorted {
            activitySortOrder($0.time) < activitySortOrder($1.time)
        }
    }

    private func activitySortOrder(_ value: String) -> Int {
        switch value.lowercased() {
        case "morning":
            return 0
        case "afternoon":
            return 1
        case "evening":
            return 2
        default:
            return 3
        }
    }
}
