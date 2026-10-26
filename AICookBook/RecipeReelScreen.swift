//
//  RecipeReelScreen.swift
//  CraveCircle (AICookBook)
//
//  Discover = full-screen vertical reel of recipes (one per screen, swipe up/down to page), Instagram
//  styled: bottom-right rail (like / share / comment / save / more), bottom-left creator lockup.
//  Pull-to-refresh at the top.
//
//  No cat here — the chef-cat lives on Home + Grocery; Discover stays focused on the reel.
//
//  Reused APIs (per Ponytail):
//   • `environment.suggestedRecipes` + fallback curated, filtered personal-use-safe.
//   • Like: `toggleLikeRecipe` / `isLiked`.  Save: `toggleSaveRecipe` / `isSaved`.
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
                                 fitMode: true,   // always fit (the recipe photo is never cropped)
                                 onNotInterested: { skip($0) })
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
        .task(id: autoplay) {
            guard autoplay, !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                if Task.isCancelled { break }
                if let id = currentID { advance(from: id) }
            }
        }
    }

    // MARK: - Advancement

    /// Drop a card the user marked Not interested and stay on the next one.
    private func skip(_ id: String) {
        guard let idx = reel.firstIndex(where: { $0.id == id }) else { return }
        let next = idx + 1 < reel.count ? reel[idx + 1].id : (idx > 0 ? reel[idx - 1].id : nil)
        reel.remove(at: idx)
        currentID = reel.contains(where: { $0.id == next }) ? next : reel.first?.id
    }

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
    var onNotInterested: (String) -> Void = { _ in }

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("reel_autoplay") private var autoplay = false
    @AppStorage("reel_fills_screen") private var fillsScreen = false
    @State private var showHeart = false       // Instagram-style burst on double-tap
    @State private var showMenu = false
    @State private var menuPage = ReelMenuPage.actions
    @State private var showReport = false
    @State private var reportAfterMenu = false
    @State private var pendingOpen: DispatchWorkItem?
    @State private var showComments = false

    private var liked: Bool  { environment.isLiked(recipeId: recipe.id) }
    private var saved: Bool  { environment.isSaved(recipeId: recipe.id) }
    private var shareURL: URL { URL(string: AppConfig.recipeWebLink(recipe.id))! }
    private var shareText: String { "\(recipe.title) on CraveCircle" }

    private var cellHeight: CGFloat { size.height + topInset + bottomInset }
    private var fitPhotoHeight: CGFloat { min(size.width, cellHeight - 260) }

    var body: some View {
        // No nested horizontal pager: it fought the outer vertical pager and hung scrolling.
        recipeContent
            .sheet(isPresented: $showMenu, onDismiss: {
                menuPage = .actions
                if reportAfterMenu {
                    reportAfterMenu = false
                    showReport = true
                }
            }) {
                ReelMoreSheet(
                    page: $menuPage,
                    interested: environment.interactionHistory.contains { $0.recipeId == recipe.id && $0.eventType == "interested" },
                    fillsScreen: fillsScreen,
                    autoplay: autoplay,
                    onInterested: {
                        Haptics.select()
                        environment.logInteraction(recipeId: recipe.id, eventType: "interested")
                        showMenu = false
                    },
                    onNotInterested: {
                        Haptics.select()
                        environment.logInteraction(recipeId: recipe.id, eventType: "not_interested")
                        showMenu = false
                        onNotInterested(recipe.id)
                    },
                    onToggleFull: { fillsScreen.toggle() },
                    onToggleAutoplay: { autoplay.toggle() },
                    onReport: { reportAfterMenu = true; showMenu = false }
                )
            }
            .sheet(isPresented: $showReport) {
                ReportIssueSheet(recipe: recipe)
            }
            .sheet(isPresented: $showComments) {
                NavigationStack {
                    ScrollView {
                        RecipeCommentsSection(recipeId: recipe.id)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, AppSpacing.md)
                            .padding(.bottom, AppSpacing.xl)
                    }
                    .background(AppTheme.background.ignoresSafeArea())
                    .navigationTitle("Comments")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.fraction(0.75), .large])
                .presentationDragIndicator(.visible)
            }
    }

    /// nil hides the badge below the bubble icon; a short "12", "99+" otherwise.
    private var commentCountLabel: String? {
        let n = environment.comments(for: recipe.id).count
        guard n > 0 else { return nil }
        return n > 99 ? "99+" : "\(n)"
    }

    // MARK: - Recipe content

    private var recipeContent: some View {
        ZStack(alignment: .bottomLeading) {
            backdrop
            heartBurst
        }
        .frame(width: size.width, height: cellHeight)
        // Photo taps stay on this layer. The rail sits in an overlay so a tap on a
        // button cannot fall through to "open the recipe".
        .overlay(alignment: .bottom) {
            HStack(alignment: .bottom, spacing: 12) {
                captionBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                rail
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .padding(.bottom, bottomInset + 12)
        }
    }

    // MARK: Backdrop (photo + taps)

    // Portrait fits the photo (never cropped); landscape would shrink that fit to a thin strip
    // (fitPhotoHeight collapses when height < width), so landscape fills the screen instead.
    private var useFit: Bool { fitMode && !fillsScreen && size.height >= size.width }

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
                    .overlay(fillsScreen ? Color.clear : Color.black.opacity(0.28))
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
    }

    /// Same Follow control as the recipe-page hero. Hidden on the user's own recipe or when
    /// there's no creator handle to follow. Restored from commit 9de0d4a.
    @ViewBuilder private var followPill: some View {
        if let h = recipe.ownerUsername, !environment.isOwner(of: recipe) {
            let following = environment.isFollowing(creatorHandle: h)
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
                    following ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(AppTheme.brand),
                    in: Capsule()
                )
                .overlay(Capsule().stroke(.white.opacity(following ? 0.35 : 0.25), lineWidth: 0.8))
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(PressableStyle())
        }
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
        VStack(spacing: 18) {
            railButton(icon: liked ? "heart.fill" : "heart",
                       tint: liked ? .red : .white,
                       bounceValue: liked, count: nil, label: "Like", action: like)
            railButton(icon: "bubble.right",
                       tint: .white, bounceValue: false,
                       count: commentCountLabel, label: "Comments") {
                Haptics.tap()
                showComments = true
            }
            ShareLink(item: shareURL, subject: Text(recipe.title), message: Text(shareText)) {
                Image(systemName: "paperplane")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Share")
            railButton(icon: saved ? "bookmark.fill" : "bookmark",
                       tint: .white,
                       bounceValue: saved, count: nil, label: "Save", action: save)
            railButton(icon: "line.3.horizontal", tint: .white, bounceValue: false,
                       count: nil, label: "More") {
                menuPage = .actions
                showMenu = true
            }
        }
    }

    private func railButton(icon: String, tint: Color, bounceValue: Bool, count: String?,
                            label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: bounceValue)
                if let count { Text(count).font(AppFont.body(10, weight: .semibold)).foregroundStyle(.white) }
            }
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
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
        withAnimation(AppMotion.snappy) { environment.toggleSaveRecipe(id: recipe.id, recipe: recipe) }
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

