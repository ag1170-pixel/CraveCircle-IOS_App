//
//  RecipeReelScreen.swift
//  CraveCircle (AICookBook)
//
//  Discover = full-screen vertical reel of recipes (one per screen, swipe up/down to page), Instagram
//  styled: bottom-right rail (like / comment / share / save), bottom-left creator lockup. Hinge-style
//  horizontal swipes track taste — RIGHT = INTERESTED, LEFT = NOT INTERESTED — logged via
//  `environment.logInteraction(...)` so the recommendation engine learns. Pull-to-refresh at the top.
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

struct RecipeReelScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("reel_autoplay")        private var autoplay = false
    @AppStorage("reel_interested_ids")  private var interestedCSV = ""

    @State private var currentID: String?
    @State private var autoplayTick = 0

    // A STABLE, randomized snapshot of the personalized unseen feed. Built on appear / refresh only
    // (not recomputed while scrolling — logging a "view" marks a recipe seen, which must not yank it
    // out from under the user mid-scroll). See `AppEnvironment.discoveryReel()`.
    @State private var reel: [Recipe] = []

    private func rebuildReel() {
        let next = environment.discoveryReel()
        reel = next
        if currentID == nil || !next.contains(where: { $0.id == currentID }) {
            currentID = next.first?.id
        }
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
                                 fitMode: true,   // always fit (the recipe photo is never cropped)
                                 onInterested: { logTaste(r, interested: true); advance(from: r.id) },
                                 onNotInterested: { logTaste(r, interested: false); advance(from: r.id) })
                        .frame(width: geo.size.width,
                               height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
                        .id(r.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentID)
            .refreshable { await environment.fetchSuggestedFeed(); rebuildReel() }   // pull to reshuffle
            .ignoresSafeArea()
            .background(.black)
            .overlay(alignment: .top) { topChrome(topInset: geo.safeAreaInsets.top) }
        }
        .task {
            // Build the reel from local data FIRST so it appears instantly, even when the backend is
            // slow/offline. Then refresh the personalized feed in the background and rebuild if empty.
            if reel.isEmpty { rebuildReel() }
            if environment.suggestedRecipes.isEmpty {
                await environment.fetchSuggestedFeed()
                if reel.isEmpty { rebuildReel() }
            }
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

    // MARK: - Advancement + taste

    private func advance(from id: String) {
        if let idx = reel.firstIndex(where: { $0.id == id }), idx + 1 < reel.count {
            withAnimation(AppMotion.smooth) { currentID = reel[idx + 1].id }
        }
    }

    private func logTaste(_ r: Recipe, interested: Bool) {
        Haptics.toggle(interested)
        environment.logInteraction(recipeId: r.id, eventType: interested ? "interested" : "not_interested")
        if interested {
            var ids = interestedCSV.split(separator: ",").map(String.init)
            if !ids.contains(r.id) { ids.append(r.id); interestedCSV = ids.joined(separator: ",") }
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
    let onInterested: () -> Void
    let onNotInterested: () -> Void

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showHeart = false       // Instagram-style burst on double-tap
    @State private var showComments = false    // bottom sheet with comments
    // Horizontal page: 0 = NOT INTERESTED (shown when swiping finger RIGHT → content shifts LEFT),
    //                  1 = recipe (default),  2 = INTERESTED (shown when swiping LEFT).
    // Nested horizontal ScrollView with .paging + .scrollPosition — SwiftUI arbitrates with the outer
    // vertical pager natively, so we don't need a DragGesture that would block vertical scrolling.
    @State private var hPage: Int? = 1

    private var liked: Bool  { environment.isLiked(recipeId: recipe.id) }
    private var saved: Bool  { environment.isSaved(recipeId: recipe.id) }
    private var commentsN: Int { environment.comments(for: recipe.id).count }
    private var following: Bool { environment.isFollowing(creatorHandle: recipe.ownerUsername ?? "") }

    private var shareURL: URL { URL(string: "https://cravecircle.cc/recipe/\(recipe.id)")! }
    private var shareText: String { "\(recipe.title) on CraveCircle" }

    private var cellHeight: CGFloat { size.height + topInset + bottomInset }
    private var fitPhotoHeight: CGFloat { min(size.width, cellHeight - 260) }

    var body: some View {
        // Just the recipe content — no nested horizontal paging wrapper. The horizontal
        // interested/not-interested swipe is commented out below (owner's call 2026-10-03): the
        // nested `.scrollTargetBehavior(.paging)` was fighting the outer vertical pager and causing
        // vertical scrolling to hang between recipes. Vertical paging is smooth without it.
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
        /*  ---- COMMENTED OUT (owner, 2026-10-03): horizontal swipe for interested / not-interested.
            Re-enable by replacing the `recipeContent` call above with this block. Note it causes
            vertical paging to hang (nested paging ScrollViews fight each other).

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                tastePage(label: "NOT FOR ME", icon: "hand.thumbsdown.fill", color: .red).id(0)
                recipeContent.id(1)
                tastePage(label: "INTERESTED", icon: "hand.thumbsup.fill", color: .green).id(2)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $hPage, anchor: .center)
        .defaultScrollAnchor(.center)
        .scrollIndicators(.hidden)
        .frame(width: size.width, height: cellHeight)
        .onChange(of: hPage) { _, new in
            guard let new else { return }
            if new == 0 {
                onNotInterested()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(AppMotion.smooth) { hPage = 1 }
                }
            } else if new == 2 {
                onInterested()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(AppMotion.smooth) { hPage = 1 }
                }
            }
        }
        */
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

    // MARK: - Taste page (swipe-reveal green / red overlay)

    private func tastePage(label: String, icon: String, color: Color) -> some View {
        ZStack {
            color.opacity(0.92)
            VStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(.white)
                Text(label)
                    .font(AppFont.display(24, weight: .bold))
                    .foregroundStyle(.white)
            }
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
                RecipeCoverImage(urlString: recipe.thumbnailUrl)
                    .scaledToFit()
                    .frame(width: size.width, height: fitPhotoHeight)
                    .clipped()
            } else {
                RecipeCoverImage(urlString: recipe.thumbnailUrl)
                    .scaledToFill()
                    .frame(width: size.width, height: cellHeight)
                    .clipped()
                    .overlay(.black.opacity(0.28))
            }
        }
        .frame(width: size.width, height: cellHeight)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { doubleTapLike() }
        .onTapGesture { environment.selectRecipe(recipe) }
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
                if let p = recipe.prepTime { metaPill(icon: "clock", text: p) }
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

    /// Follow / Following toggle (bigger pill — owner feedback 2026-10-03).
    @ViewBuilder private var followPill: some View {
        if let h = recipe.ownerUsername {
            Button {
                Haptics.tap()
                withAnimation(AppMotion.snappy) { environment.toggleFollow(creatorHandle: h) }
            } label: {
                Text(following ? "Following" : "Follow")
                    .font(AppFont.body(13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 7)
                    .background(following ? Color.white.opacity(0.18) : Color(hex: "EA5A38"), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(following ? 0.6 : 0), lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .contentTransition(.opacity)
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
