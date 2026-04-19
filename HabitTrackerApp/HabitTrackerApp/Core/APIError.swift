//
//  APIError.swift
//  HabitTrackerApp
//
//  Mapowanie wspólnego formatu błędów z obu mikroserwisów:
//      { "error": { "code": "...", "message": "...", "details": {...}, "request_id": "..." } }
//

import Foundation

/// Surowy envelope błędu jaki oba serwisy zwracają (patrz README, sekcja 4).
struct ServerErrorEnvelope: Decodable {
    struct ErrorBody: Decodable {
        let code: String
        let message: String
        let requestId: String?

        enum CodingKeys: String, CodingKey {
            case code
            case message
            case requestId = "request_id"
        }
    }
    let error: ErrorBody
}

/// Jednolity typ błędu używany w całej apce.
/// `.server` trzyma kod z backendu (np. `UNAUTHORIZED`, `VALIDATION_ERROR`, ...),
/// pozostałe cases to błędy po stronie klienta/sieci.
enum APIError: LocalizedError, Equatable {
    case server(status: Int, code: String, message: String, requestId: String?)
    case decoding(String)
    case transport(String)
    case unauthorized
    case unknown

    var errorDescription: String? {
        switch self {
        case .server(_, _, let message, _):
            return message
        case .decoding(let detail):
            return "Could not parse server response: \(detail)"
        case .transport(let detail):
            return "Network error: \(detail)"
        case .unauthorized:
            return "Please sign in again."
        case .unknown:
            return "Something went wrong."
        }
    }

    /// Convenience — dla widoków, które chcą zareagować na 401 (wylogowanie).
    var isUnauthorized: Bool {
        switch self {
        case .unauthorized: return true
        case .server(let status, _, _, _): return status == 401
        default: return false
        }
    }
}
