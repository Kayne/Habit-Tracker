//
//  HabitModels.swift
//  HabitTrackerApp
//
//  Codable modele DTO dla habits-service.
//  Patrz habits-service/app/schemas.py
//

import Foundation

// MARK: - Habit

struct HabitCreateRequest: Encodable {
    let name: String
    let description: String?
    let targetPerWeek: Int  // 1..7

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case targetPerWeek = "target_per_week"
    }
}

/// Wszystkie pola opcjonalne — PATCH wysyła tylko to co się zmienia.
/// Używamy `encodeIfPresent` zamiast synthesized encode, żeby nil-e nie trafiły
/// jako `null` — backend potraktowałby je jako "wyczyść pole" (NOT NULL -> 500).
struct HabitUpdateRequest: Encodable {
    let name: String?
    let description: String?
    let targetPerWeek: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case targetPerWeek = "target_per_week"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(targetPerWeek, forKey: .targetPerWeek)
    }
}

struct Habit: Decodable, Identifiable, Equatable, Hashable {
    let id: UUID
    let userId: UUID
    let name: String
    let description: String?
    let targetPerWeek: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId        = "user_id"
        case name
        case description
        case targetPerWeek = "target_per_week"
        case createdAt     = "created_at"
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
    let completionRate7d: Double   // 0.0 … 1.0
    let lastLoggedOn: String?

    enum CodingKeys: String, CodingKey {
        case habitId           = "habit_id"
        case totalLogs         = "total_logs"
        case currentStreakDays = "current_streak_days"
        case longestStreakDays = "longest_streak_days"
        case completionRate7d  = "completion_rate_7d"
        case lastLoggedOn      = "last_logged_on"
    }
}
