//
//  CatCompanion.swift
//  CraveCircle (AICookBook)
//
//  A chef-hat cat that lives on the Home recipe cards:
//   • STOPPED → peeks over a card's top edge, two paws on the edge, FACING THE USER.
//   • MOVING  → walks (side profile) FACING the travel direction, with a little hop, then peeks.
//   • GRABBED → welded to the finger and hangs from it; drag anywhere (the page can't scroll while
//               held) and release to throw her: she flies from your finger to the card nearest
//               where the throw was heading.
//   • SCROLLING → her playground is the part of the feed on screen. When her card scrolls away she
//               jumps from the screen edge to the nearest card in view, so she follows the user from
//               Fresh in your Circle to Suggested for You and on down, instead of vanishing.
//
//  Coordinates are GLOBAL throughout (cards report `.frame(in: .global)`, the drag uses `.global`,
//  and we convert to the overlay's local space by subtracting its global origin). That keeps the cat
//  welded to the finger no matter how the feed is scrolled — a named/scrolling space drifted them apart.
//

import SwiftUI
import Combine

// MARK: - Card frame reporting

struct CardFrame: Equatable {
    let id: String
    let rect: CGRect        // in GLOBAL coordinates
    let liked: Bool
}

struct CardFramesKey: PreferenceKey {
    static var defaultValue: [CardFrame] = []
    static func reduce(value: inout [CardFrame], nextValue: () -> [CardFrame]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    func reportsCardFrame(id: String, liked: Bool) -> some View {
        background(
            GeometryReader { p in
                Color.clear.preference(key: CardFramesKey.self,
                                       value: [CardFrame(id: id, rect: p.frame(in: .global), liked: liked)])
            }
        )
    }
}

// MARK: - The companion

struct CatCompanion: View {
    let cardFrames: [CardFrame]
    @Binding var catHeld: Bool               // mirrors `held` up so HomeScreen can freeze the scroll

    private static let peekH: CGFloat = 80    // head + paws over the ledge (stopped) — a touch smaller
    private static let moveH: CGFloat = 88    // full body, SIDE-profile walking (faces travel dir)
    private static let hangH: CGFloat = 112   // full body, dangling from the finger
    private static let grip:  CGFloat = 8     // paws overlap onto the card's top edge
    private static let handGap: CGFloat = 40  // gap below the finger so the held cat isn't hidden by the thumb

    @AppStorage("kitchen_cat_enabled") private var enabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var size: CGSize = .zero
    @State private var originG: CGPoint = .zero      // overlay's global origin (for on-screen filtering)
    @State private var currentID: String?
    @State private var fx: CGFloat = 0.5
    @State private var facingRight = true
    @State private var moving = false
    @State private var held = false
    @State private var blink = false
    @State private var dragPoint: CGPoint = .zero    // GLOBAL finger position while held
    @State private var swing: Double = 0
    @State private var lift: CGFloat = 0
    @State private var lastDragX: CGFloat = 0
    @State private var nextHop = Date.distantPast
    @State private var nextBlink = Date.distantPast
    @State private var busyUntil: Date?
    /// GLOBAL centre while she is between cards (mid-throw, or about to jump back into view).
    @State private var freeCenter: CGPoint?
    @State private var lastCenter: CGPoint?      // last on-card centre, for when her card is unloaded
    /// Set when the user drops her on a recipe: she stays put (no wandering) until that card
    /// scrolls away or she is picked up again.
    @State private var placedByUser = false

    private let behavior = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    /// The same recipe can appear in several Home sections under one id. Prefer the copy that is
    /// on screen, or she'd sit on an off-screen twin and look like she vanished.
    private var currentCard: CardFrame? {
        let copies = cardFrames.filter { $0.id == currentID }
        return copies.first(where: isInPlay) ?? copies.first
    }

