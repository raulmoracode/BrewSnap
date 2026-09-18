// PackageRow.swift
// BrewSnap — Package row (name + version).

import SwiftUI

struct PackageRow: View {
    let name: String
    let version: String
    var tap: String? = nil
    var isPinned: Bool = false
    var homepage: String? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name).font(.system(.body, design: .monospaced)).lineLimit(1)
                    if isPinned { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.orange) }
                }
                if let tap { Text(tap).font(.caption2).foregroundStyle(.secondary) }
            }
            Spacer()
            if let homepage, let url = URL(string: homepage) {
                Link(destination: url) {
                    Image(systemName: "link")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#FBB040"))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(homepage)
                .pointerCursor()
            }
            Text(version).font(.caption.monospaced()).foregroundStyle(Color(hex: "#FBB040"))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
        }
        .padding(.vertical, 4)
    }
}

struct CaskRow: View {
    let cask: BrewCask
    var body: some View {
        PackageRow(name: cask.name, version: cask.version, tap: cask.tap, homepage: cask.homepage)
    }
}