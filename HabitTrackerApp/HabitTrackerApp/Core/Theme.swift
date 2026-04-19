//
//  Theme.swift
//  HabitTrackerApp
//
//  Paleta kolorów aplikacji. Źródło:
//    https://coolors.co/99621e-d38b5d-f3ffb6-739e82-2c5530
//
//  Dajemy zarówno "surowe" kolory (ochre / copper / cream / sage / forest),
//  jak i semantyczne aliasy (primary / accent / detail / highlight) — widoki
//  używają aliasów, bo gdy kiedyś zmienimy paletę, nie trzeba będzie chodzić
//  po całej apce.
//

import SwiftUI

enum Theme {

    // MARK: - Raw palette

    /// #99621e — ciemny ochre / złoty brąz.
    static let ochre  = Color(hex: 0x99621E)

    /// #d38b5d — miedziany / ciepły tan.
    static let copper = Color(hex: 0xD38B5D)

    /// #f3ffb6 — pastelowa śmietankowa żółć (highlight).
    static let cream  = Color(hex: 0xF3FFB6)

    /// #739e82 — sage / stonowana zieleń.
    static let sage   = Color(hex: 0x739E82)

    /// #2c5530 — ciemna leśna zieleń (akcent primary).
    static let forest = Color(hex: 0x2C5530)

    // MARK: - Semantic aliases

    /// Główny kolor akcji (przyciski, tint globalny, aktywny stan).
    static let primary = forest

    /// Miększy wariant dla stanów wtórnych / "OK" / progresu.
    static let secondary = sage

    /// Ciepły akcent dla rzeczy "gorących" (streak, płomień, nagroda).
    static let accent = copper

    /// Detal tekstowy / subtelne podkreślenie.
    static let detail = ochre

    /// Tło podświetlenia (cards, hero sections).
    static let highlight = cream
}

// MARK: - Color hex init

extension Color {
    /// Inicjalizator z 6-cyfrowego hexa (np. `0x99621E`).
    /// Trzymamy prosto — bez wsparcia dla alphy i stringów, bo to wystarcza
    /// dla statycznej palety zdefiniowanej w kodzie.
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
