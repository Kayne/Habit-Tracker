//
//  LoginView.swift
//  HabitTrackerApp
//
//  Ekran logowania. Minimalny — hero header + dwa pola + przycisk + link do rejestracji.
//

import SwiftUI

struct LoginView: View {
    @Environment(AuthStore.self) private var auth

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showRegister: Bool = false

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
            && password.count >= 1
            && !auth.isLoading
    }

    var body: some View {
        NavigationStack {
            Form {
                // Cały hero siedzi w pierwszej sekcji bez tytułu — dzięki temu
                // wygląda jak "karta" a nie zwykły nagłówek listy.
                Section {
                    AuthHeroHeader(
                        title: "Habit Tracker",
                        subtitle: "Małe kroki. Codziennie."
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Konto") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Hasło", text: $password)
                        .textContentType(.password)
                }

                Section {
                    Button {
                        Task { await auth.login(email: email, password: password) }
                    } label: {
                        HStack {
                            if auth.isLoading { ProgressView().padding(.trailing, 4) }
                            Text("Zaloguj się")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primary)
                    .disabled(!canSubmit)
                    .listRowBackground(Color.clear)
                }

                Section {
                    Button {
                        showRegister = true
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Załóż konto")
                        }
                        .foregroundStyle(Theme.detail)
                    }
                }
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .alert(
                "Nie udało się zalogować",
                isPresented: errorBinding,
                actions: { Button("OK", role: .cancel) {} },
                message: { Text(auth.errorMessage ?? "") }
            )
            .sheet(isPresented: $showRegister) {
                RegisterView()
                    .environment(auth)
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { auth.errorMessage != nil },
            set: { if !$0 { auth.errorMessage = nil } }
        )
    }
}

// MARK: - Hero header (współdzielone Login/Register)

struct AuthHeroHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient z cream → sage tworzy ciepły, "naturalny" wizerunek.
            LinearGradient(
                colors: [Theme.highlight, Theme.secondary.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .padding(.bottom, 4)

                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.detail)
            }
            .padding(20)
        }
        .frame(height: 180)
    }
}

#Preview {
    LoginView()
        .environment(AuthStore())
        .tint(Theme.primary)
}
