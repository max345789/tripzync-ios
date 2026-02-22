//
//  MapView.swift
//  Tripzync
//

import SwiftUI
import MapKit

struct MapView: View {
    let activities: [Activity]
    let title: String

    @State private var position: MapCameraPosition

    init(activities: [Activity], title: String = "Trip Map") {
        self.activities = activities
        self.title = title

        if let first = activities.first {
            let region = MKCoordinateRegion(
                center: first.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
            )
            _position = State(initialValue: .region(region))
        } else {
            _position = State(initialValue: .automatic)
        }
    }

    var body: some View {
        ZStack {
            BrandBackground()

            if activities.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "map")
                        .font(.system(size: 36))
                        .foregroundStyle(BrandPalette.accentCoral)
                    Text("No Coordinates")
                        .font(.headline)
                        .foregroundStyle(BrandPalette.textPrimary)
                    Text("No map data is available for this trip.")
                        .font(.subheadline)
                        .foregroundStyle(BrandPalette.textSecondary)
                }
                .brandCard()
                .padding(.horizontal, 24)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Map(position: $position) {
                            ForEach(activities) { activity in
                                Marker(activity.title, coordinate: activity.coordinate)
                            }
                        }
                        .frame(height: 330)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )

                        ForEach(activities) { activity in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(activity.title)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(BrandPalette.textPrimary)

                                Text(activity.time)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(BrandPalette.accentCoral)

                                Text(String(format: "%.5f, %.5f", activity.latitude, activity.longitude))
                                    .font(.caption)
                                    .foregroundStyle(BrandPalette.textSecondary)
                            }
                            .brandCard(cornerRadius: 16, padding: 12, fillOpacity: 0.08)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle(title)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .tint(BrandPalette.navigationAccent)
    }
}

#Preview {
    NavigationStack {
        MapView(activities: [], title: "Trip Map")
    }
}
