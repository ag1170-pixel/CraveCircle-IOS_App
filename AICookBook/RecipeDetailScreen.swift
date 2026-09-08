//
//  RecipeDetailScreen.swift
//  CraveCircle (AICookBook)
//
//  The hero screen. Fusion direction: full-bleed food photography leads, editorial
//  oversized title, HIG-native controls underneath. Stretchy parallax header, glass
//  overlay buttons, a custom lime segmented control, checkable rows with haptics.
//  Full light + dark parity; honors Reduce Motion.
//

import SwiftUI

struct RecipeDetailScreen: View {
    @State private var recipe: Recipe

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var tab: Int                            // 0 = Ingredients, 1 = Directions (owned by the pager)
    private let onSwitchRecipe: ((Int) -> Void)?     // +1 next / -1 prev — swipe OUTSIDE the segment region
    @State private var segmentFrame: CGRect = .zero  // Ingredients/Directions region, in the "detail" space
    @State private var checkedIngredients: Set<String> = []
    @State private var checkedSteps: Set<Int> = []
    @State private var descriptionExpanded = false
    @State private var descFullHeight: CGFloat = 0        // natural height of the full description
    @State private var descClampedHeight: CGFloat = 0     // height when clamped to 3 lines
    @State private var servings: Int
    @State private var showCook = false
    @State private var showEdit = false
    @State private var showShareSheet = false
    @State private var showCreatorSheet = false
    @State private var showWatchReel = false
    @State private var showDeleteConfirm = false
    @AppStorage(LanguagePrefs.key) private var preferredLang = LanguagePrefs.default.rawValue
    @State private var showGroceryBanner = false
    @State private var addedGroceryCount = 0
    @State private var showHeartBurst = false
    @State private var heartBurstScale: CGFloat = 0.2
    @State private var heartBurstOpacity: Double = 0.0
    @State private var heartBurstY: CGFloat = 0
    @State private var showOriginalRecipeInfo = false
    @State private var showReportSheet = false
    @State private var viewStartTime: Date? = nil

    private let heroHeight: CGFloat = 380

