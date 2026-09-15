import SwiftUI

@main
struct BrewSnapApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(appState)
                .frame(minWidth: 800, minHeight: 600)
        }
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
