import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox.fill").foregroundStyle(Color(hex: "#FBB040"))
                Text("BrewSnap").font(.headline)
                Spacer()
                if let snap = appState.snapshot {
                    Text("\(snap.formulaeCount) · \(snap.casksCount)").font(.caption.monospaced()).foregroundStyle(.secondary)
                }
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
            }.disabled(appState.isScanning)

            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            } label: { Label("Abrir BrewSnap…", systemImage: "arrow.up.left.and.arrow.down.right") }

            Divider()

            Button("Salir") { NSApplication.shared.terminate(nil) }
        }
        .padding(12)
        .frame(width: 280)
    }
}

private extension Color {
    init(hex: String) {
        let h = hex.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0; Scanner(string: h).scanHexInt64(&rgb)
        self.init(.sRGB, red: Double((rgb >> 16) & 0xFF)/255, green: Double((rgb >> 8) & 0xFF)/255, blue: Double(rgb & 0xFF)/255, opacity: 1)
    }
}
