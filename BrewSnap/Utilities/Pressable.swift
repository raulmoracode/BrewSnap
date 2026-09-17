// Pressable.swift
// BrewSnap — Press-down physics (Apple Design §1).
// Native bordered buttons already respond on press; plain-style controls
// don't, so this adds the instant 0.97 press + release feedback to them.

import SwiftUI

private struct PressScaleModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressing && !reduceMotion ? 0.97 : 1.0)
            .opacity(pressing ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.1), value: pressing)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressing = true }
                    .onEnded { _ in pressing = false }
            )
    }
}

extension View {
    /// Instant press feedback for controls without a native pressed state.
    func pressable() -> some View {
        modifier(PressScaleModifier())
    }
}
