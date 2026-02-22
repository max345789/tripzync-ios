//
//  SignupView.swift
//  Tripzync
//

import SwiftUI

struct SignupView: View {

    @EnvironmentObject private var session: AppSession

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case email
        case password
    }

    private var normalizedEmail: String {
        InputValidator.normalize(email)
    }

    private var isEmailValid: Bool {
        InputValidator.isValidEmail(normalizedEmail)
    }

    private var hasStrongEnoughPassword: Bool {
        InputValidator.isStrongEnoughPassword(password)
    }

    private var emailValidationMessage: String? {
        guard !normalizedEmail.isEmpty, !isEmailValid else { return nil }
        return "Enter a valid email address."
    }

    private var passwordValidationMessage: String? {
        guard !password.isEmpty, !hasStrongEnoughPassword else { return nil }
        return "Password must be at least 8 characters."
    }

    private var canSubmit: Bool {
        !normalizedEmail.isEmpty &&
        isEmailValid &&
        hasStrongEnoughPassword &&
        !session.isAuthenticating
    }

    var body: some View {
        ZStack {
            BrandBackground()

            ScrollView {
                VStack(spacing: 20) {
                    Text("Create Account")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text("Set up your Tripzync workspace and start generating daily plans.")
                        .font(.body.weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(BrandPalette.textSecondary)

                    VStack(spacing: 14) {
                        TextField("Name (optional)", text: $name)
#if os(iOS)
                            .submitLabel(.next)
#endif
                            .focused($focusedField, equals: .name)
                            .onSubmit {
                                focusedField = .email
                            }
                            .textFieldStyle(BrandFieldStyle())

                        TextField("Email", text: $email)
#if os(iOS)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
#endif
                            .focused($focusedField, equals: .email)
                            .onSubmit {
                                focusedField = .password
                            }
                            .textFieldStyle(BrandFieldStyle())

                        SecureField("Password (min 8 chars)", text: $password)
#if os(iOS)
                            .submitLabel(.go)
#endif
                            .focused($focusedField, equals: .password)
                            .onSubmit {
                                if canSubmit {
                                    submitSignup()
                                }
                            }
                            .textFieldStyle(BrandFieldStyle())

                        if let emailValidationMessage {
                            Text(emailValidationMessage)
                                .font(.caption)
                                .foregroundStyle(BrandPalette.accentCoral)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if let passwordValidationMessage {
                            Text(passwordValidationMessage)
                                .font(.caption)
                                .foregroundStyle(BrandPalette.accentCoral)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("Use at least 8 characters for account security.")
                                .font(.caption)
                                .foregroundStyle(BrandPalette.textMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .brandCard()

                    Button {
                        submitSignup()
                    } label: {
                        BrandPrimaryButtonLabel(
                            title: "Sign Up",
                            icon: "sparkles",
                            isLoading: session.isAuthenticating
                        )
                    }
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1 : 0.58)

                    if let message = session.authErrorMessage {
                        Text(message)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(BrandPalette.accentCoral)
                            .multilineTextAlignment(.center)
                            .brandCard(cornerRadius: 14, padding: 12, fillOpacity: 0.09)
                    }

                    NavigationLink {
                        LoginView()
                    } label: {
                        BrandSecondaryButtonLabel(title: "Sign In")
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Sign Up")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .tint(BrandPalette.navigationAccent)
        .onAppear {
            focusedField = .name
        }
        .onChange(of: name) { _, _ in
            session.authErrorMessage = nil
        }
        .onChange(of: email) { _, _ in
            session.authErrorMessage = nil
        }
        .onChange(of: password) { _, _ in
            session.authErrorMessage = nil
        }
    }

    private func submitSignup() {
        guard canSubmit else { return }

        Task {
            await session.register(
                email: email,
                password: password,
                name: name.isEmpty ? nil : name
            )
            if session.state == .authenticated {
                Haptics.success()
            } else if session.authErrorMessage != nil {
                Haptics.error()
            }
        }
    }
}

#Preview {
    NavigationStack {
        SignupView()
            .environmentObject(AppSession())
    }
}
