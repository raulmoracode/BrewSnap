// RepositoryView.swift
// BrewSnap — Public links to the repo.

import SwiftUI

struct RepositoryView: View {
    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "shippingbox.fill")
                        .font(.title)
                        .foregroundStyle(Color(hex: "#FBB040"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BrewSnap").font(.title2.bold())
                        Text("Your Homebrew environment, synced and protected")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Text("Open source project - anyone can visit the repository, view the code, report issues or contribute.")
                    .font(.callout).foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                RepoCard(
                    title: "raulmoracode/brewsnap",
                    subtitle: "App, releases (DMG) and documentation",
                    url: "https://github.com/raulmoracode/brewsnap",
                    icon: "chevron.left.forwardslash.chevron.right",
                    color: Color(hex: "#1D3557")
                )
                RepoCard(
                    title: "raulmoracode/homebrew-tap",
                    subtitle: "Tap for brew install raulmoracode/tap/brewsnap",
                    url: "https://github.com/raulmoracode/homebrew-tap",
                    icon: "arrow.down.circle.fill",
                    color: Color(hex: "#FBB040")
                )
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

    // MARK: - Private Views

    private var resolvedURL: URL? {
        URL(string: url)
    }

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
                if let resolvedURL {
                    Link(destination: resolvedURL) {
                        Label(url.replacingOccurrences(of: "https://", with: ""), systemImage: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
            }
            Spacer()
            if let resolvedURL {
                Link(destination: resolvedURL) {
                    Text("Open").font(.callout.weight(.semibold))
                }
                .buttonStyle(.borderedProminent).tint(color).controlSize(.small)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary, lineWidth: 1))
    }
}

#Preview { RepositoryView().frame(width: 700, height: 600) }
