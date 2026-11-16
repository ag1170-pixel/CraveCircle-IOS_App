//
//  CatCompanion.swift
//  CraveCircle (AICookBook)
//
//  A chef-hat cat that lives on the Home recipe cards:
//   • STOPPED → peeks over a card's top edge, two paws on the edge, FACING THE USER.
//   • MOVING  → walks (side profile) FACING the travel direction, with a little hop, then peeks.
//   • GRABBED → welded to the finger and hangs from it; drag anywhere (the page can't scroll while
//               held) and release to throw her onto the nearest card.
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

    private let behavior = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    private var currentCard: CardFrame? { cardFrames.first { $0.id == currentID } }

    var body: some View {
        GeometryReader { geo in
            let og = geo.frame(in: .global).origin
            ZStack {
                if enabled, held || currentCard != nil {
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
        guard let c = currentCard else { return CGPoint(x: og.x + size.width / 2, y: og.y + size.height / 2) }
        return CGPoint(x: anchor(c).x, y: anchor(c).y - h / 2 + Self.grip)      // paws on the card's top edge
    }

    // MARK: Grab · drag · throw

    private func drag() -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { v in
                if !held {
                    held = true; catHeld = true; moving = false; busyUntil = nil; lift = 0
                    Haptics.tap(); lastDragX = v.location.x
                }
                dragPoint = v.location                                 // GLOBAL — welded to the finger
                let dx = v.location.x - lastDragX; lastDragX = v.location.x
                swing = max(-24, min(24, Double(dx) * 1.6))
            }
            .onEnded { v in
                held = false; catHeld = false
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { swing = 0 }
                let target = v.predictedEndLocation                    // GLOBAL throw target
                if let dest = nearestCard(to: target) {
                    facingRight = anchor(dest).x >= dragPoint.x
                    fx = min(max(0.15, (target.x - dest.rect.minX) / max(1, dest.rect.width)), 0.85)
                    runTo(dest, duration: 0.5)
                }
                nextHop = Date().addingTimeInterval(.random(in: 3.0...5.0))
            }
    }

    // MARK: Autonomous behaviour

    private func perchable() -> [CardFrame] {
        cardFrames.filter { c in
            c.rect.width > 80 &&
            c.rect.midX > originG.x && c.rect.midX < originG.x + size.width &&
            c.rect.minY > originG.y + Self.peekH * 0.7 + 40 &&
            c.rect.minY < originG.y + size.height - 150
        }
    }

    private func nearestCard(to p: CGPoint) -> CardFrame? {
        perchable().min { a, b in
            hypot(anchor(a).x - p.x, a.rect.minY - p.y) < hypot(anchor(b).x - p.x, b.rect.minY - p.y)
        }
    }

    private func tick(_ now: Date) {
        guard enabled, size != .zero, !held else { return }
        let visible = perchable()
        guard !visible.isEmpty else { return }

        if currentID == nil || !visible.contains(where: { $0.id == currentID }) {
            currentID = visible.randomElement()!.id; fx = .random(in: 0.25...0.75)
            moving = false; blink = false; busyUntil = nil
            nextHop = now.addingTimeInterval(.random(in: 3.0...5.0))
            nextBlink = now.addingTimeInterval(.random(in: 2.0...4.0))
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

        if now >= nextHop {
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
        withAnimation(.easeInOut(duration: duration)) { currentID = dest.id }
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
