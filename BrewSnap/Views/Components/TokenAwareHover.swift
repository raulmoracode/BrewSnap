// TokenAwareHover.swift
// BrewSnap — Reusable token-aware hover feedback for GitHub action buttons.

import SwiftUI
import AppKit

/// Adds token-aware hover feedback to a GitHub action button:
/// - No validated token → `operationNotAllowed` cursor + minimalist tooltip below.
/// - Validated token → `pointingHand` cursor.
struct TokenAwareHoverModifier: ViewModifier {
    @Environment(AppState.self) private var appState
    @State private var isHovering = false
    var requiresRepository = false
    var requiresGit = false

    private var actionIsAvailable: Bool {
        appState.hasGitInstalled &&
            appState.hasGithubToken &&
            (!requiresRepository || appState.hasConfiguredRepo)
    }

    private var tooltipText: String {
        if requiresGit && !appState.hasGitInstalled {
            return "Install Git to use Import and Export"
        }
        if !appState.hasGithubToken {
            return "Set up your GitHub token in Settings"
        }
        return requiresRepository
            ? "No brewsnap-config repository found in your GitHub account"
            : "Go to Settings to create the brewsnap-config repository"
    }

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovering = hovering
                }
                if hovering {
                    if actionIsAvailable {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.operationNotAllowed.push()
                    }
                } else {
                    NSCursor.pop()
                }
            }
            .overlay(alignment: .bottom) {
                TokenHelpTooltip(text: tooltipText)
                    .fixedSize()
                    .opacity(isHovering && !actionIsAvailable ? 1 : 0)
                    .allowsHitTesting(false)
                    .offset(y: 38)
            }
    }
}

extension View {
    /// Adds GitHub token-aware hover feedback (cursor + tooltip).
    func tokenAwareHover(requiresRepository: Bool = false, requiresGit: Bool = false) -> some View {
        modifier(TokenAwareHoverModifier(requiresRepository: requiresRepository, requiresGit: requiresGit))
    }
}

/// Minimalist reminder shown below a GitHub action button when the token is not configured.
struct TokenHelpTooltip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
    }
}