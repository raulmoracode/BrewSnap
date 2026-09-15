// StatusBadge.swift
// BrewSnap — Sync status badge.

import SwiftUI

struct StatusBadge: View {
    enum Status {
        case synced, outOfSync, syncing, error, idle
        var color: Color {
            switch self {
            case .synced: return .green
            case .outOfSync: return .orange
            case .syncing: return .blue
            case .error: return .red
            case .idle: return .secondary
            }
        }
        var label: String {
            switch self {
            case .synced: return "Synced"
            case .outOfSync: return "Out of sync"
            case .syncing: return "Syncing…"
            case .error: return "Error"
            case .idle: return "Idle"
            }
        }
    }

    let status: Status

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(status.color.opacity(0.15), in: Capsule())
            .foregroundStyle(status.color)
    }
}
