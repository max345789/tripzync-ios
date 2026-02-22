import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Notification.Name {
    static let tripsDidChange = Notification.Name("tripsDidChange")
}

enum AppDateFormatter {
    static let tripDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let tripDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let tripTimeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

enum BrandPalette {
    private static func themed(
        light: UIColor,
        dark: UIColor
    ) -> Color {
        Color(
            UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? dark : light
            }
        )
    }

    static let backgroundTop = themed(
        light: UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1),
        dark: UIColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1)
    )
    static let backgroundBottom = themed(
        light: UIColor(red: 0.90, green: 0.93, blue: 0.97, alpha: 1),
        dark: UIColor(red: 0.01, green: 0.01, blue: 0.02, alpha: 1)
    )

    static let accentRed = themed(
        light: UIColor(red: 0.96, green: 0.63, blue: 0.33, alpha: 1),
        dark: UIColor(red: 0.46, green: 0.78, blue: 0.98, alpha: 1)
    )
    static let accentCoral = themed(
        light: UIColor(red: 1.00, green: 0.73, blue: 0.45, alpha: 1),
        dark: UIColor(red: 0.70, green: 0.90, blue: 1.00, alpha: 1)
    )
    static let accentOrange = themed(
        light: UIColor(red: 1.00, green: 0.83, blue: 0.62, alpha: 1),
        dark: UIColor(red: 0.56, green: 0.84, blue: 1.00, alpha: 1)
    )
    // Keep navigation controls neutral and consistent across light/dark.
    static let navigationAccent = Color(red: 0.62, green: 0.64, blue: 0.68)

    static let textPrimary = themed(
        light: UIColor(red: 0.14, green: 0.16, blue: 0.20, alpha: 1),
        dark: UIColor(red: 0.94, green: 0.97, blue: 1.00, alpha: 1)
    )
    static let textSecondary = themed(
        light: UIColor(red: 0.31, green: 0.37, blue: 0.44, alpha: 1),
        dark: UIColor(red: 0.73, green: 0.80, blue: 0.89, alpha: 1)
    )
    static let textMuted = themed(
        light: UIColor(red: 0.46, green: 0.52, blue: 0.60, alpha: 1),
        dark: UIColor(red: 0.56, green: 0.63, blue: 0.72, alpha: 1)
    )

    static let fieldFill = themed(
        light: UIColor(red: 1.00, green: 0.94, blue: 0.87, alpha: 0.32),
        dark: UIColor(red: 0.72, green: 0.89, blue: 1.00, alpha: 0.13)
    )
    static let cardFill = themed(
        light: UIColor(red: 1.00, green: 0.93, blue: 0.85, alpha: 0.28),
        dark: UIColor(red: 0.72, green: 0.89, blue: 1.00, alpha: 0.11)
    )
    static let secondaryButtonFill = themed(
        light: UIColor(red: 1.00, green: 0.94, blue: 0.87, alpha: 0.65),
        dark: UIColor(red: 0.72, green: 0.89, blue: 1.00, alpha: 0.08)
    )
    static let borderStrong = themed(
        light: UIColor(red: 1.00, green: 0.74, blue: 0.50, alpha: 0.48),
        dark: UIColor(red: 0.77, green: 0.92, blue: 1.00, alpha: 0.34)
    )
    static let borderSoft = themed(
        light: UIColor(red: 1.00, green: 0.75, blue: 0.53, alpha: 0.34),
        dark: UIColor(red: 0.78, green: 0.92, blue: 1.00, alpha: 0.26)
    )
    static let cardShadow = themed(
        light: UIColor(red: 1.00, green: 0.71, blue: 0.45, alpha: 0.10),
        dark: UIColor(red: 0.58, green: 0.86, blue: 1.00, alpha: 0.10)
    )
    static let primaryGlow = themed(
        light: UIColor(red: 1.00, green: 0.66, blue: 0.40, alpha: 0.24),
        dark: UIColor(red: 0.70, green: 0.90, blue: 1.00, alpha: 0.32)
    )

    static let accentGradient = LinearGradient(
        colors: [accentRed, accentOrange],
        startPoint: .leading,
        endPoint: .trailing
    )
}

