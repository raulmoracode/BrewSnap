// Color+Hex.swift
// BrewSnap — Extensión compartida para colores hex de marca (#FBB040, #1D3557).

import SwiftUI

extension Color {
    /// Inicializa un Color desde hex string (ej. "#FBB040" o "FBB040").
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: 1
        )
    }
}
