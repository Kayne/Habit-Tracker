//
//  HabitModels.swift
//  HabitTrackerApp
//
//  Codable modele DTO dla habits-service.
//  Patrz habits-service/app/schemas.py
//

import Foundation

// MARK: - FrequencyType

enum FrequencyType: String, Codable, CaseIterable, Identifiable {
    case daily   = "daily"
    case weekly  = "weekly"
    case monthly = "monthly"

    var id: String { rawValue }

    /// Czytelna etykieta dla UI.
    var label: String {
        switch self {
        case .daily:   return "Dziennie"
        case .weekly:  return "Tygodniowo"
        case .monthly: return "Miesięcznie"
        }
    }

    /// Maksymalna wartość target_per_frequency dla danego typu.
    var maxTarget: Int {
        switch self {
        case .daily:   return 99   // np. 5× dziennie wypij wodę
        case .weekly:  return 7
        case .monthly: return 31
        }
    }

    /// Domyślna wartość target_per_frequency dla danego typu.
    var defaultTarget: Int {
        switch self {
        case .daily:   return 1
        case .weekly:  return 7
        case .monthly: return 1
        }
    }

    /// Krótka etykieta wyświetlana przy celu nawyku (np. "3×/tydz.").
    func targetLabel(_ target: Int) -> String {
        switch self {
        case .daily:   return "\(target)×/dzień"
        case .weekly:  return "\(target)×/tydz."
        case .monthly: return "\(target)×/mies."
        }
    }
}

// MARK: - Habit

struct HabitCreateRequest: Encodable {
    let name: String
    let description: String?
    let frequencyType: FrequencyType
    let targetPerFrequency: Int

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case frequencyType = "frequency_type"
        case targetPerFrequency = "target_per_frequency"
    }
}

/// Wszystkie pola opcjonalne — PATCH wysyła tylko to co się zmienia.
/// Używamy `encodeIfPresent` zamiast synthesized encode, żeby nil-e nie trafiły
/// jako `null` — backend potraktowałby je jako "wyczyść pole" (NOT NULL -> 500).
struct HabitUpdateRequest: Encodable {
    let name: String?
    let description: String?
    let frequencyType: FrequencyType?
    let targetPerFrequency: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case frequencyType = "frequency_type"
        case targetPerFrequency = "target_per_frequency"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(frequencyType, forKey: .frequencyType)
        try container.encodeIfPresent(targetPerFrequency, forKey: .targetPerFrequency)
    }
}

struct Habit: Decodable, Identifiable, Equatable, Hashable {
    let id: UUID
    let userId: UUID
    let name: String
    let description: String?
    let frequencyType: FrequencyType
    let targetPerFrequency: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId        = "user_id"
        case name
        case description
        case frequencyType = "frequency_type"
        case targetPerFrequency = "target_per_frequency"
        case createdAt     = "created_at"
    }

    // Ręczny init, żeby `frequency_type` miało fallback na `.weekly`
    // gdy serwer zwróci stary rekord bez tej kolumny (przed migracją).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(UUID.self,   forKey: .id)
        userId        = try c.decode(UUID.self,   forKey: .userId)
        name          = try c.decode(String.self, forKey: .name)
        description   = try c.decodeIfPresent(String.self, forKey: .description)
        frequencyType = (try? c.decode(FrequencyType.self, forKey: .frequencyType)) ?? .weekly
        targetPerFrequency = try c.decode(Int.self,    forKey: .targetPerFrequency)
        createdAt     = try c.decode(Date.self,   forKey: .createdAt)
    }
}

// MARK: - Habit logs

struct HabitLogCreateRequest: Encodable {
    /// `nil` == "dzisiaj" — backend sam wstawi `date.today()`.
    let loggedOn: String?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case loggedOn = "logged_on"
        case note
    }
}

struct HabitLog: Decodable, Identifiable, Equatable {
    let id: UUID
    let habitId: UUID
    /// ISO-8601 date (`YYYY-MM-DD`) zgodnie z pydantic.date.
    let loggedOn: String
    let note: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case habitId   = "habit_id"
        case loggedOn  = "logged_on"
        case note
        case createdAt = "created_at"
    }
}

// MARK: - Stats

struct HabitStats: Decodable, Equatable {
    let habitId: UUID
    let totalLogs: Int
    let currentStreakDays: Int
    let longestStreakDays: Int
    /// Wskaźnik ukończenia za bieżący okres (0.0…1.0).
    /// Dla daily: ostatnie 7 dni / 7.
    /// Dla weekly: ostatnie 7 dni / target_per_frequency.
    /// Dla monthly: ostatnie 30 dni / target_per_frequency.
    let completionRateCurrentPeriod: Double
    let lastLoggedOn: String?

    enum CodingKeys: String, CodingKey {
        case habitId                     = "habit_id"
        case totalLogs                   = "total_logs"
        case currentStreakDays            = "current_streak_days"
        case longestStreakDays            = "longest_streak_days"
        case completionRateCurrentPeriod = "completion_rate_current_period"
        case lastLoggedOn                = "last_logged_on"
    }
}