    var body: some View {
        GeometryReader { geo in
            let og = geo.frame(in: .global).origin
            ZStack {
                if enabled, held || freeCenter != nil || currentCard != nil {
                    let a = sprite()
                    let g = centerGlobal(a.h, og)                 // where the cat should be, in global space
                    Image(a.name)
                        .resizable()
                        .scaledToFit()
                        .frame(height: a.h)
                        .scaleEffect(x: a.flip ? -1 : 1, y: 1)    // face travel direction (side only)
                        .offset(y: lift)                          // little hop while walking
                        .rotationEffect(.degrees(held ? swing : 0), anchor: .top)  // dangle from the finger
                        .contentShape(Rectangle())                // only the sprite is tappable
                        .highPriorityGesture(drag())              // grabbing wins over the scroll
                        .accessibilityLabel("Kitchen cat")
                        .position(x: g.x - og.x, y: g.y - og.y)   // global → overlay-local
                        .animation(nil, value: held)              // grabbing snaps (no ghost cross-fade)
                        .transition(.identity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear { size = geo.size; originG = og }
            .onChange(of: geo.size) { _, s in size = s }
            .onChange(of: og) { _, v in originG = v }
            .onReceive(behavior) { tick($0) }
            // Every scroll frame: the moment her card leaves the screen she jumps back into view,
            // rather than waiting for the next behaviour tick and scrolling off with it.
            .onChange(of: cardFrames) { _, _ in followUser() }
        }
    }

    // MARK: Sprite + placement

    private func sprite() -> (name: String, h: CGFloat, flip: Bool) {
        if held   { return ("ChefCatHang", Self.hangH, false) }                 // dangling from the finger
        if moving { return ("ChefCatWalk", Self.moveH, !facingRight) }          // SIDE walk, faces travel dir
        return (blink ? "ChefCatPeekHappy" : "ChefCatPeek", Self.peekH, false)  // stopped → peek at the user
    }

    private func anchor(_ c: CardFrame) -> CGPoint { CGPoint(x: c.rect.minX + fx * c.rect.width, y: c.rect.minY) }

    /// Where the cat's CENTER belongs, in global coordinates.
    private func centerGlobal(_ h: CGFloat, _ og: CGPoint) -> CGPoint {
        if held { return CGPoint(x: dragPoint.x, y: dragPoint.y + h / 2 + Self.handGap) } // hangs below the finger
        if let f = freeCenter { return f }
        guard let c = currentCard else { return CGPoint(x: og.x + size.width / 2, y: og.y + size.height / 2) }
        return CGPoint(x: anchor(c).x, y: anchor(c).y - h / 2 + Self.grip)      // paws on the card's top edge
    }

    // MARK: Grab · drag · throw

    private func drag() -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { v in
                if !held {
                    held = true; catHeld = true; moving = false; busyUntil = nil; lift = 0; placedByUser = false
                    Haptics.tap(); lastDragX = v.location.x
                }
                dragPoint = v.location                                 // GLOBAL — welded to the finger
                let dx = v.location.x - lastDragX; lastDragX = v.location.x
                swing = max(-24, min(24, Double(dx) * 1.6))
            }
            .onEnded { v in
                // She lands on the recipe she was let go over, and stays there.
                let finger = v.location
                let release = CGPoint(x: dragPoint.x, y: dragPoint.y + Self.hangH / 2 + Self.handGap)
                held = false; catHeld = false
                freeCenter = clamped(release)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { swing = 0 }
                busyUntil = Date().addingTimeInterval(1)               // no autonomous hop mid-air
                DispatchQueue.main.async {
                    guard let dest = dropTarget(finger: finger, paws: release) else { return }
                    placedByUser = true
                    facingRight = anchor(dest).x >= release.x
                    fx = min(max(0.15, (finger.x - dest.rect.minX) / max(1, dest.rect.width)), 0.85)
                    runTo(dest, duration: 0.4)
                }
            }
    }

    // MARK: Autonomous behaviour

    private func isPerchable(_ c: CardFrame) -> Bool {
        c.rect.width > 80 &&
        c.rect.midX > originG.x && c.rect.midX < originG.x + size.width &&
        c.rect.minY > originG.y + Self.peekH * 0.7 + 40 &&
        c.rect.minY < originG.y + size.height - 150
    }

    private func perchable() -> [CardFrame] { cardFrames.filter(isPerchable) }

    /// Still on screen. A card the user dropped her on keeps her until its top edge leaves the
    /// screen, even if it sits lower than where she would pick by herself.
    private func isInPlay(_ c: CardFrame) -> Bool {
        guard placedByUser else { return isPerchable(c) }
        return c.rect.midX > originG.x && c.rect.midX < originG.x + size.width &&
            c.rect.minY > originG.y + Self.peekH * 0.7 && c.rect.minY < originG.y + size.height - 60
    }

    /// The recipe she was dropped on: the card under the finger (or under her paws), if its top
    /// edge is on screen; otherwise the visible card closest to where she was let go.
    private func dropTarget(finger: CGPoint, paws: CGPoint) -> CardFrame? {
        let topVisible: (CardFrame) -> Bool = { c in
            c.rect.width > 80 && c.rect.minY > originG.y + Self.peekH * 0.7 && c.rect.minY < originG.y + size.height - 60
        }
        if let under = cardFrames.first(where: { $0.rect.contains(finger) && topVisible($0) })
            ?? cardFrames.first(where: { $0.rect.contains(paws) && topVisible($0) }) {
            return under
        }
        return perchable().min { a, b in distance(finger, a.rect) < distance(finger, b.rect) }
    }

    private func distance(_ p: CGPoint, _ r: CGRect) -> CGFloat {
        hypot(max(r.minX - p.x, 0, p.x - r.maxX), max(r.minY - p.y, 0, p.y - r.maxY))
    }

    private func nearestCard(to p: CGPoint) -> CardFrame? {
        perchable().min { a, b in
            hypot(anchor(a).x - p.x, a.rect.minY - p.y) < hypot(anchor(b).x - p.x, b.rect.minY - p.y)
        }
    }

    /// The on-screen area she may stand in (global), so a jump never starts off screen.
    private func clamped(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, originG.x + 44), originG.x + size.width - 44),
                y: min(max(p.y, originG.y + Self.peekH + 40), originG.y + size.height - 150))
    }

