//
//  GroceryCat.swift
//  CraveCircle (AICookBook)
//
//  A chef-cat that "fishes" your grocery list: she clings over an UNCHECKED item, JUMPS item → item
//  like the Home cat (side-profile walk facing travel direction + hop arc), and FALLS (the leaping
//  ChefCatFall sprite) to the next item the moment the one she's on is checked off. When the whole list
//  is checked she hides.
//
//  She is also CATCHABLE exactly like the Home cat: touch her and she hangs from your finger (with the
//  same handGap below the touch), the page freezes so the drag can't be cancelled, and on release she
//  flies to the nearest item and resumes. Only the sprite is interactive — checkboxes stay tappable.
//
//  Coordinates are GLOBAL (rows report `.frame(in: .global)`), converted to overlay-local for drawing.
//  Art: ChefCatCling · ChefCatWalk (hop) · ChefCatFall (checked) · ChefCatHang (held).
//

import SwiftUI
import Combine

// MARK: - Grocery row reporting

struct GRow: Equatable {
    let id: String
    let rect: CGRect        // GLOBAL
    let done: Bool
}

struct GRowKey: PreferenceKey {
    static var defaultValue: [GRow] = []
    static func reduce(value: inout [GRow], nextValue: () -> [GRow]) { value.append(contentsOf: nextValue()) }
}

extension View {
    func reportsGroceryRow(id: String, done: Bool) -> some View {
        background(
            GeometryReader { p in
                Color.clear.preference(key: GRowKey.self,
                                       value: [GRow(id: id, rect: p.frame(in: .global), done: done)])
            }
        )
    }
}

// MARK: - The grocery cat

struct GroceryCat: View {
    let rows: [GRow]
    @Binding var catHeld: Bool               // mirrors `held` up so GroceryScreen can freeze the scroll

    private static let clingH: CGFloat = 74
    private static let moveH:  CGFloat = 86
    private static let fallH:  CGFloat = 104
    private static let hangH:  CGFloat = 112
    private static let grip:   CGFloat = 6
    private static let handGap: CGFloat = 40  // gap below the finger so the held cat isn't hidden by the thumb

    @AppStorage("kitchen_cat_enabled") private var enabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var size: CGSize = .zero
    @State private var originG: CGPoint = .zero
    @State private var currentID: String?
    @State private var fx: CGFloat = 0.6
    @State private var facingRight = true
    @State private var moving = false
    @State private var falling = false
    @State private var held = false
    @State private var lift: CGFloat = 0
    @State private var fallY: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var tumble: Double = 0
    @State private var swing: Double = 0
    @State private var dragPoint: CGPoint = .zero    // GLOBAL finger position while held
    @State private var lastDragX: CGFloat = 0
    @State private var nextHop = Date.distantPast
    @State private var busyUntil: Date?

    private let behavior = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    private var current: GRow? { rows.first { $0.id == currentID } }

