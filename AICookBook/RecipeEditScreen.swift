//
//  RecipeEditScreen.swift
//  CraveCircle (AICookBook)
//
//  Edit a recipe you own — title, times, servings, ingredient groups, and steps.
//  Owner-only (surfaced from the Recipe Detail glass Edit button). Saves back to the
//  open recipe + the library; wires to PATCH /recipes/{id} when the backend is live.
//

import SwiftUI
import PhotosUI

struct RecipeEditScreen: View {
    @Binding var recipe: Recipe
    var onSave: (Recipe) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Recipe
    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?

    init(recipe: Binding<Recipe>, onSave: @escaping (Recipe) -> Void) {
        _recipe = recipe
        self.onSave = onSave
        _draft = State(initialValue: recipe.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    photoPreview
                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        Label("Change photo", systemImage: "photo")
                    }
                }
                Section("Details") {
                    TextField("Title", text: $draft.title)
                    TextField("Prep time (e.g. 12 min)", text: $draft.prepTime.orEmpty())
                    TextField("Cook time (e.g. 8 min)", text: $draft.cookTime.orEmpty())
                    Stepper("Servings: \(draft.servings ?? 1)", value: servingsBinding, in: 1...30)
                }

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
            .onChange(of: pickedItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        pickedImage = ui
                    }
                }
            }
        }
    }

    @ViewBuilder private var photoPreview: some View {
        Group {
            if let pickedImage {
                Image(uiImage: pickedImage).resizable().scaledToFill()
            } else if let s = draft.thumbnailUrl, let url = URL(string: s) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Image("chickenRecipe").resizable().scaledToFill()
                }
            } else {
                Image("chickenRecipe").resizable().scaledToFill()
            }
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
    }

    /// Persist a picked photo to the caches dir and point the recipe at it (file:// URL).
    private func persistPickedImage() {
        guard let img = pickedImage, let data = img.jpegData(compressionQuality: 0.85) else { return }
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent("recipe-\(draft.id)-\(Int(Date().timeIntervalSince1970)).jpg")
        try? data.write(to: url)
        draft.thumbnailUrl = url.absoluteString
    }

    private var servingsBinding: Binding<Int> {
        Binding(get: { draft.servings ?? 1 }, set: { draft.servings = $0 })
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

        persistPickedImage()
        draft.nutrition = nil   // ingredients may have changed → recompute kcal from them on next render

        recipe = draft
        onSave(draft)
        dismiss()
    }
}

extension Binding where Value == String? {
    /// Bridge an optional-string model field to a plain-string TextField.
    func orEmpty() -> Binding<String> {
        Binding<String>(
            get: { wrappedValue ?? "" },
            set: { wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}
