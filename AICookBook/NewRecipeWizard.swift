//
//  NewRecipeWizard.swift
//  CraveCircle (AICookBook)
//
//  Four-step wizard for writing a recipe from scratch, matching the Figma reference
//  (OB4 • Welcome / New Recipe flow). Steps:
//    1. Photo    — upload the cover shot that inspires other cooks.
//    2. Basics   — title, description, serves, cook time.
//    3. Ingredients — grouped list with drag-reorder and swipe-delete.
//    4. Method   — directions, one step per line.
//
//  Writes into the same `Recipe` struct the Edit screen uses, so the existing save hook
//  (`environment.updateRecipe(_:)`) still applies.
//

import SwiftUI
#if !XTOOL_WSL
import PhotosUI
#endif

struct NewRecipeWizard: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    /// We mutate the draft locally and hand it back on Save. The caller supplies a blank
    /// recipe (see `AddRecipeSheet.newBlank()`).
    @State var draft: Recipe
    var onSave: (Recipe) -> Void

    @State private var step: Step = .photo
    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var ingredientRows: [String] = []
    @State private var directionRows: [String] = []

    private enum Step: Int, CaseIterable, Identifiable {
        case photo, basics, ingredients, method
        var id: Int { rawValue }
        var number: Int { rawValue + 1 }
        var title: String {
            switch self {
            case .photo:       return "Photo"
            case .basics:      return "Basics"
            case .ingredients: return "Ingredients"
            case .method:      return "Method"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepTracker
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.sm)

                ScrollView {
                    Group {
                        switch step {
                        case .photo:       photoStep
                        case .basics:      basicsStep
                        case .ingredients: ingredientsStep
                        case .method:      methodStep
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, 120)   // leaves room for the sticky bottom bar
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        Haptics.tap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    HStack(spacing: 8) {
                        // Figma: Save = dark pill, Publish = white pill.
                        Button("Save") { save(publishing: false) }
                            .font(AppFont.body(14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(AppTheme.textPrimary, in: Capsule())
                        if environment.canPublish {
                            Button("Publish") { save(publishing: true) }
                                .font(AppFont.body(14, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.white, in: Capsule())
                                .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
                                .disabled(!canPublish)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .onChange(of: pickedItem) { _, item in loadPicked(item) }
            .onAppear { seedRowsFromDraft() }
        }
        .tint(AppTheme.accentInk)
    }

    // MARK: - Step tracker (the four numbered circles at the top)

    private var stepTracker: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases) { s in
                stepBubble(for: s)
                if s != .method {
                    Rectangle()
                        .fill(s.rawValue < step.rawValue ? AppTheme.accent : AppTheme.hairline)
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func stepBubble(for s: Step) -> some View {
        let done = s.rawValue < step.rawValue
        let active = s == step
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(active || done ? AppTheme.accent : AppTheme.surface)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(active || done ? Color.clear : AppTheme.hairline, lineWidth: 1))
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.onAccent)
                } else {
                    Text("\(s.number)")
                        .font(AppFont.body(12, weight: .bold))
                        .foregroundStyle(active ? AppTheme.onAccent : AppTheme.textSecondary)
                }
            }
            Text(s.title)
                .font(AppFont.body(10, weight: .semibold))
                .foregroundStyle(active ? AppTheme.textPrimary : AppTheme.textSecondary)
        }
        .onTapGesture {
            Haptics.tap()
            withAnimation(AppMotion.snappy) { step = s }
        }
    }

    // MARK: - Step 1: Photo

    private var photoStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("New Recipe")
                .font(AppFont.display(32, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            #if !XTOOL_WSL
            PhotosPicker(selection: $pickedItem, matching: .images) {
                photoTile
            }
            .buttonStyle(.plain)
            #else
            photoTile
            #endif

            Text("A dish photo is the thing people see first. Yours or the creator's — both fine.")
                .font(AppFont.body(13))
                .foregroundStyle(AppTheme.textTertiary)
        }
    }

    private var photoTile: some View {
        VStack(spacing: 10) {
            if let img = pickedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            } else {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accentSoft)
                            .frame(width: 56, height: 56)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(AppTheme.accentInk)
                    }
                    Text("Upload recipe photo")
                        .font(AppFont.body(16, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Inspire others to cook your dish")
                        .font(AppFont.body(12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .strokeBorder(AppTheme.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                )
            }
        }
    }

    // MARK: - Step 2: Basics

    private var basicsStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Basics")
                .font(AppFont.display(28, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            labeled("Title") {
                TextField("My best-ever tomato pasta", text: $draft.title)
                    .font(AppFont.body(16))
                    .padding(.vertical, 10)
            }

            labeled("Description") {
                TextField("Share a little more about this dish. What or who inspired you?",
                          text: Binding(get: { draft.description ?? "" },
                                        set: { draft.description = $0.isEmpty ? nil : $0 }),
                          axis: .vertical)
                    .lineLimit(3...6)
                    .font(AppFont.body(15))
                    .padding(.vertical, 10)
            }

            HStack(spacing: AppSpacing.sm) {
                servingsPill
                cookTimePill
            }
            .padding(.top, 4)
        }
    }

    private var servingsPill: some View {
        HStack {
            Text("Serves")
                .font(AppFont.body(14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Menu {
                ForEach([1, 2, 4, 6, 8, 10, 12], id: \.self) { n in
                    Button("\(n) \(n == 1 ? "person" : "people")") { draft.servings = n }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("\(draft.servings ?? 4) people")
                        .font(AppFont.body(14, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.hairline, lineWidth: 1))
    }

    private var cookTimePill: some View {
        HStack {
            Text("Cook time")
                .font(AppFont.body(14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Menu {
                ForEach([10, 15, 20, 30, 45, 60, 90, 120], id: \.self) { m in
                    Button("\(m) min") { draft.cookTime = "\(m) min" }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(draft.cookTime ?? "35 min")
                        .font(AppFont.body(14, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.hairline, lineWidth: 1))
    }

    // MARK: - Step 3: Ingredients

    private var ingredientsStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Ingredients")
                .font(AppFont.display(28, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("One per line. Example: 400 g rigatoni")
                .font(AppFont.body(13))
                .foregroundStyle(AppTheme.textSecondary)

            ForEach(ingredientRows.indices, id: \.self) { i in
                ingredientRow(index: i)
            }

            Button {
                Haptics.tap()
                withAnimation(AppMotion.snappy) { ingredientRows.append("") }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add ingredient")
                }
                .font(AppFont.body(14, weight: .semibold))
                .foregroundStyle(AppTheme.accentInk)
            }
            .padding(.top, 6)
        }
    }

    private func ingredientRow(index i: Int) -> some View {
        HStack(spacing: 10) {
            Button {
                Haptics.warning()
                withAnimation(AppMotion.snappy) { ingredientRows.remove(at: i) }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(AppTheme.destructive)
            }
            TextField("Ingredient…", text: Binding(
                get: { i < ingredientRows.count ? ingredientRows[i] : "" },
                set: { if i < ingredientRows.count { ingredientRows[i] = $0 } }
            ))
            .font(AppFont.body(15))
            Spacer(minLength: 0)
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.hairline, lineWidth: 1))
    }

    // MARK: - Step 4: Method

    private var methodStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Method")
                .font(AppFont.display(28, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("One step at a time. Short and clear reads best hands-free.")
                .font(AppFont.body(13))
                .foregroundStyle(AppTheme.textSecondary)

            ForEach(directionRows.indices, id: \.self) { i in
                directionRow(index: i)
            }

            Button {
                Haptics.tap()
                withAnimation(AppMotion.snappy) { directionRows.append("") }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add step")
                }
                .font(AppFont.body(14, weight: .semibold))
                .foregroundStyle(AppTheme.accentInk)
            }
            .padding(.top, 6)
        }
    }

    private func directionRow(index i: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(i + 1)")
                .font(AppFont.serif(16, weight: .bold))
                .foregroundStyle(AppTheme.accentInk)
                .frame(width: 24, alignment: .center)
                .padding(.top, 2)
            TextField("Describe this step…",
                      text: Binding(
                        get: { i < directionRows.count ? directionRows[i] : "" },
                        set: { if i < directionRows.count { directionRows[i] = $0 } }
                      ),
                      axis: .vertical)
                .lineLimit(2...6)
                .font(AppFont.body(15))
            Button {
                Haptics.warning()
                withAnimation(AppMotion.snappy) { directionRows.remove(at: i) }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(AppTheme.destructive)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.hairline, lineWidth: 1))
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 10) {
            if step != .photo {
                Button {
                    Haptics.tap()
                    withAnimation(AppMotion.snappy) { step = Step(rawValue: step.rawValue - 1) ?? .photo }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(AppFont.body(15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.surface, in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
                }
            }
            Button {
                Haptics.tap()
                if step == .method {
                    save(publishing: false)
                } else {
                    withAnimation(AppMotion.snappy) { step = Step(rawValue: step.rawValue + 1) ?? .method }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(step == .method ? "Save recipe" : "Continue")
                    if step != .method {
                        Image(systemName: "chevron.right")
                    }
                }
                .font(AppFont.body(15, weight: .bold))
                .foregroundStyle(AppTheme.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.accent, in: Capsule())
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            LinearGradient(colors: [AppTheme.background.opacity(0), AppTheme.background],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        )
    }

    // MARK: - Helpers

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(AppFont.body(11, weight: .bold))
                .foregroundStyle(AppTheme.textTertiary)
                .kerning(0.8)
            content()
                .padding(.horizontal, 14)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.hairline, lineWidth: 1))
        }
    }

    private var canPublish: Bool {
        !draft.title.trimmingCharacters(in: .whitespaces).isEmpty
        && !ingredientRows.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        && !directionRows.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    #if !XTOOL_WSL
    private func loadPicked(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                await MainActor.run { pickedImage = img }
            }
        }
    }
    #else
    private func loadPicked(_ item: PhotosPickerItem?) {}
    #endif

    private func seedRowsFromDraft() {
        if ingredientRows.isEmpty {
            let flat = draft.ingredients.flatMap { $0.items }
            ingredientRows = flat.isEmpty ? [""] : flat
        }
        if directionRows.isEmpty {
            let steps = draft.directions.map { $0.text }
            directionRows = steps.isEmpty ? [""] : steps
        }
    }

    private func save(publishing: Bool) {
        // Flatten the two scratch arrays back into the Recipe shape the rest of the app uses.
        let ings = ingredientRows
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        draft.ingredients = ings.isEmpty ? [] : [IngredientGroup(groupName: nil, items: ings)]

        let dirs = directionRows
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { DirectionStep(stepIndex: $0.offset + 1, text: $0.element) }
        draft.directions = dirs

        // Persist the photo locally if one was picked.
        if let img = pickedImage,
           let data = img.jpegData(compressionQuality: 0.85) {
            let name = "cover_\(draft.id).jpg"
            if let url = LocalStore.saveData(data, to: name) {
                draft.thumbnailUrl = url.absoluteString
            }
        }

        if publishing { draft.visibility = .everyone }
        Haptics.success()
        onSave(draft)
        dismiss()
    }
}
