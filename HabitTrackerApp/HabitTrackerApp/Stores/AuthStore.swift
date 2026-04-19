//
//  AuthStore.swift
//  HabitTrackerApp
//
//  Globalny store dla stanu uwierzytelnienia.
//  Trzyma JWT w Keychainie i dane zalogowanego usera w pamięci.
//
//  Wstrzykiwany jako @Environment(AuthStore.self) — ContentView decyduje
//  na jego podstawie, czy pokazać login czy listę nawyków.
//

import Foundation
import Observation

@Observable
final class AuthStore {

    // MARK: - UserDefaults keys

    /// Klucz pod którym trzymamy ostatnio używany email (do pre-fillowania
    /// pola na ekranie logowania). TYLKO email — hasła nie trzymamy.
    static let lastUsedEmailKey = "lastUsedEmail"

    // MARK: - Published state

    /// Aktualny token. `nil` == niezalogowany.
    private(set) var accessToken: String?

    /// Dane usera po /auth/me. `nil` dopóki nie dociągniemy.
    private(set) var currentUser: UserResponse?

    /// Trwa request (login / register / me).
    private(set) var isLoading: Bool = false

    /// Ostatni błąd do pokazania w UI (np. alert).
    var errorMessage: String?

    // MARK: - Dependencies

    private let client: APIClient

    // MARK: - Init

    init() {
        // Token z Keychaina (jeśli był zapisany w poprzedniej sesji).
        self.accessToken = KeychainStore.loadToken()

        // Ważne: APIClient dostaje closure pobierający token,
        // więc po zmianie `accessToken` klient od razu używa świeżego.
        // Zapisujemy self przed tworzeniem clienta żeby uniknąć capture-before-init.
        var tokenRef: () -> String? = { nil }
        self.client = APIClient(
            baseURL: AppConfig.authBaseURL,
            tokenProvider: { tokenRef() }
        )
        tokenRef = { [weak self] in self?.accessToken }
    }

    // MARK: - Computed

    var isLoggedIn: Bool { accessToken != nil }

    // MARK: - Auth actions

    func register(email: String, password: String, displayName: String) async {
        await run {
            let payload = RegisterRequest(
                email: email,
                password: password,
                displayName: displayName
            )
            // Po rejestracji backend zwraca UserResponse, ale NIE tokena.
            // Dlatego od razu logujemy aby dostać JWT.
            let _: UserResponse = try await self.client.send(
                .POST, path: "/auth/register",
                body: payload, authenticated: false
            )
            try await self.loginInternal(email: email, password: password)
        }
    }

    func login(email: String, password: String) async {
        await run {
            try await self.loginInternal(email: email, password: password)
        }
    }

    func logout() {
        KeychainStore.deleteToken()
        accessToken = nil
        currentUser = nil
    }

    /// Pobiera /auth/me — używamy po wejściu do apki, żeby zweryfikować
    /// czy token z Keychaina nadal jest ważny (mógł wygasnąć).
    func fetchCurrentUser() async {
        guard isLoggedIn else { return }
        await run {
            let user: UserResponse = try await self.client.send(.GET, path: "/auth/me")
            self.currentUser = user
        }
    }

    // MARK: - Private helpers

    private func loginInternal(email: String, password: String) async throws {
        let payload = LoginRequest(email: email, password: password)
        let tokenResponse: TokenResponse = try await client.send(
            .POST, path: "/auth/login",
            body: payload, authenticated: false
        )
        self.accessToken = tokenResponse.accessToken
        KeychainStore.saveToken(tokenResponse.accessToken)

        // Zapamiętujemy email do pre-fillowania formularza przy następnym
        // logowaniu (patrz LoginView). Hasła NIE trzymamy — tylko email.
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        UserDefaults.standard.set(trimmed, forKey: Self.lastUsedEmailKey)

        // Token mamy — od razu pobieramy /me dla display_name na UI.
        let user: UserResponse = try await client.send(.GET, path: "/auth/me")
        self.currentUser = user
    }

    /// Zawija wywołanie w loading + error handling.
    /// Trzyma jedną konwencję dla wszystkich akcji auth-store'a.
    private func run(_ action: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await action()
        } catch let apiError as APIError {
            // Token wygasł / zły — sprzątamy stan.
            if apiError.isUnauthorized {
                logout()
            }
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
