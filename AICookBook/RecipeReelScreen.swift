//
//  RecipeReelScreen.swift
//  CraveCircle (AICookBook)
//
//  Discover = full-screen vertical reel of recipes (one per screen, swipe up/down to page), Instagram
//  styled: bottom-right rail (like / comment / share / save), bottom-left creator lockup.
//  Pull-to-refresh at the top.
//
//  No cat here — the chef-cat lives on Home + Grocery; Discover stays focused on the reel.
//
//  Reused APIs (per Ponytail):
//   • `environment.suggestedRecipes` + fallback curated, filtered personal-use-safe.
//   • Like: `toggleLikeRecipe` / `isLiked`.  Save: `toggleSaveRecipe` / `isSaved`.
//   • Follow: `toggleFollow` / `isFollowing` (tap to follow / unfollow, same button).
//   • Share: native iOS share sheet via `ShareLink` on the cravecircle.cc universal link.
//   • Full detail: `environment.selectRecipe(_:in:)`.
//
//  Responsive: safe-area insets + relative sizing — scales from SE to 16 Pro Max.
//

import SwiftUI
import Combine

/// Head card after an explicit Discovery refresh.
/// `.scrollPosition` stays pinned if the on-screen id is still in the shuffle, so a multi-item
/// list that still contains `currentID` must land on a different id. A missing id, or a one-card
/// list, keeps the first (only) item — first appear must not use this, or it jumps off card one.
enum DiscoveryReelRefresh {
    static func nextHead(currentID: String?, ids: [String]) -> String? {
        guard let first = ids.first else { return nil }
        guard let currentID, ids.count > 1, ids.contains(currentID) else { return first }
        return first == currentID ? ids[1] : first
    }

    /// Cards not already in the on-screen stack. Falls back to `candidates` when every one was shown.
    static func unseenPool(shown: [String], candidates: [String]) -> [String] {
        let shownSet = Set(shown)
        let fresh = candidates.filter { !shownSet.contains($0) }
        return fresh.isEmpty ? candidates : fresh
    }

    /// Suggestion cards plus Home's library (owned or saved), one copy per id, shuffled.
    /// Viewed ids stay off the suggestion list. Owned library cards stay eligible after a view;
    /// a viewed saved card stays out unless dropping the library would empty the reel.
    static func mixedReel(
        library: [Recipe],
        suggestions: [Recipe],
        ownedIDs: Set<String>,
        viewedIDs: Set<String>
    ) -> [Recipe] {
        let eligible = library.filter { ownedIDs.contains($0.id) || !viewedIDs.contains($0.id) }
        var byID: [String: Recipe] = [:]
        for recipe in suggestions { byID[recipe.id] = recipe }
        for recipe in eligible { byID[recipe.id] = recipe }
        if byID.isEmpty {
            for recipe in library { byID[recipe.id] = recipe }
        }
        return Array(byID.values).shuffled()
    }
}

/// Bumped only by a double-tap on the Discover tab while that tab is already selected.
struct DiscoverTabSignal: Equatable {
    var token = 0
}

struct RecipeReelScreen: View {
    var tabSignal: DiscoverTabSignal = DiscoverTabSignal()
    /// Owned by the tab bar so leaving Discover and coming back shows the same card.
    @Binding var reel: [Recipe]
    @Binding var currentID: String?
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("reel_autoplay")        private var autoplay = false

    @State private var autoplayTick = 0

    // A STABLE snapshot of the feed. Built once, then only on an explicit Discover-tab double-tap.
    // Reappearing the tab must not reshuffle — a viewed card would drop out from under the user.
    // See `AppEnvironment.discoveryReel()`.

    /// First appear only. Stays on the current card when that id is still in the new shuffle.
    private func rebuildReel() {
        let next = environment.discoveryReel()
        reel = next
        if currentID == nil || !next.contains(where: { $0.id == currentID }) {
            currentID = next.first?.id
        }
    }

