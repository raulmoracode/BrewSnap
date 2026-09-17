// HookSidebar.swift
// React source: use client, CORNER 6, DASH repeating-linear-gradient, Rail + HookSidebar
// Adaptado a SwiftUI + proyecto BrewSnap (icons + href, color proyecto #FBB040)

import SwiftUI
import AppKit

// MARK: - Item (string | {label, href} + icon para BrewSnap)

struct HookSidebarItem: Identifiable, Hashable {
    let id = UUID()
    let label: String
    var icon: String? = nil
    var href: String? = nil
    static func plain(_ label: String, icon: String? = nil) -> Self { HookSidebarItem(label: label, icon: icon, href: nil) }
    static func link(_ label: String, href: String, icon: String? = nil) -> Self { HookSidebarItem(label: label, icon: icon, href: href) }
}

// MARK: - Center measurement (equiv. ResizeObserver offsetTop + height/2)

private struct CenterKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) { value.merge(nextValue(), uniquingKeysWith: { $1 }) }
}

// MARK: - Rail (equiv. const Rail = ({from,y,visible,color,dashed}) => motion.span)

private struct Rail: View {
    var from: CGFloat = 0
    var y: CGFloat?
    var visible: Bool
    var color: Color = Color(hex: "#FC4C01") // React default #FC4C01
    var dashed: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let corner: CGFloat = 6

    var body: some View {
        ZStack(alignment: .topLeading) {
            if visible, let y {
                let h = max(0, y - corner - from)
                if h > 0 {
                    Rectangle().stroke(color, style: StrokeStyle(lineWidth: 1, lineCap: .butt, dash: dashed ? [2, 2] : []))
                        .frame(width: 1, height: h).offset(x: 2, y: from) // left-0.5 w-px exact React
                }
                HookCorner(color: color, dashed: dashed).frame(width: 12, height: 7).offset(x: 2, y: y - corner)
            } else if visible, let y {
                // hover above active with no vertical (from == y-corner)
                HookCorner(color: color, dashed: dashed).frame(width: 12, height: 7).offset(x: 2, y: y - corner)
            }
        }
        .opacity(visible && y != nil ? 1 : 0)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: visible)
        .animation(reduceMotion ? .none : .interpolatingSpring(stiffness: 420, damping: 34).asSpring(), value: y)
        .animation(reduceMotion ? .none : .interpolatingSpring(stiffness: 420, damping: 34).asSpring(), value: from)
        .allowsHitTesting(false)
    }
}

private extension Animation {
    func asSpring() -> Animation { self }
}

private struct HookCorner: View {
    var color: Color
    var dashed: Bool
    var body: some View {
        // Curva exacta React: M0.5 0 a6 6 0 0 0 6 6 H12 — quarter circle r6
        Path { p in
            p.move(to: CGPoint(x: 0.5, y: 0))
            p.addArc(
                center: CGPoint(x: 6.5, y: 0),
                radius: 6,
                startAngle: .degrees(180),
                endAngle: .degrees(90),
                clockwise: true   // 👈 este es el cambio
            )
            p.addLine(to: CGPoint(x: 12, y: 6))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 1, lineCap: .butt, lineJoin: .miter, dash: dashed ? [2, 2] : []))
        .frame(width: 12, height: 7)
    }
}
// MARK: - HookSidebar (equiv. export function HookSidebar)

struct HookSidebar: View {
    let items: [HookSidebarItem]
    var label: String? = nil
    @Binding var selectedIndex: Int
    var color: Color = Color(hex: "#FC4C01") // React default, en BrewSnap se pasa #FBB040
    var dashed: Bool = true
    var showsRail: Bool = true
    var onSelect: ((Int) -> Void)? = nil

    @State private var centers: [Int: CGFloat] = [:]
    @State private var hoverIndex: Int? = nil
    @State private var pointerInside = false
    @State private var focusInside = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var activeY: CGFloat? {
        guard selectedIndex >= 0, selectedIndex < items.count else { return nil }
        return centers[selectedIndex]
    }
    private var hoverY: CGFloat? { hoverIndex.flatMap { centers[$0] } }
    private var hoverFrom: CGFloat {
        if let ay = activeY, let hy = hoverY, hy <= ay { return max(0, hy - 6) }
        return activeY ?? 0
    }

