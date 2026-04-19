//
//  HabitsStore.swift
//  HabitTrackerApp
//
//  Store dla habits-service — lista nawyków + operacje CRUD + logi + statystyki.
//  Tworzony raz w HabitTrackerAppApp.swift, dzielony przez wszystkie widoki
//  potrzebujące danych o nawykach.
//

import Foundation
import Observation

@Observable
final class HabitsStore {

    // MARK: - Published state

    private(set) var habits: [Habit] = []
    private(set) var isLoading: Bool = false
    var errorMessage: String?

    /// Cache logów i statystyk per habitId — ładowane na żądanie z HabitDetailView.
    private(set) var logs: [UUID: [HabitLog]] = [:]
    private(set) var stats: [UUID: HabitStats] = [:]

    // MARK: - Dependencies

    private let client: APIClient
    /// Trzymamy referencję na AuthStore, żeby przy 401 wymusić logout.
    private weak var auth: AuthStore?

    // MARK: - Init

    init(auth: AuthStore) {
        self.auth = auth
        self.client = APIClient(
            baseURL: AppConfig.habitsBaseURL,
            tokenProvider: { [weak auth] in auth?.accessToken }
        )
    }

    // MARK: - Habits: CRUD

    func loadHabits() async {
        await run {
            self.habits = try await self.client.send(.GET, path: "/habits")
        }
    }

    func createHabit(name: String, description: String?, targetPerWeek: Int) async -> Bool {
        var created: Habit?
        await run {
            let payload = HabitCreateRequest(
                name: name,
                description: description?.isEmpty == true ? nil : description,
                targetPerWeek: targetPerWeek
            )
            let habit: Habit = try await self.client.send(
                .POST, path: "/habits", body: payload
            )
            // Optymistycznie wrzucamy na początek listy (backend sortuje DESC po created_at).
            self.habits.insert(habit, at: 0)
            created = habit
        }
        return created != nil
    }

    func updateHabit(
        id: UUID,
        name: String?,
        description: String?,
        targetPerWeek: Int?
    ) async -> Bool {
        var ok = false
        await run {
            let payload = HabitUpdateRequest(
                name: name,
                description: description,
                targetPerWeek: targetPerWeek
            )
            let updated: Habit = try await self.client.send(
                .PATCH, path: "/habits/\(id.uuidString.lowercased())", body: payload
            )
            if let idx = self.habits.firstIndex(where: { $0.id == id }) {
                self.habits[idx] = updated
            }
            ok = true
        }
        return ok
    }

    func deleteHabit(id: UUID) async {
        await run {
            try await self.client.sendEmpty(
                .DELETE, path: "/habits/\(id.uuidString.lowercased())"
            )
            self.habits.removeAll { $0.id == id }
            self.logs[id] = nil
            self.stats[id] = nil
        }
    }

    // MARK: - Logs

    /// Zaloguj dzisiejsze wykonanie nawyku. Backend chroni przed duplikatem (409).
    func logToday(habitId: UUID, note: String? = nil) async {
        await run {
            let payload = HabitLogCreateRequest(loggedOn: nil, note: note)
            let log: HabitLog = try await self.client.send(
                .POST, path: "/habits/\(habitId.uuidString.lowercased())/logs",
                body: payload
            )
            var existing = self.logs[habitId] ?? []
            existing.insert(log, at: 0)
            self.logs[habitId] = existing
            // Statystyki się zmieniły — wyrzuć z cache aby się odświeżyły.
            self.stats[habitId] = nil
        }
    }

    func loadLogs(habitId: UUID) async {
        await run {
            let fetched: [HabitLog] = try await self.client.send(
                .GET, path: "/habits/\(habitId.uuidString.lowercased())/logs"
            )
            self.logs[habitId] = fetched
        }
    }

    // MARK: - Stats

    func loadStats(habitId: UUID) async {
        await run {
            let s: HabitStats = try await self.client.send(
                .GET, path: "/habits/\(habitId.uuidString.lowercased())/stats"
            )
            self.stats[habitId] = s
        }
    }

    // MARK: - Lifecycle

    /// Używane na wylogowanie — czyścimy wszystko, co nie powinno przeciec do nowego usera.
    func reset() {
        habits = []
        logs = [:]
        stats = [:]
        errorMessage = nil
    }

    // MARK: - Private

    private func run(_ action: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await action()
        } catch let apiError as APIError {
            if apiError.isUnauthorized {
                // Token wygasł — wymuszamy logout w AuthStore, UI wróci na ekran logowania.
                auth?.logout()
                reset()
            }
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