private enum ReelMenuPage {
    case actions
    case playback
}

/// More menu on a reel: Interested, Not interested, Playback, Report.
/// Playback is only full-screen and auto-scroll.
private struct ReelMoreSheet: View {
    @Binding var page: ReelMenuPage
    let interested: Bool
    let fillsScreen: Bool
    let autoplay: Bool
    let onInterested: () -> Void
    let onNotInterested: () -> Void
    let onToggleFull: () -> Void
    let onToggleAutoplay: () -> Void
    let onReport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if page == .playback {
                playback
            } else {
                actions
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.lg)
        .padding(.bottom, AppSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(page == .playback ? 240 : 300)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }

    private var actions: some View {
        VStack(spacing: 0) {
            menuRow(icon: "checkmark", title: "Interested", tint: .primary, action: onInterested)
            glassDivider
            menuRow(icon: "xmark", title: "Not interested", tint: .primary, action: onNotInterested)
            glassDivider
            menuRow(icon: "play.circle", title: "Playback", tint: .primary) { page = .playback }
            glassDivider
            menuRow(icon: "exclamationmark.bubble", title: "Report", tint: AppTheme.destructive, action: onReport)
        }
    }

    private var playback: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Playback")
                .font(AppFont.body(17, weight: .bold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
            VStack(spacing: 0) {
                Button(action: onToggleFull) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 28)
                        Text("View full-screen")
                            .font(AppFont.body(16, weight: .medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        if fillsScreen {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                glassDivider
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 28)
                    Text("Auto-scroll")
                        .font(AppFont.body(16, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Toggle("Auto-scroll", isOn: Binding(get: { autoplay }, set: { _ in onToggleAutoplay() }))
                        .labelsHidden()
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 10)
            }
        }
    }

    private var glassDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(height: 0.5)
            .padding(.leading, 52)
    }

    private func menuRow(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28)
                Text(title)
                    .font(AppFont.body(16, weight: .medium))
                    .foregroundStyle(tint)
                Spacer()
                if title == "Interested" && interested {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}