    var body: some View {
        // nav data-slot="hook-sidebar" aria-label={label} className="flex flex-col"
        VStack(alignment: .leading, spacing: 0) {
            if let label {
                // span data-slot="hook-sidebar-label" class="pb-3 pl-0.5 pr-2 font-sans text-sm font-medium uppercase tracking-wide text-foreground"
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .tracking(0.6) // tracking-wide
                    .textCase(.uppercase)
                    .foregroundStyle(Color.primary)
                    .padding(.leading, 2) // pl-0.5
                    .padding(.trailing, 8) // pr-2
                    .padding(.bottom, 12) // pb-3
            }
            // div ref={listRef} onMouseLeave gap-0.5 relative flex flex-col
            ZStack(alignment: .topLeading) {
                if showsRail {
                    // Rail hover: from={hoverFrom} y={hoverY} visible={(pointerInside||focusInside)&&hoverIndex!==activeIndex} dashed text-foreground/30
                    Rail(from: hoverFrom, y: hoverY, visible: (pointerInside || focusInside) && hoverIndex != selectedIndex, color: Color.primary.opacity(0.30), dashed: dashed)
                    // Rail active: y={activeY} visible={activeY!==null} color={color} dashed
                    Rail(y: activeY, visible: activeY != nil, color: color, dashed: dashed)
                }
                VStack(alignment: .leading, spacing: 2) { // gap-0.5
                    ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                        let isActive = idx == selectedIndex
                        let isHovered = hoverIndex == idx
                        row(for: item, isActive: isActive, isHovered: isHovered, index: idx)
                            .background(GeometryReader { proxy in
                                Color.clear.preference(key: CenterKey.self, value: [idx: proxy.frame(in: .named("HookSidebar")).midY])
                            })
                    }
                }
            }
            .coordinateSpace(name: "HookSidebar")
            .onPreferenceChange(CenterKey.self) { centers = $0 }
            .onHover { inside in
                pointerInside = inside
                if !inside { hoverIndex = nil }
            }
        }
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: hoverIndex)
    }

    @ViewBuilder
    private func row(for item: HookSidebarItem, isActive: Bool, isHovered: Bool, index: Int) -> some View {
        // rounded-lg py-1.5 pl-5 pr-2 text-left text-sm transition-colors duration-200
        // isActive ? text-foreground : text-foreground/50 hover:text-foreground/80
        let textColor: Color = isActive ? Color.primary : (isHovered ? Color.primary.opacity(0.8) : Color.primary.opacity(0.5))
        let content = HStack(spacing: 8) {
            if let icon = item.icon {
                Image(systemName: icon).font(.system(size: 12.5, weight: .regular)).foregroundStyle(isActive ? Color.primary : (isHovered ? Color.primary.opacity(0.8) : Color.secondary)).frame(width: 16)
            }
            Text(item.label).font(.system(size: 13, weight: isActive ? .semibold : .regular)).foregroundStyle(textColor).lineLimit(1)
            Spacer()
        }
        .padding(.vertical, 5) // py-1.5
        .padding(.leading, 3) // pl-3 (rail removed, items closer to the edge)
        .padding(.top, -5)
        .padding(.trailing, 8) // pr-2
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.clear)) // no fill, rail is indicator
        .contentShape(Rectangle())
        Group {
            if let href = item.href, let url = URL(string: href) {
                Button { NSWorkspace.shared.open(url) } label: { content }
                    .buttonStyle(.plain)
                    .pressable()
                    .onHover { h in
                        if h { hoverIndex = index; pointerInside = true } else if hoverIndex == index { hoverIndex = nil }
                        if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
            } else {
                Button { select(index) } label: { content }
                    .buttonStyle(.plain)
                    .pressable()
                    .onHover { h in
                        if h { hoverIndex = index; pointerInside = true } else if hoverIndex == index { hoverIndex = nil }
                        if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
            }
        }
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func select(_ idx: Int) {
        if items[idx].href != nil { return } // links don't change selection (equiv. routed href)
        selectedIndex = idx
        onSelect?(idx)
    }
}
