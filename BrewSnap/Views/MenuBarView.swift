// MenuBarView.swift
// BrewSnap — Menu bar extra (desplegable).

import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox.fill").foregroundStyle(Color(hex: "#FBB040"))
                Text("BrewSnap").font(.headline)
                Spacer()
            }

            if let snap = appState.snapshot {
                Text("Último snapshot: \(snap.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Divider()

            Button {
                Task { await appState.scan() }
            } label: {
                Label(appState.isScanning ? "Escaneando…" : "Create Snapshot", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "#FBB040"))
            .controlSize(.regular)
            .frame(maxWidth: .infinity)
            .disabled(appState.isScanning)

            Button {
                NSApp.activate(ignoringOtherApps: true)
                // Abre la app en grande (centrada y zoom si no está maximizada)
                if let window = NSApp.windows.first(where: { $0.canBecomeKey }) ?? NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                    // Tamaño grande por defecto
                    let targetSize = NSSize(width: 1100, height: 700)
                    var frame = window.frame
                    frame.size = targetSize
                    // Centrar en pantalla
                    if let screen = window.screen ?? NSScreen.main {
                        let screenFrame = screen.visibleFrame
                        frame.origin.x = screenFrame.midX - frame.width / 2
                        frame.origin.y = screenFrame.midY - frame.height / 2
                    }
                    window.setFrame(frame, display: true, animate: true)
                    // Si no está zoomed, maximiza
                    if !window.isZoomed {
                        window.zoom(nil)
                    }
                } else {
                    NSApp.sendAction(Selector(("showWindow:")), to: nil, from: nil)
                }
            } label: {
                Label("Abrir BrewSnap…", systemImage: "arrow.up.left.and.arrow.down.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .frame(maxWidth: .infinity)

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Salir", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "#FF2C2C"))
            .controlSize(.regular)
            .frame(maxWidth: .infinity)
        }
        .padding(12)
        .frame(width: 220)
    }
}
