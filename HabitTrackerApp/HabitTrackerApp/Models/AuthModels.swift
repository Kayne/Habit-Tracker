//
//  AuthModels.swift
//  HabitTrackerApp
//
//  Codable modele DTO dla auth-service.
//  Nazwy pól 1:1 z pydantic-schematami — patrz auth-service/app/schemas.py
//

import Foundation

// MARK: - Request bodies

struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case displayName = "display_name"
    }
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

// MARK: - Responses

struct TokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType   = "token_type"
        case expiresIn   = "expires_in"
    }
}

struct UserResponse: Decodable, Identifiable, Equatable {
    let id: UUID
    let email: String
    let displayName: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case createdAt   = "created_at"
    }
}