struct BrandBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BrandPalette.backgroundTop, BrandPalette.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [BrandPalette.accentCoral.opacity(0.22), .clear],
                center: .topLeading,
                startRadius: 24,
                endRadius: 420
            )

            RadialGradient(
                colors: [BrandPalette.accentOrange.opacity(0.18), .clear],
                center: .bottomTrailing,
                startRadius: 16,
                endRadius: 390
            )

            BrandGrainOverlay()
                .opacity(0.16)
        }
        .ignoresSafeArea()
    }
}

private struct BrandGrainOverlay: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 6
            var x: CGFloat = 0

            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    let noise = pseudoNoise(x: x, y: y)
                    if noise > 0.84 {
                        var path = Path()
                        path.addRect(CGRect(x: x, y: y, width: 1.2, height: 1.2))
                        context.fill(path, with: .color(.white.opacity((noise - 0.84) * 0.45)))
                    }
                    y += step
                }
                x += step
            }
        }
        .blendMode(.softLight)
    }

    private func pseudoNoise(x: CGFloat, y: CGFloat) -> Double {
        let raw = sin(Double(x) * 12.9898 + Double(y) * 78.233) * 43758.5453
        return raw - floor(raw)
    }
}

struct BrandPrimaryButtonLabel: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.9)
            } else if let icon {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
            }

            Text(title)
                .font(.headline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .foregroundStyle(.white)
        .background(BrandPalette.accentGradient)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BrandPalette.borderStrong, lineWidth: 0.8)
        )
        .shadow(color: BrandPalette.primaryGlow, radius: 12, x: 0, y: 6)
    }
}

struct BrandSecondaryButtonLabel: View {
    let title: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
            }
            Text(title)
                .font(.headline.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .foregroundStyle(BrandPalette.textPrimary)
        .background(BrandPalette.secondaryButtonFill)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BrandPalette.borderStrong, lineWidth: 1)
        )
    }
}

private struct BrandCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let innerPadding: CGFloat
    let fillOpacity: Double

    func body(content: Content) -> some View {
        content
            .padding(innerPadding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(BrandPalette.cardFill.opacity(fillOpacity > 0 ? fillOpacity * 2.2 : 0.16))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(BrandPalette.borderSoft, lineWidth: 1)
                )
            )
            .shadow(color: BrandPalette.cardShadow, radius: 14, x: 0, y: 8)
    }
}

extension View {
    func brandCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16, fillOpacity: Double = 0.08) -> some View {
        modifier(BrandCardModifier(cornerRadius: cornerRadius, innerPadding: padding, fillOpacity: fillOpacity))
    }
}

struct BrandFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(BrandPalette.fieldFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(BrandPalette.borderSoft, lineWidth: 1)
                    )
            )
            .foregroundStyle(BrandPalette.textPrimary)
    }
}

enum Haptics {
    static func success() {
#if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
#endif
    }

    static func warning() {
#if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
#endif
    }

    static func error() {
#if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
#endif
    }
}

enum InputValidator {
    private static let emailRegex = try? NSRegularExpression(
        pattern: #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$"#,
        options: [.caseInsensitive]
    )

    private static let tripIDRegex = try? NSRegularExpression(
        pattern: #"^c[a-z0-9]{24}$"#
    )

    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValidEmail(_ email: String) -> Bool {
        let value = normalize(email)
        guard !value.isEmpty, let emailRegex else { return false }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return emailRegex.firstMatch(in: value, options: [], range: range) != nil
    }

    static func isStrongEnoughPassword(_ password: String) -> Bool {
        password.count >= 8
    }

    static func isValidDays(_ days: Int) -> Bool {
        (1...14).contains(days)
    }

    static func isValidTripID(_ id: String) -> Bool {
        let value = normalize(id)
        guard !value.isEmpty, let tripIDRegex else { return false }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return tripIDRegex.firstMatch(in: value, options: [], range: range) != nil
    }
}
