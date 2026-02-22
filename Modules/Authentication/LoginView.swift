//
//  LoginView.swift
//  Tripzync
//

import SwiftUI

struct LoginView: View {

    @EnvironmentObject private var session: AppSession

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    private var normalizedEmail: String {
        InputValidator.normalize(email)
    }

    private var normalizedPassword: String {
        password.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEmailValid: Bool {
        InputValidator.isValidEmail(normalizedEmail)
    }

    private var emailValidationMessage: String? {
        guard !normalizedEmail.isEmpty, !isEmailValid else { return nil }
        return "Enter a valid email address."
    }

    private var canSubmit: Bool {
        !normalizedEmail.isEmpty &&
        !normalizedPassword.isEmpty &&
        isEmailValid &&
        !session.isAuthenticating
    }

    var body: some View {
        ZStack {
            BrandBackground()

            ScrollView {
                VStack(spacing: 20) {
                    Text("Welcome Back")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text("Sign in to continue building smart, time-balanced trip plans.")
                        .font(.body.weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(BrandPalette.textSecondary)

                    VStack(spacing: 14) {
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

                        SecureField("Password", text: $password)
#if os(iOS)
                            .submitLabel(.go)
#endif
                            .focused($focusedField, equals: .password)
                            .onSubmit {
                                if canSubmit {
                                    submitLogin()
                                }
                            }
                            .textFieldStyle(BrandFieldStyle())

                        if let emailValidationMessage {
                            Text(emailValidationMessage)
                                .font(.caption)
                                .foregroundStyle(BrandPalette.accentCoral)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .brandCard()

                    Button {
                        submitLogin()
                    } label: {
                        BrandPrimaryButtonLabel(
                            title: "Sign In",
                            icon: "arrow.right",
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
                        SignupView()
                    } label: {
                        BrandSecondaryButtonLabel(title: "Create Account")
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 28)
            }
        }
        .navigationBarBackButtonHidden(true)
        .tint(BrandPalette.navigationAccent)
        .onAppear {
            focusedField = .email
        }
        .onChange(of: email) { _, _ in
            session.authErrorMessage = nil
        }
        .onChange(of: password) { _, _ in
            session.authErrorMessage = nil
        }
    }

    private func submitLogin() {
        guard canSubmit else { return }

        Task {
            await session.login(email: email, password: password)
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
        LoginView()
            .environmentObject(AppSession())
    }
}
