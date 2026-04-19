//
//  LoginView.swift
//  HabitTrackerApp
//
//  Ekran logowania. Minimalny — dwa pola + przycisk + link do rejestracji.
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
                Section("Account") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }

                Section {
                    Button {
                        Task { await auth.login(email: email, password: password) }
                    } label: {
                        HStack {
                            if auth.isLoading { ProgressView().padding(.trailing, 4) }
                            Text("Log in")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSubmit)
                }

                Section {
                    Button("Create an account") { showRegister = true }
                }
            }
            .navigationTitle("Habit Tracker")
            .alert(
                "Login failed",
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

#Preview {
    LoginView()
        .environment(AuthStore())
}