    /// Pull-to-refresh, or a second Discover-tab tap. `discoveryReel()` reads `recipes`.
    /// `excludingShown` drops the cards already in this stack so the new pile is unseen.
    private func refreshReel(excludingShown: Bool = false) {
        var next = environment.discoveryReel()
        if excludingShown {
            let fresh = DiscoveryReelRefresh.unseenPool(shown: reel.map(\.id), candidates: next.map(\.id))
            let byID = Dictionary(next.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            next = fresh.compactMap { byID[$0] }
        }
        let ids = next.map(\.id)
        let head = DiscoveryReelRefresh.nextHead(currentID: currentID, ids: ids)
        if let head, ids.first != head {
            next.append(next.removeFirst())
        }
        reel = next
        guard let head else {
            currentID = nil
            return
        }
        guard head != currentID else { return }
        currentID = nil
        // ponytail: a paging ScrollView drops a scrollPosition write in the same turn as replacing
        // ForEach data. Nil, then set the head next run loop. Upgrade path: assign `currentID = head`
        // directly if that write starts sticking.
        DispatchQueue.main.async { currentID = head }
    }

    /// Append a fresh shuffled batch that isn't already in the reel (endless scroll).
    private func appendMoreToReel() {
        let have = Set(reel.map(\.id))
        let more = environment.discoveryReel().filter { !have.contains($0.id) }
        guard !more.isEmpty else { return }
        reel.append(contentsOf: more)
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(reel) { r in
                        ReelCell(recipe: r,
                                 size: geo.size,
                                 topInset: geo.safeAreaInsets.top,
                                 bottomInset: geo.safeAreaInsets.bottom,
                                 fitMode: true)   // always fit (the recipe photo is never cropped)
                        .frame(width: geo.size.width,
                               height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
                        .id(r.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentID)
            .refreshable { await environment.fetchSuggestedFeed(); refreshReel() }
            .ignoresSafeArea()
            .background(.black)
            .overlay(alignment: .top) { topChrome(topInset: geo.safeAreaInsets.top) }
        }
        .task {
            // `.task` restarts every time this tab appears. Only build a reel when there isn't one.
            guard reel.isEmpty else { return }
            rebuildReel()
            await environment.fetchSuggestedFeed()
            if reel.isEmpty { rebuildReel() }
        }
        .onChange(of: currentID) { _, id in
            guard let id else { return }
            if let r = reel.first(where: { $0.id == id }) {
                environment.logInteraction(recipeId: r.id, eventType: "view")
            }
            // Instagram-style endless reel: nearing the end appends more recipes so scrolling never
            // dead-ends. New batches re-run the recommender + shuffle (unseen first).
            if let idx = reel.firstIndex(where: { $0.id == id }), idx >= reel.count - 2 {
                appendMoreToReel()
            }
        }
        .onChange(of: tabSignal.token) { _, _ in
            guard tabSignal.token > 0 else { return }
            refreshReel(excludingShown: true)
        }
        .task(id: "\(autoplay)-\(autoplayTick)") {
            guard autoplay, !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                if Task.isCancelled { break }
                if let id = currentID { advance(from: id) }
            }
        }
    }

    // MARK: - Top chrome (a single bubbly play/pause control for auto-advance)

    private func topChrome(topInset: CGFloat) -> some View {
        HStack {
            Spacer()
            Button {
                Haptics.select()
                withAnimation(AppMotion.snappy) { autoplay.toggle(); autoplayTick &+= 1 }
            } label: {
                Image(systemName: autoplay ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(autoplay ? "Pause auto-advance" : "Play — auto-advance reels")
        }
        .padding(.horizontal, 14)
        .padding(.top, topInset + 10)
    }

    // MARK: - Advancement

    private func advance(from id: String) {
        if let idx = reel.firstIndex(where: { $0.id == id }), idx + 1 < reel.count {
            withAnimation(AppMotion.smooth) { currentID = reel[idx + 1].id }
        }
    }
}

// MARK: - One recipe cell

private struct ReelCell: View {
    let recipe: Recipe
    let size: CGSize
    let topInset: CGFloat
    let bottomInset: CGFloat
    let fitMode: Bool

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showHeart = false       // Instagram-style burst on double-tap
    @State private var showComments = false    // bottom sheet with comments
    @State private var pendingOpen: DispatchWorkItem?

    private var liked: Bool  { environment.isLiked(recipeId: recipe.id) }
    private var saved: Bool  { environment.isSaved(recipeId: recipe.id) }
    private var commentsN: Int { environment.comments(for: recipe.id).count }
    private var following: Bool { environment.isFollowing(creatorHandle: recipe.ownerUsername ?? "") }

    private var shareURL: URL { URL(string: AppConfig.recipeWebLink(recipe.id))! }
    private var shareText: String { "\(recipe.title) on CraveCircle" }

    private var cellHeight: CGFloat { size.height + topInset + bottomInset }
    private var fitPhotoHeight: CGFloat { min(size.width, cellHeight - 260) }

    var body: some View {
        // No nested horizontal pager: it fought the outer vertical pager and hung scrolling.
        recipeContent
            .sheet(isPresented: $showComments) {
                NavigationStack {
                    ScrollView {
                        RecipeCommentsSection(recipeId: recipe.id)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, AppSpacing.md)
                    }
                    .background(AppTheme.background.ignoresSafeArea())
                    .navigationTitle("Comments")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showComments = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
    }

    // MARK: - Recipe content

    private var recipeContent: some View {
        ZStack(alignment: .bottomLeading) {
            backdrop
            captionBlock
            rail
            heartBurst
        }
        .frame(width: size.width, height: cellHeight)
    }

    // MARK: Backdrop (photo + taps)

    // Portrait fits the photo (never cropped); landscape would shrink that fit to a thin strip
    // (fitPhotoHeight collapses when height < width), so landscape fills the screen instead.
    private var useFit: Bool { fitMode && size.height >= size.width }

    private var backdrop: some View {
        ZStack {
            Color.black.frame(width: size.width, height: cellHeight)
            if useFit {
                RecipeCoverImage(recipe: recipe)
                    .scaledToFit()
                    .frame(width: size.width, height: fitPhotoHeight)
                    .clipped()
            } else {
                RecipeCoverImage(recipe: recipe)
                    .scaledToFill()
                    .frame(width: size.width, height: cellHeight)
                    .clipped()
                    .overlay(.black.opacity(0.28))
            }
        }
        .frame(width: size.width, height: cellHeight)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            pendingOpen?.cancel()
            pendingOpen = nil
            doubleTapLike()
        }
        .onTapGesture(count: 1) {
            pendingOpen?.cancel()
            let open = DispatchWorkItem { environment.selectRecipe(recipe) }
            pendingOpen = open
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: open)
        }
        .overlay(alignment: .bottom) {
            AppTheme.heroScrim
                .frame(height: 220)
                .allowsHitTesting(false)
        }
    }

    // MARK: Caption + meta

    private var captionBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                creatorAvatar
                Text(recipe.ownerUsername ?? "@cravecircle")
                    .font(AppFont.body(12, weight: .semibold))
                    .foregroundStyle(.white)
                followPill
            }
            Text(recipe.title)
                .font(AppFont.body(14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            HStack(spacing: 6) {
                if let c = recipe.cookTime, !c.isEmpty { metaPill(icon: "clock", text: c) }
                if let k = recipe.nutrition?.calories { metaPill(icon: "flame", text: "\(Int(k)) kcal") }
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 70)
        .padding(.bottom, bottomInset + 20)
    }

    private var creatorAvatar: some View {
        let handle = (recipe.ownerUsername ?? "cravecircle").replacingOccurrences(of: "@", with: "")
        let initials = String(handle.prefix(2)).uppercased()
        return Text(initials)
            .font(AppFont.serif(10, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(Color(hex: "EA5A38"), in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
    }

    /// Same Follow control as the recipe page hero (`RecipeDetailScreen` creator row).
    @ViewBuilder private var followPill: some View {
        if let h = recipe.ownerUsername {
            Button {
                Haptics.select()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                    environment.toggleFollow(creatorHandle: h)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: following ? "checkmark" : "person.badge.plus")
                        .font(.system(size: 11, weight: .bold))
                        .contentTransition(.symbolEffect(.replace))
                    Text(following ? "Following" : "Follow")
                        .font(AppFont.body(12, weight: .bold))
                }
                .foregroundStyle(AppTheme.onBrand)
                .padding(.horizontal, 11)
                .frame(height: 28)
                .background(
                    following
                        ? AnyShapeStyle(.ultraThinMaterial)
                        : AnyShapeStyle(AppTheme.brand),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(following ? 0.35 : 0.25), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func metaPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
            Text(text).font(AppFont.body(11, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(.black.opacity(0.42), in: Capsule())
    }

    // MARK: Rail (bottom-right)

    private var rail: some View {
        VStack(spacing: 16) {
            railButton(icon: liked ? "heart.fill" : "heart",
                       tint: liked ? .red : .white,
                       bounceValue: liked, count: nil, action: like)
            railButton(icon: "message", tint: .white, bounceValue: false,
                       count: commentsN > 0 ? "\(commentsN)" : nil) {
                showComments = true                  // in-reel comment sheet, no need to leave Discover
            }
            ShareLink(item: shareURL, subject: Text(recipe.title), message: Text(shareText)) {
                Image(systemName: "paperplane")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
            railButton(icon: saved ? "bookmark.fill" : "bookmark",
                       tint: .white,
                       bounceValue: saved, count: nil, action: save)
        }
        .padding(.trailing, 10)
        .padding(.bottom, bottomInset + 110)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    private func railButton(icon: String, tint: Color, bounceValue: Bool, count: String?,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: bounceValue)
                if let count { Text(count).font(AppFont.body(10, weight: .semibold)).foregroundStyle(.white) }
            }
        }
        .buttonStyle(PressableStyle())
        .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
    }

    // MARK: Heart burst (Instagram-style double-tap)

    @ViewBuilder private var heartBurst: some View {
        if showHeart {
            Image(systemName: "heart.fill")
                .font(.system(size: 110, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [Color(hex: "FF2D55"), Color(hex: "FF7A00")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.scale.combined(with: .opacity))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: Actions

    private func like() {
        Haptics.tap()
        withAnimation(AppMotion.snappy) { environment.toggleLikeRecipe(id: recipe.id) }
    }
    private func save() {
        Haptics.tap()
        withAnimation(AppMotion.snappy) { environment.toggleSaveRecipe(id: recipe.id) }
    }
    private func doubleTapLike() {
        if !liked {
            Haptics.select()
            withAnimation(AppMotion.snappy) { environment.toggleLikeRecipe(id: recipe.id) }
        }
        // Heart burst — always on double-tap, Instagram-style.
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { showHeart = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.3)) { showHeart = false }
        }
    }
}
