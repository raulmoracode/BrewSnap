// MenuBarView.swift
// BrewSnap — Menu bar extra (dropdown).

import SwiftUI
import AppKit

struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    // MARK: - Body

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox.fill").foregroundStyle(Color(hex: "#FBB040"))
                Text("BrewSnap").font(.headline)
                Spacer()
            }

            if let snap = appState.snapshot {
                Text("Last snapshot: \(snap.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Divider()

            Button {
                Task { await appState.scan() }
            } label: {
                Label(appState.isScanning ? "Scanning…" : "Create Snapshot", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "#FBB040"))
            .controlSize(.regular)
            .frame(maxWidth: .infinity)
            .handCursor()
            .disabled(appState.isScanning)

            Button {
                NSApp.activate(ignoringOtherApps: true)
                if let miniaturized = NSApp.windows.first(where: { $0.isMiniaturized }) {
                    miniaturized.deminiaturize(nil)
                    miniaturized.makeKeyAndOrderFront(nil)
                    enlargeAndZoom(window: miniaturized)
                    return
                }
                if let window = NSApp.windows.first(where: { $0.canBecomeKey }) ?? NSApp.windows.first {
                    if !window.isVisible { window.setIsVisible(true) }
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                    enlargeAndZoom(window: window)
                    return
                }
                NSApp.sendAction(Selector(("showWindow:")), to: nil, from: nil)
            } label: {
                Label("Abrir BrewSnap…", systemImage: "arrow.up.left.and.arrow.down.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .frame(maxWidth: .infinity)
            .handCursor()

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
            .handCursor()
        }
        .padding(12)
        .frame(width: 220)
        .onAppear {
            // Center the dropdown window (was left-aligned to the icon)
            DispatchQueue.main.async {
                // MenuBarExtra window is a NSPanel with isFloatingPanel
                let candidates = NSApp.windows.filter { $0.isVisible && String(describing: type(of: $0)).contains("Panel") }
                let target = candidates.first ?? NSApp.keyWindow ?? NSApp.mainWindow
                guard let window = target, let screen = window.screen ?? NSScreen.main else { return }
                var frame = window.frame
                // Center horizontally on screen, just below menu bar (not left of icon)
                frame.origin.x = screen.visibleFrame.midX - frame.width / 2
                frame.origin.y = screen.visibleFrame.maxY - frame.height - 8
                window.setFrame(frame, display: true, animate: false)
            }
        }
    }

    private func enlargeAndZoom(window: NSWindow) {
        let targetSize = NSSize(width: 1100, height: 700)
        var frame = window.frame
        frame.size = targetSize
        if let screen = window.screen ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            frame.origin.x = screenFrame.midX - frame.width / 2
            frame.origin.y = screenFrame.midY - frame.height / 2
        }
        window.setFrame(frame, display: true, animate: true)
        if !window.isZoomed {
            window.zoom(nil)
        }
    }
}

private struct HandCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

private extension View {
    func handCursor() -> some View {
        modifier(HandCursorModifier())
    }
}
