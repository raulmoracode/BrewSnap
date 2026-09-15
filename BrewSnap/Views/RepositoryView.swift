import SwiftUI

struct RepositoryView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "shippingbox.fill")
                        .font(.title)
                        .foregroundStyle(Color(hex: "#FBB040"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BrewSnap").font(.title2.bold())
                        Text("Tu entorno Homebrew, sincronizado y protegido")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Text("Proyecto open source — cualquier persona puede visitar el repositorio, ver el código, reportar issues o contribuir.")
                    .font(.callout).foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                RepoCard(
                    title: "raulmoracode/brewsnap",
                    subtitle: "App, releases (DMG) y documentación",
                    url: "https://github.com/raulmoracode/brewsnap",
                    icon: "chevron.left.forwardslash.chevron.right",
                    color: Color(hex: "#1D3557")
                )
                RepoCard(
                    title: "raulmoracode/homebrew-tap",
                    subtitle: "Tap para brew install raulmoracode/tap/brewsnap",
                    url: "https://github.com/raulmoracode/homebrew-tap",
                    icon: "arrow.down.circle.fill",
                    color: Color(hex: "#FBB040")
                )
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Instalación rápida", systemImage: "terminal.fill").font(.headline)
                    Text("brew install raulmoracode/tap/brewsnap")
                        .font(.system(.callout, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                        .textSelection(.enabled)
                    HStack(spacing: 12) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("brew install raulmoracode/tap/brewsnap", forType: .string)
                        } label: { Label("Copiar", systemImage: "doc.on.doc") }
                        .buttonStyle(.bordered).controlSize(.small)
                        Link(destination: URL(string: "https://github.com/raulmoracode/brewsnap/releases")!) {
                            Label("Ver releases", systemImage: "tag.fill")
                        }.controlSize(.small)
                    }
                }.padding(4)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Info", systemImage: "info.circle.fill").font(.headline)
                    LabeledContent("Bundle ID", value: "com.raulmorasanchez.BrewSnap").font(.callout)
                    LabeledContent("Licencia", value: "MIT").font(.callout)
                    LabeledContent("Requiere", value: "macOS 15+ · Homebrew").font(.callout)
                    HStack {
                        Link("Reportar issue", destination: URL(string: "https://github.com/raulmoracode/brewsnap/issues/new")!)
                        Text("·").foregroundStyle(.secondary)
                        Link("Discussions", destination: URL(string: "https://github.com/raulmoracode/brewsnap/discussions")!)
                    }.font(.callout)
                }.padding(4)
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct RepoCard: View {
    let title: String
    let subtitle: String
    let url: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(color, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).fontDesign(.monospaced)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                Link(destination: URL(string: url)!) {
                    Label(url.replacingOccurrences(of: "https://", with: ""), systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
            }
            Spacer()
            Link(destination: URL(string: url)!) {
                Text("Abrir").font(.callout.weight(.semibold))
            }
            .buttonStyle(.borderedProminent).tint(color).controlSize(.small)
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary, lineWidth: 1))
    }
}

private extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0; Scanner(string: h).scanHexInt64(&rgb)
        self.init(.sRGB, red: Double((rgb >> 16) & 0xFF)/255, green: Double((rgb >> 8) & 0xFF)/255, blue: Double(rgb & 0xFF)/255, opacity: 1)
    }
}

#Preview { RepositoryView().frame(width: 700, height: 600) }
