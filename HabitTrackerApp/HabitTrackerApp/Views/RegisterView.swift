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
                Section {
                    AuthHeroHeader(
                        title: "Załóż konto",
                        subtitle: "Zacznij śledzić swoje nawyki."
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Dane") {
                    TextField("Nazwa wyświetlana", text: $displayName)
                        .textContentType(.name)

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Hasło (min. 8 znaków)", text: $password)
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
                            if auth.isLoggedIn { dismiss() }
                        }
                    } label: {
                        HStack {
                            if auth.isLoading { ProgressView().padding(.trailing, 4) }
                            Text("Utwórz konto")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primary)
                    .disabled(!canSubmit)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Rejestracja")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                        .foregroundStyle(Theme.detail)
                }
            }
            .alert(
                "Nie udało się zarejestrować",
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
        .tint(Theme.primary)
}
