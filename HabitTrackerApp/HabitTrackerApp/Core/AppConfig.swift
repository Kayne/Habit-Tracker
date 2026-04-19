//
//  AppConfig.swift
//  HabitTrackerApp
//
//  Statyczna konfiguracja klienta — adresy backendowych mikroserwisów.
//  W prostej wersji hardkodujemy localhost (docker compose na tym samym Macu).
//

import Foundation

enum AppConfig {
    /// auth-service — rejestracja / logowanie / /auth/me
    static let authBaseURL: URL = URL(string: "http://localhost:8001")!

    /// habits-service — CRUD nawyków, logi, statystyki
    static let habitsBaseURL: URL = URL(string: "http://localhost:8002")!
}
