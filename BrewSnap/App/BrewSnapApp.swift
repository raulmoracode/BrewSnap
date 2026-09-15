// BrewSnapApp.swift
// BrewSnap — Entry point (WindowGroup + MenuBarExtra + Settings).

import SwiftUI

@main
struct BrewSnapApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(appState)
                .frame(minWidth: 1000, idealWidth: 1100, minHeight: 650, idealHeight: 700)
        }
        .defaultSize(width: 1100, height: 700)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About BrewSnap") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "BrewSnap",
                            .applicationVersion: "1.0.0",
                            .credits: NSAttributedString(string: "Tu entorno Homebrew, sincronizado y protegido.")
                        ]
                    )
                }
            }
        }

        MenuBarExtra("BrewSnap", systemImage: "shippingbox.fill") {
            MenuBarView()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appState)
                .frame(width: 520, height: 420)
        }
    }
}
