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

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovering = hovering
                }
                if hovering {
                    if appState.hasGithubToken {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.operationNotAllowed.push()
                    }
                } else {
                    NSCursor.pop()
                }
            }
            .overlay(alignment: .bottom) {
                TokenHelpTooltip()
                    .fixedSize()
                    .opacity(isHovering && !appState.hasGithubToken ? 1 : 0)
                    .allowsHitTesting(false)
                    .offset(y: 38)
            }
    }
}

extension View {
    /// Adds GitHub token-aware hover feedback (cursor + tooltip).
    func tokenAwareHover() -> some View {
        modifier(TokenAwareHoverModifier())
    }
}

/// Minimalist reminder shown below a GitHub action button when the token is not configured.
struct TokenHelpTooltip: View {
    var body: some View {
        Text("Set up your GitHub token in Settings")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
    }
}