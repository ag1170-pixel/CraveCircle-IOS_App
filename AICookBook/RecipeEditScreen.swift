//
//  RecipeEditScreen.swift
//  CraveCircle (AICookBook)
//
//  Edit a recipe you own — title, times, servings, ingredient groups, and steps.
//  Owner-only (surfaced from the Recipe Detail glass Edit button). Saves back to the
//  open recipe + the library; wires to PATCH /recipes/{id} when the backend is live.
//

import SwiftUI
#if !XTOOL_WSL
import PhotosUI
#endif

struct RecipeEditScreen: View {
    @Binding var recipe: Recipe
    var onSave: (Recipe) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment
    @State private var draft: Recipe
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var photos: [UIImage] = []           // the working gallery (max 6; first = cover)
    @State private var loadedExisting = false

    private let maxPhotos = 6

    init(recipe: Binding<Recipe>, onSave: @escaping (Recipe) -> Void) {
        _recipe = recipe
        self.onSave = onSave
        _draft = State(initialValue: recipe.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    photoStrip
                    if photos.count < maxPhotos {
                        PhotosPicker(selection: $pickedItems,
                                     maxSelectionCount: maxPhotos - photos.count,
                                     matching: .images) {
                            Label(photos.isEmpty ? "Add photos" : "Add more",
                                  systemImage: "photo.on.rectangle.angled")
                        }
                    }
                } header: {
                    Text("Photos")
                } footer: {
                    Text("Add up to \(maxPhotos). The first is the cover.")
                }
                Section("Details") {
                    TextField("Recipe Name", text: $draft.title)
                    Stepper("Servings: \(draft.servings ?? 1)", value: servingsBinding, in: 1...30)
                }
                Section("Prep time") {
                    DurationWheel(minutes: minutesBinding(for: $draft.prepTime))
                }
                Section("Cook time") {
                    DurationWheel(minutes: minutesBinding(for: $draft.cookTime))
                }
                
                // Community Visibility section intentionally removed for now (per 2026-10-07 UI batch).
                // The draft.visibility field is kept (defaults to .everyone) so publishing still works.

                ForEach(draft.ingredients.indices, id: \.self) { i in
                    Section(i == 0 ? "Ingredients" : "") {
                        TextField("Group name (optional)", text: $draft.ingredients[i].groupName.orEmpty())
                            .font(.subheadline.weight(.semibold))
                        ForEach(draft.ingredients[i].items.indices, id: \.self) { j in
                            HStack(spacing: 8) {
                                TextField("Ingredient", text: $draft.ingredients[i].items[j])
                                Button(role: .destructive) {
                                    draft.ingredients[i].items.remove(at: j)
                                } label: {
                                    Image(systemName: "minus.circle.fill").foregroundStyle(AppTheme.destructive)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove ingredient")
                            }
                        }
                        Button { draft.ingredients[i].items.append("") } label: {
                            Label("Add ingredient", systemImage: "plus.circle")
                        }
                        if draft.ingredients.count > 1 {
                            Button(role: .destructive) { draft.ingredients.remove(at: i) } label: {
                                Label("Remove group", systemImage: "trash")
                            }
                        }
                    }
                }
                Button {
                    draft.ingredients.append(IngredientGroup(groupName: "", items: [""]))
                } label: { Label("Add ingredient group", systemImage: "plus.square") }

                Section("Steps") {
                    ForEach(draft.directions.indices, id: \.self) { k in
                        HStack(alignment: .top, spacing: 8) {
                            Text(String(format: "%02d", k + 1))
                                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                                .foregroundStyle(AppTheme.textTertiary)
                                .padding(.top, 8)
                            TextField("Step", text: $draft.directions[k].text, axis: .vertical)
                            Button(role: .destructive) {
                                draft.directions.remove(at: k)
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(AppTheme.destructive)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove step")
                            .padding(.top, 6)
                        }
                    }
                    Button {
                        draft.directions.append(DirectionStep(stepIndex: draft.directions.count + 1, text: ""))
                    } label: { Label("Add step", systemImage: "plus.circle") }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Edit recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold)
                }
            }
            .tint(AppTheme.accentInk)
            .onChange(of: pickedItems) { _, items in loadPicked(items) }
            .task { loadExistingPhotos() }
        }
    }

    @ViewBuilder private var photoStrip: some View {
        if photos.isEmpty {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .frame(height: 120)
                .overlay(
                    VStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled").font(.system(size: 24))
                        Text("No photos yet").font(AppFont.body(13))
                    }.foregroundStyle(AppTheme.textTertiary)
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(photos.indices, id: \.self) { i in
                        Image(uiImage: photos[i])
                            .resizable().scaledToFill()
                            .frame(width: 110, height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    Haptics.tap(); photos.remove(at: i)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white, .black.opacity(0.5))
                                        .padding(5)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove photo")
                            }
                            .overlay(alignment: .bottomLeading) {
                                if i == 0 {
                                    Text("Cover").font(AppFont.label(10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(AppTheme.brand, in: Capsule())
                                        .padding(6)
                                }
                            }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        }
    }

    /// Load newly-picked items into the working gallery (capped at `maxPhotos`).
    private func loadPicked(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            var added: [UIImage] = []
            for item in items {
                if photos.count + added.count >= maxPhotos { break }
                if let data = try? await item.loadTransferable(type: Data.self), let ui = UIImage(data: data) {
                    added.append(ui)
                }
            }
            await MainActor.run {
                photos.append(contentsOf: added)
                pickedItems = []
            }
        }
    }

    /// Load the recipe's existing images into the editor once (so editing keeps/reorders them).
    private func loadExistingPhotos() {
        guard !loadedExisting else { return }
        loadedExisting = true
        let refs = draft.galleryImages
        guard !refs.isEmpty else { return }
        Task {
            var loaded: [UIImage] = []
            for s in refs where loaded.count < maxPhotos {
                if let img = await Self.loadImage(s) { loaded.append(img) }
            }
            await MainActor.run { if photos.isEmpty { photos = loaded } }
        }
    }

    private static func loadImage(_ s: String) async -> UIImage? {
        if let img = UIImage(named: s) { return img }
        if let bundled = RecipeCoverImage.bundledAsset(from: s) { return bundled }
        if let url = RecipeCoverImage.remoteURL(from: s) {
            if let (data, _) = try? await URLSession.shared.data(from: url) { return UIImage(data: data) }
            return nil
        }
        let filename = s.hasPrefix("file://") ? (URL(string: s)?.lastPathComponent ?? s) : s
        return UIImage(contentsOfFile: LocalStore.url(filename).path)
    }

    /// Persist every gallery photo to the caches dir; set galleryUrls + cover (first).
    private func persistPhotos() {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        var urls: [String] = []
        for (i, img) in photos.enumerated() {
            guard let out = ImageEncoder.encode(img, quality: 0.85) else { continue }
            let stamp = Int(Date().timeIntervalSince1970)
            let url = dir.appendingPathComponent("recipe-\(draft.id)-\(stamp)-\(i).\(out.ext)")
            if (try? out.data.write(to: url)) != nil { urls.append(url.absoluteString) }
        }
        draft.galleryUrls = urls.isEmpty ? nil : urls
        draft.thumbnailUrl = urls.first ?? draft.thumbnailUrl
    }

    private var servingsBinding: Binding<Int> {
        Binding(get: { draft.servings ?? 1 }, set: { draft.servings = $0 })
    }

    /// Bridge the stored free-text duration ("1 hr 20 min") to total minutes for the wheel, writing
    /// back a tidy formatted string (nil when 0 so an unset time stays unset).
    private func minutesBinding(for field: Binding<String?>) -> Binding<Int> {
        Binding(
            get: { Recipe.minutes(from: field.wrappedValue) ?? 0 },
            set: { field.wrappedValue = $0 == 0 ? nil : Recipe.formatMinutes($0) }
        )
    }

    private func save() {
        Haptics.success()
        // Trim + drop empty entries, renumber steps.
        draft.title = draft.title.trimmingCharacters(in: .whitespaces)
        draft.ingredients = draft.ingredients.compactMap { g in
            var g = g
            g.items = g.items.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            return g.items.isEmpty ? nil : g
        }
        var steps: [DirectionStep] = []
        for s in draft.directions {
            let t = s.text.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { steps.append(DirectionStep(stepIndex: steps.count + 1, text: t)) }
        }
        draft.directions = steps

        persistPhotos()
        draft.nutrition = nil   // ingredients may have changed → recompute kcal from them on next render

        recipe = draft
        onSave(draft)
        dismiss()
    }
}

/// A Clock-alarm-style hour + minute wheel for entering a duration in minutes. Two `.wheel` pickers
/// side by side (0–23 hr, 0–59 min) so the user spins a time instead of typing "12 min".
private struct DurationWheel: View {
    @Binding var minutes: Int

    private var hours: Binding<Int> {
        Binding(get: { minutes / 60 }, set: { minutes = $0 * 60 + minutes % 60 })
    }
    private var mins: Binding<Int> {
        Binding(get: { minutes % 60 }, set: { minutes = (minutes / 60) * 60 + $0 })
    }

    var body: some View {
        HStack(spacing: 0) {
            wheel(value: hours, range: 0...23, unit: "hr")
            wheel(value: mins, range: 0...59, unit: "min")
        }
        .frame(maxHeight: 130)
    }

    private func wheel(value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        Picker(unit, selection: value) {
            ForEach(Array(range), id: \.self) { n in
                Text("\(n) \(unit)").tag(n)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

// `Binding<String?>.orEmpty()` lives in Binding+OrEmpty.swift.
