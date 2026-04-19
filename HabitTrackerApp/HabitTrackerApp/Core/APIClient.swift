//
//  APIClient.swift
//  HabitTrackerApp
//
//  Warstwa nad URLSession:
//    - generyczne `send` (JSON in, JSON out)
//    - mapowanie wspólnego error-envelope na APIError
//    - wstrzykiwanie Bearer JWT
//

import Foundation

struct APIClient {

    // MARK: - Init

    let baseURL: URL
    /// Closure, a nie stały String, bo token może się zmienić w trakcie życia apki
    /// (login → mamy token, logout → brak). APIClient nie musi o tym wiedzieć.
    let tokenProvider: @MainActor () -> String?

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseURL: URL,
        tokenProvider: @escaping @MainActor () -> String?,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.session = session

        self.encoder = JSONEncoder()
        // Backend oczekuje snake_case na poziomie pól — ale my mamy jawne
        // CodingKeys w każdym DTO, więc nie ustawiamy keyEncodingStrategy.

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            // Backend (Pydantic + Postgres TIMESTAMP) zwraca daty w trzech wariantach:
            //   1) "2026-04-17T10:30:00.123456+00:00"  — ISO-8601 z TZ i frakcją
            //   2) "2026-04-17T10:30:00+00:00"         — ISO-8601 z TZ, bez frakcji
            //   3) "2026-04-17T10:26:00.864334"        — naive (bez TZ) — traktujemy jako UTC
            // Wariant 3 jest częsty gdy kolumna w Postgresie jest `TIMESTAMP` a nie `TIMESTAMPTZ`.
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = APIClient.isoWithFractional.date(from: string) {
                return date
            }
            if let date = APIClient.isoWithoutFractional.date(from: string) {
                return date
            }
            if let date = APIClient.naiveWithFractional.date(from: string) {
                return date
            }
            if let date = APIClient.naiveWithoutFractional.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date format: \(string)"
            )
        }
    }

    // MARK: - Request API

    /// Wysyła request i dekoduje odpowiedź do `T`.
    func send<T: Decodable>(
        _ method: HTTPMethod,
        path: String,
        body: Encodable? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        let data = try await performRequest(
            method: method,
            path: path,
            body: body,
            authenticated: authenticated,
            expectEmpty: false
        )
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    /// Wariant dla endpointów zwracających 204 No Content (np. DELETE).
    func sendEmpty(
        _ method: HTTPMethod,
        path: String,
        body: Encodable? = nil,
        authenticated: Bool = true
    ) async throws {
        _ = try await performRequest(
            method: method,
            path: path,
            body: body,
            authenticated: authenticated,
            expectEmpty: true
        )
    }

    // MARK: - Private

    private func performRequest(
        method: HTTPMethod,
        path: String,
        body: Encodable?,
        authenticated: Bool,
        expectEmpty: Bool
    ) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try encoder.encode(AnyEncodable(body))
            } catch {
                throw APIError.decoding("Failed to encode request body: \(error)")
            }
        }

        if authenticated, let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        if (200..<300).contains(http.statusCode) {
            if expectEmpty { return Data() }
            return data
        }

        // Error path — próbujemy sparsować envelope z backendu
        if let envelope = try? decoder.decode(ServerErrorEnvelope.self, from: data) {
            throw APIError.server(
                status: http.statusCode,
                code: envelope.error.code,
                message: envelope.error.message,
                requestId: envelope.error.requestId
            )
        }

        // 401 bez parsowalnego body — i tak interesuje nas głównie, że to auth.
        if http.statusCode == 401 {
            throw APIError.unauthorized
        }

        throw APIError.server(
            status: http.statusCode,
            code: "UNKNOWN",
            message: "Request failed with status \(http.statusCode).",
            requestId: nil
        )
    }

    // MARK: - Date formatters

    /// np. "2026-04-17T10:30:00.123456+00:00"
    private static let isoWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// np. "2026-04-17T10:30:00+00:00" (gdy backend ucina .0)
    private static let isoWithoutFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// np. "2026-04-17T10:26:00.864334" — Pydantic z Postgres TIMESTAMP bez TZ.
    /// Zakładamy UTC po stronie backendu (typowe dla naive datetime).
    private static let naiveWithFractional: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// np. "2026-04-17T10:26:00" — naive bez frakcji.
    private static let naiveWithoutFractional: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}

// MARK: - HTTP method

enum HTTPMethod: String {
    case GET, POST, PATCH, DELETE, PUT
}

// MARK: - Encodable type erasure

/// Pozwala przekazać dowolny `Encodable` jako nieswobodny parametr `body`.
private struct AnyEncodable: Encodable {
    private let encodeFn: (Encoder) throws -> Void
    init(_ wrapped: Encodable) {
        self.encodeFn = wrapped.encode
    }
    func encode(to encoder: Encoder) throws {
        try encodeFn(encoder)
    }
}