    var body: some View {
        GeometryReader { geo in
            let og = geo.frame(in: .global).origin
            ZStack {
                if enabled, held || current != nil {
                    let s = sprite()
                    let g = centerGlobal(s.h, og)
                    Image(s.name)
                        .resizable()
                        .scaledToFit()
                        .frame(height: s.h)
                        .scaleEffect(x: s.flip ? -1 : 1, y: 1)               // face travel direction (walk only)
                        .offset(y: lift)                                     // hop arc
                        .rotationEffect(.degrees(held ? swing : (falling ? tumble : 0)),
                                        anchor: held ? .top : .center)       // dangle-swing / fall-tumble
                        .opacity(opacity)
                        .contentShape(Rectangle())
                        .highPriorityGesture(drag())                         // catch & drag like Home
                        .accessibilityLabel("Kitchen cat")
                        .position(x: g.x - og.x, y: g.y - og.y)
                        .animation(nil, value: held)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear { size = geo.size; originG = og }
            .onChange(of: geo.size) { _, s in size = s }
            .onChange(of: og) { _, v in originG = v }
            .onReceive(behavior) { tick($0) }
        }
    }

    private func sprite() -> (name: String, h: CGFloat, flip: Bool) {
        if held    { return ("ChefCatHang", Self.hangH, false) }
        if falling { return ("ChefCatFall", Self.fallH, false) }
        if moving  { return ("ChefCatWalk", Self.moveH, !facingRight) }
        return ("ChefCatCling", Self.clingH, false)
    }

    private func anchor(_ r: GRow) -> CGPoint { CGPoint(x: r.rect.minX + fx * r.rect.width, y: r.rect.minY) }

    private func centerGlobal(_ h: CGFloat, _ og: CGPoint) -> CGPoint {
        if held { return CGPoint(x: dragPoint.x, y: dragPoint.y + h / 2 + Self.handGap) }  // hangs below finger
        guard let c = current else { return CGPoint(x: og.x + size.width / 2, y: og.y + size.height / 2) }
        return CGPoint(x: anchor(c).x, y: anchor(c).y - h / 2 + Self.grip + fallY)          // paws on row edge (+fall)
    }

    // MARK: Catch · drag · throw (mirrors the Home cat)

    private func drag() -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { v in
                if !held {
                    held = true; catHeld = true; moving = false; falling = false
                    busyUntil = nil; lift = 0; fallY = 0; opacity = 1; tumble = 0
                    Haptics.tap(); lastDragX = v.location.x
                }
                dragPoint = v.location
                let dx = v.location.x - lastDragX; lastDragX = v.location.x
                swing = max(-24, min(24, Double(dx) * 1.6))
            }
            .onEnded { v in
                held = false; catHeld = false
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { swing = 0 }
                let target = v.predictedEndLocation
                if let dest = nearestRow(to: target) { hop(to: dest, from: nil, fx: throwFx(target, dest)) }
                nextHop = Date().addingTimeInterval(.random(in: 2.5...4.0))
            }
    }

    private func throwFx(_ target: CGPoint, _ dest: GRow) -> CGFloat {
        min(max(0.3, (target.x - dest.rect.minX) / max(1, dest.rect.width)), 0.75)
    }

    // MARK: Behaviour

    private func onscreen(_ r: GRow) -> Bool {
        r.rect.width > 60 &&
        r.rect.minY > originG.y + Self.clingH * 0.6 + 20 &&
        r.rect.minY < originG.y + size.height - 110
    }

    private func targets() -> [GRow] { rows.filter { !$0.done && onscreen($0) } }

    private func nearestRow(to p: CGPoint) -> GRow? {
        let pool = targets().isEmpty ? rows.filter(onscreen) : targets()
        return pool.min { hypot(anchor($0).x - p.x, $0.rect.minY - p.y) < hypot(anchor($1).x - p.x, $1.rect.minY - p.y) }
    }

    private func tick(_ now: Date) {
        guard enabled, size != .zero, !held else { return }
        if let until = busyUntil { if now >= until { busyUntil = nil; moving = false }; return }

        if let c = current, c.done, !falling { startFall(); return }

        let avail = targets()
        if current == nil || !avail.contains(where: { $0.id == currentID }) {
            guard let pick = avail.first else { currentID = nil; return }
            currentID = pick.id; fx = .random(in: 0.45...0.7)
            moving = false; lift = 0; fallY = 0; opacity = 1; tumble = 0
            nextHop = now.addingTimeInterval(.random(in: 2.5...4.0))
            return
        }

        guard !reduceMotion else { return }

        if now >= nextHop, avail.count > 1, let idx = avail.firstIndex(where: { $0.id == currentID }) {
            hop(to: avail[(idx + 1) % avail.count], from: current, fx: .random(in: 0.45...0.7))
            nextHop = now.addingTimeInterval(.random(in: 2.5...4.0))
        }
    }

    /// Walk + hop over to `dest` (same feel as the Home cat).
    private func hop(to dest: GRow, from cur: GRow?, fx newFx: CGFloat) {
        if let cur = cur {
            facingRight = anchor(dest).x >= anchor(cur).x
        } else {
            facingRight = anchor(dest).x >= dragPoint.x
        }
        moving = true; falling = false
        withAnimation(.easeInOut(duration: 0.5)) { currentID = dest.id; fx = newFx }
        withAnimation(.easeOut(duration: 0.25)) { lift = -34 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeIn(duration: 0.25)) { lift = 0 }
        }
        busyUntil = Date().addingTimeInterval(0.5)
    }

    private func startFall() {
        falling = true; moving = false; lift = 0
        Haptics.tap()
        withAnimation(.easeIn(duration: 0.55)) { fallY = 360; tumble = 30; opacity = 0 }
        busyUntil = Date().addingTimeInterval(0.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            falling = false; fallY = 0; tumble = 0; opacity = 1
            currentID = targets().first?.id
            if currentID != nil { fx = .random(in: 0.45...0.7) }
            nextHop = Date().addingTimeInterval(.random(in: 2.0...3.5))
        }
    }
}

#if DEBUG
#Preview("Grocery cat") {
    let r = CGRect(x: 20, y: 300, width: 360, height: 52)
    let h: CGFloat = 74, grip: CGFloat = 6
    let feet = (r.minY - h / 2 + grip) + h / 2
    assert(abs(feet - (r.minY + grip)) < 0.001, "paws not on the row edge")
    return ZStack {
        Color(hex: "F5EEE2").ignoresSafeArea()
        RoundedRectangle(cornerRadius: 10).fill(.white)
            .frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY)
        GroceryCat(rows: [GRow(id: "a", rect: r, done: false)], catHeld: .constant(false))
    }
}
#endif