    /// Her card has scrolled out of the playground: appear at the screen edge she left from and
    /// jump to the nearest card the user can see.
    private func followUser() {
        guard enabled, size != .zero, !held, busyUntil == nil, currentID != nil else { return }
        if let c = currentCard { lastCenter = CGPoint(x: anchor(c).x, y: anchor(c).y - Self.peekH / 2 + Self.grip) }
        guard !(currentCard.map(isInPlay) ?? false), let from = lastCenter else { return }
        placedByUser = false
        let start = clamped(from)
        guard let dest = nearestCard(to: start) else { return }
        freeCenter = start                                   // first frame: at the edge, in view
        busyUntil = Date().addingTimeInterval(1)
        DispatchQueue.main.async {                           // next frame: jump from there
            facingRight = anchor(dest).x >= start.x
            fx = min(max(0.2, (start.x - dest.rect.minX) / max(1, dest.rect.width)), 0.8)
            runTo(dest, duration: reduceMotion ? 0.2 : 0.55)
        }
    }

    private func tick(_ now: Date) {
        guard enabled, size != .zero, !held else { return }
        let visible = perchable()
        guard !visible.isEmpty else { return }

        if currentID == nil {
            currentID = visible.randomElement()!.id; fx = .random(in: 0.25...0.75)
            moving = false; blink = false; busyUntil = nil
            nextHop = now.addingTimeInterval(.random(in: 3.0...5.0))
            nextBlink = now.addingTimeInterval(.random(in: 2.0...4.0))
            return
        }
        // Thrown somewhere with no card, or her card is gone: hop to the nearest one in view.
        if busyUntil == nil, freeCenter != nil || !(currentCard.map(isInPlay) ?? false) {
            placedByUser = false
            let from = freeCenter ?? lastCenter ?? CGPoint(x: originG.x + size.width / 2, y: originG.y + size.height / 2)
            if let dest = nearestCard(to: from) {
                freeCenter = clamped(from)
                facingRight = anchor(dest).x >= from.x
                busyUntil = now.addingTimeInterval(1)
                DispatchQueue.main.async { runTo(dest, duration: 0.55) }
            }
            return
        }

        if let until = busyUntil {
            if now >= until { moving = false; busyUntil = nil
                              nextHop = now.addingTimeInterval(.random(in: 3.0...5.0)) }
            return
        }

        if now >= nextBlink {
            blink.toggle()
            nextBlink = now.addingTimeInterval(blink ? 0.22 : .random(in: 2.5...4.5))
        }

        guard !reduceMotion else { return }

        if now >= nextHop, !placedByUser {
            let liked = visible.filter { $0.liked && $0.id != currentID }
            let pool  = visible.filter { $0.id != currentID }
            if let dest = (Double.random(in: 0...1) < 0.5 ? liked.randomElement() : nil) ?? pool.randomElement() {
                facingRight = anchor(dest).x >= (currentCard.map(anchor)?.x ?? 0)
                fx = .random(in: 0.25...0.75)
                runTo(dest, duration: 0.6)
            }
        }
    }

    /// Walk (side profile, facing travel direction) over to `dest` with a little hop, then peek.
    private func runTo(_ dest: CardFrame, duration: Double) {
        blink = false
        moving = true
        withAnimation(.easeInOut(duration: duration)) { currentID = dest.id; freeCenter = nil }
        withAnimation(.easeOut(duration: duration * 0.45)) { lift = -30 }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.45) {
            withAnimation(.easeIn(duration: duration * 0.45)) { lift = 0 }
        }
        busyUntil = Date().addingTimeInterval(duration)
    }
}

#if DEBUG
#Preview("Chef cat") {
    // Self-check: peeking places the paws on the card's top edge (feet at minY + grip).
    let r = CGRect(x: 40, y: 320, width: 180, height: 220)
    let peekH: CGFloat = 96, grip: CGFloat = 8
    let feet = (r.minY - peekH / 2 + grip) + peekH / 2
    assert(abs(feet - (r.minY + grip)) < 0.001, "paws not on the card edge")
    return ZStack {
        Color(hex: "F5EEE2").ignoresSafeArea()
        RoundedRectangle(cornerRadius: 16).fill(.brown.opacity(0.35))
            .frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY)
        CatCompanion(cardFrames: [CardFrame(id: "demo", rect: r, liked: true)], catHeld: .constant(false))
    }
}
#endif
