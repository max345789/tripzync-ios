import SwiftUI

struct OnboardingView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 2) {
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

                        Text("Tripzync converts your travel ideas into structured daily plans.")
                            .font(.body.weight(.medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(BrandPalette.textSecondary)
                            .padding(.horizontal, 8)

                        HeroDevicePreview()

                        NavigationLink {
                            SignupView()
                        } label: {
                            BrandPrimaryButtonLabel(title: "Start Planning", icon: "sparkles")
                        }

                        NavigationLink {
                            LoginView()
                        } label: {
                            BrandSecondaryButtonLabel(title: "Log In", icon: "rectangle.portrait.and.arrow.right")
                        }

                        VStack(spacing: 10) {
                            TrustRow(icon: "clock.arrow.trianglehead.counterclockwise.rotate.90", title: "Smart Day Sequencing")
                            TrustRow(icon: "hourglass.bottomhalf.filled", title: "Time-Balanced Itineraries")
                            TrustRow(icon: "person.fill", title: "Designed for Every Traveler")
                        }
                        .brandCard()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Everything You Need to Plan Efficiently")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(BrandPalette.textPrimary)

                            FeaturePreviewCard(title: "Create Trip", icon: "square.and.pencil", subtitle: "Set destination, date window, and daily schedule range.")
                            FeaturePreviewCard(title: "Select Interests", icon: "square.grid.2x2", subtitle: "Choose focus areas like food, culture, and nature.")
                            FeaturePreviewCard(title: "Trip Timeline", icon: "list.bullet.rectangle.portrait", subtitle: "View structured day-by-day activity timelines.")
                        }
                        .brandCard()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
            .tint(BrandPalette.navigationAccent)
        }
    }
}

private struct HeroDevicePreview: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(Color.clear)
                .frame(height: 340)

            Circle()
                .fill(BrandPalette.accentGradient)
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .opacity(0.22)

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.black.opacity(0.95))
                    .overlay(
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Trip Plan")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(BrandPalette.textPrimary)

                            MiniTimelineItem(time: "09:00", title: "Louvre Museum", subtitle: "2h • Culture")
                            MiniTimelineItem(time: "12:00", title: "Local Bistro", subtitle: "1h • Food")
                            MiniTimelineItem(time: "14:30", title: "Seine Walk", subtitle: "1.5h • Nature")
                        }
                        .padding(18)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .frame(width: 220, height: 300)
            }

            CurvedTravelPath()
                .stroke(BrandPalette.accentCoral.opacity(0.42), style: StrokeStyle(lineWidth: 1.4, dash: [6, 8]))
                .frame(width: 280, height: 260)
        }
        .brandCard(cornerRadius: 28, padding: 12, fillOpacity: 0.05)
    }
}

private struct CurvedTravelPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 20, y: rect.midY + 60))
        path.addCurve(
            to: CGPoint(x: rect.maxX - 20, y: rect.midY - 70),
            control1: CGPoint(x: rect.midX - 90, y: rect.midY - 80),
            control2: CGPoint(x: rect.midX + 70, y: rect.midY + 90)
        )
        return path
    }
}

private struct MiniTimelineItem: View {
    let time: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(time)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandPalette.accentCoral)
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandPalette.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(BrandPalette.textSecondary)
            }
            Spacer()
        }
    }
}

private struct TrustRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandPalette.accentCoral)
                .frame(width: 22)

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(BrandPalette.textSecondary)

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

private struct FeaturePreviewCard: View {
    let title: String
    let icon: String
    let subtitle: String

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
    OnboardingView()
}