    init(recipe: Recipe, tab: Binding<Int> = .constant(0), onSwitchRecipe: ((Int) -> Void)? = nil) {
        _recipe = State(initialValue: recipe)
        _tab = tab
        self.onSwitchRecipe = onSwitchRecipe
        _servings = State(initialValue: recipe.servings ?? 2)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if environment.canView(recipe) {
                        content
                    } else {
                        followGate
                    }
                }
            }
            .coordinateSpace(name: "scroll")
            .scrollIndicators(.hidden)

            topControls
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, safeTopInset())
        }
        .background(AppTheme.background.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .coordinateSpace(.named("detail"))
        .simultaneousGesture(
            DragGesture(minimumDistance: 25, coordinateSpace: .named("detail"))
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.3,
                          abs(value.translation.width) > 50 else { return }
                    let goLeft = value.translation.width < 0
                    if segmentFrame.contains(value.startLocation) {
                        // swipe INSIDE the Ingredients/Directions region → switch those two
                        withAnimation(.easeInOut(duration: 0.22)) { tab = goLeft ? 1 : 0 }
                        Haptics.select()
                    } else {
                        // swipe anywhere ELSE on the page → previous / next recipe
                        onSwitchRecipe?(goLeft ? 1 : -1)
                    }
                }
        )
        .leadingEdgeBack { environment.dismissRecipeDetail() }
        .overlay(alignment: .bottom) {
            if showGroceryBanner {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    Text("Added \(addedGroceryCount) items to Grocery List!")
                        .font(AppFont.body(14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 12)
                .background(AppTheme.surface, in: Capsule())
                .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if showOriginalRecipeInfo {
                HStack(spacing: 9) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color(hex: "FFB340"))
                        .font(.system(size: 15, weight: .bold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Chef's Original Recipe")
                            .font(AppFont.body(13, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Handcrafted & published directly on CraveCircle.")
                            .font(AppFont.body(12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 14, y: 5)
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .scrollIndicators(.hidden)
        .fullScreenCover(isPresented: $showCook) {
            CookModeScreen(recipe: recipe, servings: servings)
        }
        .fullScreenCover(isPresented: $showEdit) {
            RecipeEditScreen(recipe: $recipe, onSave: { environment.updateRecipe($0) })
                .environmentObject(environment)
        }
        .sheet(isPresented: $showWatchReel) {
            SafariView(url: recipe.reelUrl)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showShareSheet) {
            RecipeShareSheet(recipe: recipe)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCreatorSheet) {
            if let handle = recipe.ownerUsername {
                CreatorProfileSheet(handle: handle, name: nil)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportIssueSheet(recipe: recipe)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .alert("Delete this recipe?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Haptics.success()
                environment.deleteOwnedRecipe(id: recipe.id)
                environment.dismissRecipeDetail()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes it from your library. Other people’s recipes can’t be deleted.")
        }
        .onAppear {
            viewStartTime = Date()
        }
        .onDisappear {
            if let start = viewStartTime {
                let duration = Int(Date().timeIntervalSince(start))
                environment.logInteraction(recipeId: recipe.id, eventType: "view", durationSeconds: duration)
            }
        }
    }

    // MARK: Stretchy parallax hero

    private var header: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named("scroll")).minY
            let stretch = max(0, minY)
            let height = heroHeight + (reduceMotion ? 0 : stretch)

            ZStack(alignment: .bottom) {
                heroImage
                    .frame(width: geo.size.width, height: height)
                    .clipped()
                    .blur(radius: environment.canView(recipe) ? 0 : 20)
                    .offset(y: reduceMotion ? 0 : -stretch)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        if !environment.isLiked(recipeId: recipe.id) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                environment.toggleLikeRecipe(id: recipe.id)
                            }
                        }
                        triggerHeartBurst()
                    }

                // Instagram Double-Tap Heart Burst Animation
                if showHeartBurst {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 92, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "FF2D55"), Color(hex: "FF375F"), Color(hex: "FF7A00")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.4), radius: 14, x: 0, y: 6)
                        .scaleEffect(heartBurstScale)
                        .opacity(heartBurstOpacity)
                        .offset(y: heartBurstY)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                AppTheme.heroScrim
                    .frame(height: height * 0.65)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .offset(y: reduceMotion ? 0 : -stretch)
                    .allowsHitTesting(false)

                heroFooter
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, 42)
                    .offset(y: reduceMotion ? 0 : -stretch)
            }
        }
        .frame(height: heroHeight)
    }

    @ViewBuilder private var heroImage: some View {
        if let thumb = recipe.thumbnailUrl, UIImage(named: thumb) != nil {
            Image(thumb).resizable().scaledToFill()
        } else if let urlString = recipe.thumbnailUrl, let url = URL(string: urlString), (url.scheme == "http" || url.scheme == "https" || url.scheme == "file") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    RecipeImagePlaceholder(isBuffering: false, size: 48)
                case .empty:
                    RecipeImagePlaceholder(isBuffering: true, size: 48)
                @unknown default:
                    RecipeImagePlaceholder(isBuffering: false, size: 48)
                }
            }
        } else {
            RecipeImagePlaceholder(isBuffering: false, size: 48)
        }
    }

    private var heroFooter: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                Haptics.tap()
                showCreatorSheet = true
            } label: {
                HStack(spacing: 8) {
                    CreatorAvatarView(handle: recipe.ownerUsername, size: 36)
                    Text(recipe.ownerUsername ?? "@cravecircle")
                        .font(AppFont.body(15, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            if let handle = recipe.ownerUsername, !environment.isOwner(of: recipe) {
                let following = environment.isFollowing(creatorHandle: handle)
                Button {
                    Haptics.select()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                        environment.toggleFollow(creatorHandle: handle)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: following ? "checkmark" : "person.badge.plus")
                            .font(.system(size: 12, weight: .bold))
                            .contentTransition(.symbolEffect(.replace))
                        Text(following ? "Following" : "Follow")
                            .font(AppFont.body(13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(
                        following 
                            ? AnyShapeStyle(.ultraThinMaterial) 
                            : AnyShapeStyle(Color(hex: "1877F2")),
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

            Spacer(minLength: 4)

            if recipe.isImportedFromSocial {
                Button {
                    Haptics.tap()
                    showWatchReel = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill").font(.system(size: 12, weight: .bold))
                        Text("Watch").font(AppFont.body(14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.8))
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(PressableStyle())
                .contextMenu {
                    Button {
                        showWatchReel = true
                    } label: {
                        Label("Watch in App", systemImage: "play.circle")
                    }
                    Button {
                        UIApplication.shared.open(recipe.reelUrl)
                    } label: {
                        Label("Open in Instagram App", systemImage: "arrow.up.right.square")
                    }
                    Button {
                        UIPasteboard.general.string = recipe.reelUrl.absoluteString
                        Haptics.tap()
                    } label: {
                        Label("Copy Reel Link", systemImage: "doc.on.doc")
                    }
                }
            } else {
                Button {
                    Haptics.select()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        showOriginalRecipeInfo = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showOriginalRecipeInfo = false
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(hex: "FFB340"))
                        Text("Original")
                            .font(AppFont.body(13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "FFB340").opacity(0.6), .white.opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.0
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func triggerHeartBurst() {
        Haptics.success()
        guard !reduceMotion else { return }
        showHeartBurst = true
        heartBurstScale = 0.2
        heartBurstOpacity = 0.95
        heartBurstY = 0
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            heartBurstScale = 1.25
        }
        withAnimation(.easeInOut(duration: 0.45).delay(0.35)) {
            heartBurstScale = 1.4
            heartBurstOpacity = 0.0
            heartBurstY = -30
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            showHeartBurst = false
        }
    }

    // MARK: Floating top controls

    private var topControls: some View {
        HStack {
            GlassIconButton(systemImage: "chevron.left", label: "Back") { environment.dismissRecipeDetail() }
            Spacer()
            HStack(spacing: 10) {
                // Instagram-style Like Button
                let isLiked = environment.isLiked(recipeId: recipe.id)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        environment.toggleLikeRecipe(id: recipe.id)
                    }
                    if !isLiked {
                        triggerHeartBurst()
                    }
                } label: {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(isLiked ? Color(hex: "FF2D55") : .white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.8))
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(isLiked ? "Unlike recipe" : "Like recipe")

                GlassIconButton(systemImage: "square.and.arrow.up", label: "Share recipe") {
                    Haptics.tap()
                    showShareSheet = true
                }
                Menu {
                    if environment.canDelete(recipe) {
                        Button(role: .destructive) {
                            Haptics.tap()
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete from Library", systemImage: "trash")
                        }
                    }

                    if environment.isOwner(of: recipe) {
                        Button {
                            Haptics.tap()
                            showEdit = true
                        } label: {
                            Label("Edit Recipe", systemImage: "pencil")
                        }
                    }

                    let saved = environment.isSaved(recipeId: recipe.id)
                    Button {
                        Haptics.select()
                        environment.toggleSaveRecipe(id: recipe.id)
                    } label: {
                        Label(saved ? "Remove from Saved" : "Save Recipe", systemImage: saved ? "bookmark.fill" : "bookmark")
                    }

                    Button {
                        Haptics.success()
                        let count = environment.addIngredientsToGrocery(recipe: recipe)
                        addedGroceryCount = count
                        withAnimation { showGroceryBanner = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { showGroceryBanner = false }
                        }
                    } label: {
                        Label("Add to Grocery List", systemImage: "basket")
                    }

                    Button {
                        Haptics.tap()
                        showShareSheet = true
                    } label: {
                        Label("Share with Circle", systemImage: "paperplane")
                    }
                    
                    Button {
                        Haptics.tap()
                        showReportSheet = true
                    } label: {
                        Label("Report Issue", systemImage: "exclamationmark.triangle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.8))
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .accessibilityLabel("More options")
            }
        }
    }

    // MARK: Scrolling content

    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text(recipe.title)
                .font(AppFont.display(30, weight: .heavy))
                .foregroundStyle(AppTheme.textPrimary)
                .lineSpacing(-2)
                .fixedSize(horizontal: false, vertical: true)

            metaLine

            originChip

            if let description = recipe.description, !description.isEmpty {
                descriptionBlock(description)
            }

            NutritionCard(nutrition: recipe.nutritionOrEstimate, servings: servings)

            actionRow

            PillButton(title: "Start Cooking", systemImage: "flame.fill", kind: .filled, fullWidth: true) {
                environment.logInteraction(recipeId: recipe.id, eventType: "cook")
                showCook = true
            }

            LimeSegmentedControl(segments: ["Ingredients", "Directions"], selection: $tab)
                .padding(.top, 2)

            Group {
                if tab == 0 { ingredientsList } else { directionsList }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: tab)
            .contentShape(Rectangle())
            // Report this region so a swipe here toggles Ingredients/Directions; elsewhere = switch recipe.
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("detail")) } action: { segmentFrame = $0 }

            Rectangle().fill(AppTheme.separator).frame(height: 1).padding(.top, AppSpacing.sm)

            RecipeCommentsSection(recipeId: recipe.id)

            Spacer(minLength: 60)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.lg)
        .background(
            AppTheme.background
                .clipShape(.rect(topLeadingRadius: AppRadius.sheet, topTrailingRadius: AppRadius.sheet))
                .ignoresSafeArea(edges: .bottom)
                .offset(y: -AppSpacing.lg)
        )
    }

    private var followGate: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.accentSoft)
            
            Text("Followers Only")
                .font(AppFont.display(24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            
            Text("Follow \(recipe.ownerUsername ?? "@creator") to unlock this recipe and see all their latest dishes.")
                .font(AppFont.body(16))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)
            
            Button {
                Haptics.success()
                if let handle = recipe.ownerUsername {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                        environment.toggleFollow(creatorHandle: handle)
                    }
                }
            } label: {
                Text("Follow to Unlock")
                    .font(AppFont.body(16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color(hex: "1877F2"), in: Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.vertical, 80)
        .frame(maxWidth: .infinity)
        .background(AppTheme.background)
        .clipShape(.rect(topLeadingRadius: AppRadius.sheet, topTrailingRadius: AppRadius.sheet))
        .offset(y: -AppSpacing.lg)
    }

    @ViewBuilder private var originChip: some View {
        let userLang = AppLanguage(rawValue: preferredLang) ?? LanguagePrefs.default
        let isManual = !recipe.isImportedFromSocial

        if isManual {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "EA5A38"))
                Text("Handcrafted Recipe")
                    .font(AppFont.body(13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(AppTheme.surface, in: Capsule())
            .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
        } else if let src = AppLanguage.from(code: recipe.sourceLanguage), src != userLang {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 12, weight: .semibold))
                Text("Translated from \(src.name)")
                    .font(AppFont.body(13, weight: .semibold))
            }
            .foregroundStyle(AppTheme.accentInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(AppTheme.accentSoft, in: Capsule())
        } else {
            HStack(spacing: 6) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.accentInk)
                Text("Original Audio Reel")
                    .font(AppFont.body(13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(AppTheme.surface, in: Capsule())
            .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
        }
    }

    private var metaLine: some View {
        HStack(spacing: 10) {
            if let prep = recipe.prepTime { metaItem("Prep", prep) }
            if recipe.prepTime != nil && recipe.cookTime != nil { divider }
            if let cook = recipe.cookTime { metaItem("Cook", cook) }
        }
    }

    private func metaItem(_ label: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(label.uppercased())
                .font(AppFont.label(11, weight: .bold)).tracking(0.8)
                .foregroundStyle(AppTheme.textTertiary)
            Text(value)
                .font(AppFont.body(14, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var divider: some View {
        Rectangle().fill(AppTheme.hairline).frame(width: 1, height: 12)
    }

    private func descriptionBlock(_ description: String) -> some View {
        // Only show the toggle when the text actually overflows 3 lines — compare the clamped
        // height against a hidden full-height copy, so short descriptions never show "Show more".
        let isTruncated = descFullHeight > descClampedHeight + 1
        return VStack(alignment: .leading, spacing: 6) {
            Text(description)
                .font(AppFont.body(16))
                .foregroundStyle(AppTheme.textSecondary)
                .lineSpacing(3)
                .lineLimit(descriptionExpanded ? nil : 3)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { descClampedHeight = $0 }
                .background(
                    Text(description)
                        .font(AppFont.body(16))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { descFullHeight = $0 }
                        .hidden()
                )
            if isTruncated || descriptionExpanded {
                Button(descriptionExpanded ? "Show less" : "Show more") {
                    withAnimation(AppMotion.smooth) { descriptionExpanded.toggle() }
                }
                .font(AppFont.body(14, weight: .semibold))
                .foregroundStyle(AppTheme.accentInk)
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            // Direct interactive Servings Stepper
            HStack(spacing: 8) {
                Button {
                    if servings > 1 {
                        Haptics.tap()
                        withAnimation(AppMotion.snappy) { servings -= 1 }
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(servings > 1 ? AppTheme.accentInk : AppTheme.textTertiary)
                        .frame(width: 26, height: 26)
                        .background(AppTheme.accentSoft, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(servings <= 1)
                .accessibilityLabel("Decrease servings")

                VStack(spacing: 0) {
                    Text("\(servings) Servings")
                        .font(AppFont.body(13, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    let base = recipe.servings ?? 2
                    if servings != base {
                        Text("Base: \(base)")
                            .font(AppFont.body(10))
                            .foregroundStyle(AppTheme.accentInk)
                    }
                }
                .padding(.horizontal, 2)

                Button {
                    if servings < 24 {
                        Haptics.tap()
                        withAnimation(AppMotion.snappy) { servings += 1 }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.accentInk)
                        .frame(width: 26, height: 26)
                        .background(AppTheme.accentSoft, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Increase servings")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(AppTheme.surface, in: Capsule())
            .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))

            PillButton(title: "Add to Grocery", systemImage: "basket.fill", kind: .outlined) {
                Haptics.success()
                let count = environment.addIngredientsToGrocery(recipe: recipe, servings: servings)
                addedGroceryCount = count
                withAnimation { showGroceryBanner = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { showGroceryBanner = false }
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Ingredients

    private var ingredientsList: some View {
        let baseServings = recipe.servings ?? 2
        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            if servings != baseServings {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Quantities scaled for \(servings) servings (original: \(baseServings))")
                        .font(AppFont.body(12, weight: .medium))
                    Spacer()
                    Button("Reset") {
                        Haptics.tap()
                        withAnimation(AppMotion.snappy) { servings = baseServings }
                    }
                    .font(AppFont.body(12, weight: .bold))
                    .foregroundStyle(AppTheme.accentInk)
                }
                .foregroundStyle(AppTheme.accentInk)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { groupIndex, group in
                VStack(alignment: .leading, spacing: 0) {
                    if let name = group.groupName, !name.isEmpty {
                        Text(name).sectionLabelStyle().padding(.bottom, 6)
                    }
                    ForEach(Array(group.items.enumerated()), id: \.offset) { itemIndex, item in
                        let key = "\(groupIndex):\(itemIndex)"
                        let scaledText = IngredientScaler.scale(text: item, from: baseServings, to: servings)
                        VStack(spacing: 0) {
                            IngredientRow(text: scaledText, checked: checkedIngredients.contains(key)) {
                                toggle(&checkedIngredients, key)
                            }
                            if itemIndex < group.items.count - 1 {
                                Rectangle().fill(AppTheme.separator).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Directions

    private var directionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            let steps = recipe.directions.sorted { $0.stepIndex < $1.stepIndex }
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                DirectionRow(index: i + 1, text: step.text, checked: checkedSteps.contains(step.stepIndex)) {
                    toggle(&checkedSteps, step.stepIndex)
                }
            }
        }
    }

    // MARK: Helpers

    private func toggle<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private func safeTopInset() -> CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            let top = window.safeAreaInsets.top
            return top > 0 ? top + 4 : 54
        }
        return 56
    }
}

// MARK: - Swipeable recipe pager (region-scoped)
//
// Region-based swiping: a swipe INSIDE the Ingredients/Directions section toggles those two; a
// swipe ANYWHERE ELSE on the page moves to the previous/next recipe. RecipeDetailScreen owns the
// gesture (it knows the section's frame) and calls back here to change the recipe.
struct RecipeDetailPager: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var segment = 0            // 0 = Ingredients, 1 = Directions
    @State private var resolved = false
    private let startId: String

    init(start: Recipe) { self.startId = start.id }

    private var swipeAnim: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.85)
    }

    var body: some View {
        // Swipe within the caller's context (e.g. Library's Liked/Saved/Created tab) when one was
        // given, so left/right stays inside what's actually on screen; otherwise the full library.
        let recipes = environment.recipeSwipeContext ?? environment.recipes
        let safe = min(max(index, 0), max(recipes.count - 1, 0))
        Group {
            if recipes.indices.contains(safe) {
                RecipeDetailScreen(recipe: recipes[safe], tab: $segment, onSwitchRecipe: { dir in
                    // Swipe OUTSIDE the Ingredients/Directions region → previous / next recipe.
                    withAnimation(swipeAnim) {
                        if dir > 0, index < recipes.count - 1 { index += 1; segment = 0 }
                        else if dir < 0, index > 0 { index -= 1; segment = 0 }
                        else { return }
                    }
                    Haptics.select()
                })
                .id(recipes[safe].id)     // fresh per-recipe state; segment persists via binding
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear {
            if !resolved { index = recipes.firstIndex { $0.id == startId } ?? 0; resolved = true }
        }
        .onChange(of: index) { _, _ in
            if environment.isGuest {
                let defaults = UserDefaults.standard
                let count = defaults.integer(forKey: "guest_recipe_view_count")
                if count >= 10 {
                    environment.dismissRecipeDetail()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        environment.showGuestLoginWall = true
                    }
                    return
                }
                defaults.set(count + 1, forKey: "guest_recipe_view_count")
            }
        }
    }
}

#Preview {
    RecipeDetailScreen(recipe: Recipe.placeholderRecipes[0])
        .environmentObject(AppEnvironment())
}
