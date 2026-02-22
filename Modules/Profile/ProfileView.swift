//
//  ProfileView.swift
//  Tripzync
//

import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {

    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUpdatingPhoto = false
    @State private var isRefreshing = false
    @State private var photoErrorMessage: String?
    @State private var infoMessage: String?

    private var displayName: String {
        guard let rawName = session.currentUser?.name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawName.isEmpty else {
            return "Traveler"
        }
        return rawName
    }

    private var initials: String {
        let words = displayName
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
            .joined()
        return words.isEmpty ? "T" : words
    }

    var body: some View {
        ZStack {
            BrandBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Profile")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandPalette.textPrimary)

                    profileHeaderCard
                    quickActionsCard
                    accountDetailsCard
                    appearanceCard
                    securityCard

                    if let infoMessage {
                        Text(infoMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BrandPalette.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .brandCard(cornerRadius: 14, padding: 12, fillOpacity: 0.09)
                    }

                    Spacer(minLength: 28)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .tint(BrandPalette.navigationAccent)
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                await applySelectedPhoto(newValue)
            }
        }
    }

    private var profileHeaderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                avatarPicker

                VStack(alignment: .leading, spacing: 5) {
                    Text(displayName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text(session.currentUser?.email ?? "No active session")
                        .font(.subheadline)
                        .foregroundStyle(BrandPalette.textSecondary)

                    if let user = session.currentUser {
                        Text("Member since \(AppDateFormatter.tripDate.string(from: user.createdAt))")
                            .font(.caption)
                            .foregroundStyle(BrandPalette.textMuted)
                    }
                }

                Spacer()

                if isUpdatingPhoto {
                    ProgressView()
                        .tint(BrandPalette.accentCoral)
                }
            }

            if let photoErrorMessage {
                Text(photoErrorMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(BrandPalette.accentCoral)
            }
        }
        .brandCard()
    }

    private var avatarPicker: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let data = session.profilePhotoData, let image = image(from: data) {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                        Text(initials)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(BrandPalette.textPrimary)
                    }
                }
            }
            .frame(width: 106, height: 106)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            )

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack {
                    Circle()
                        .fill(BrandPalette.accentGradient)
                        .frame(width: 32, height: 32)
                    Image(systemName: "camera.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline.weight(.semibold))
                .foregroundStyle(BrandPalette.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink {
                    DestinationSearchView()
                } label: {
                    ProfileActionTile(
                        title: "New Trip",
                        subtitle: "Create itinerary",
                        icon: "plus.circle.fill"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    SavedTripsView()
                } label: {
                    ProfileActionTile(
                        title: "My Trips",
                        subtitle: "View all saved",
                        icon: "suitcase.rolling.fill"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await refreshAccount()
                    }
                } label: {
                    ProfileActionTile(
                        title: isRefreshing ? "Refreshing..." : "Refresh",
                        subtitle: "Sync account data",
                        icon: "arrow.clockwise.circle.fill"
                    )
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)

                Button {
                    copyEmailToClipboard()
                } label: {
                    ProfileActionTile(
                        title: "Copy Email",
                        subtitle: "Share quickly",
                        icon: "doc.on.doc.fill"
                    )
                }
                .buttonStyle(.plain)
                .disabled(session.currentUser == nil)
                .opacity(session.currentUser == nil ? 0.55 : 1)
            }
        }
        .brandCard()
    }

    private var accountDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Details")
                .font(.headline.weight(.semibold))
                .foregroundStyle(BrandPalette.textPrimary)

            if let user = session.currentUser {
                ProfileDetailRow(label: "Name", value: displayName, icon: "person.text.rectangle")
                ProfileDetailRow(label: "Email", value: user.email, icon: "envelope.fill")
                ProfileDetailRow(label: "User ID", value: user.id, icon: "number.square.fill")
                ProfileDetailRow(label: "Joined", value: AppDateFormatter.tripDate.string(from: user.createdAt), icon: "calendar")
            } else {
                Text("No active session")
                    .font(.subheadline)
                    .foregroundStyle(BrandPalette.textSecondary)
            }
        }
        .brandCard()
    }

    private var securityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Security")
                .font(.headline.weight(.semibold))
                .foregroundStyle(BrandPalette.textPrimary)

            if session.profilePhotoData != nil {
                Button {
                    if session.updateProfilePhoto(nil) {
                        photoErrorMessage = nil
                        showInfo("Profile photo removed.")
                    } else {
                        photoErrorMessage = "Unable to remove photo. Try again."
                    }
                } label: {
                    ProfileMenuButton(title: "Remove Profile Photo", icon: "trash")
                }
                .buttonStyle(.plain)
            }

            Button(role: .destructive) {
                session.logout()
            } label: {
                ProfileMenuButton(title: "Log Out", icon: "rectangle.portrait.and.arrow.right", isDestructive: true)
            }
            .buttonStyle(.plain)
        }
        .brandCard()
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.headline.weight(.semibold))
                .foregroundStyle(BrandPalette.textPrimary)

            Toggle(isOn: Binding(
                get: { themeManager.isLightModeEnabled },
                set: { themeManager.isLightModeEnabled = $0 }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Light Mode")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text("Enable a bright interface across all screens.")
                        .font(.caption)
                        .foregroundStyle(BrandPalette.textSecondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: BrandPalette.accentCoral))
        }
        .brandCard()
    }

    private func applySelectedPhoto(_ item: PhotosPickerItem) async {
        isUpdatingPhoto = true
        defer {
            isUpdatingPhoto = false
            selectedPhotoItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else {
                photoErrorMessage = "Unable to load selected image."
                return
            }

            if session.updateProfilePhoto(data) {
                photoErrorMessage = nil
                showInfo("Profile photo updated.")
            } else {
                photoErrorMessage = "Unable to save photo. Please try again."
            }
        } catch {
            photoErrorMessage = "Unable to access photo library image."
        }
    }

    private func refreshAccount() async {
        isRefreshing = true
        await session.refreshIfNeededOnResume()
        isRefreshing = false
        showInfo("Account refreshed.")
    }

    private func copyEmailToClipboard() {
        guard let email = session.currentUser?.email, !email.isEmpty else { return }
        UIPasteboard.general.string = email
        showInfo("Email copied.")
    }

    private func showInfo(_ message: String) {
        infoMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if infoMessage == message {
                infoMessage = nil
            }
        }
    }

    private func image(from data: Data) -> Image? {
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }
}

private struct ProfileActionTile: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(BrandPalette.accentCoral)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandPalette.textPrimary)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(BrandPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard(cornerRadius: 16, padding: 12, fillOpacity: 0.09)
    }
}

private struct ProfileDetailRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandPalette.accentCoral)
                .frame(width: 22, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandPalette.textMuted)

                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BrandPalette.textPrimary)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct ProfileMenuButton: View {
    let title: String
    let icon: String
    var isDestructive = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isDestructive ? Color.red.opacity(0.95) : BrandPalette.accentCoral)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isDestructive ? Color.red.opacity(0.95) : BrandPalette.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isDestructive ? Color.red.opacity(0.10) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isDestructive ? Color.red.opacity(0.25) : Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AppSession())
            .environmentObject(ThemeManager())
    }
}
