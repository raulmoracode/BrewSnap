// PointerCursor.swift
// BrewSnap — Reusable pointing-hand cursor on hover.

import SwiftUI
import AppKit

/// Shows a pointing-hand cursor while the pointer is over the wrapped view.
struct PointerCursorModifier: ViewModifier {
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

extension View {
    /// Shows a pointing-hand cursor when hovering this view.
    func pointerCursor() -> some View {
        modifier(PointerCursorModifier())
    }
}