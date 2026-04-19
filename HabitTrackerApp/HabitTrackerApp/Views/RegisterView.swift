//
//  RegisterView.swift
//  HabitTrackerApp
//
//  Formularz rejestracji — prezentowany jako sheet nad LoginView.
//  Po sukcesie AuthStore od razu loguje, więc sheet się sam zamknie
//  (ContentView zareaguje na isLoggedIn i pokaże HabitsListView).
//

import SwiftUI

struct RegisterView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var displayName: String = ""

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
            && password.count >= 8
            && !displayName.trimmingCharacters(in: .whitespaces).isEmpty
            && !auth.isLoading
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your info") {
                    TextField("Display name", text: $displayName)
                        .textContentType(.name)

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Password (min 8 chars)", text: $password)
                        .textContentType(.newPassword)
                }

                Section {
                    Button {
                        Task {
                            await auth.register(
                                email: email,
                                password: password,
                                displayName: displayName
                            )
                            // Jeśli register się udał, AuthStore od razu zalogował
                            // i ustawił accessToken — zamykamy sheet.
                            if auth.isLoggedIn { dismiss() }
                        }
                    } label: {
                        HStack {
                            if auth.isLoading { ProgressView().padding(.trailing, 4) }
                            Text("Create account")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle("Register")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert(
                "Could not register",
                isPresented: errorBinding,
                actions: { Button("OK", role: .cancel) {} },
                message: { Text(auth.errorMessage ?? "") }
            )
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
    RegisterView()
        .environment(AuthStore())
}
