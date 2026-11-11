//
//  AddToGrocerySheet.swift
//  CraveCircle (AICookBook)
//
//  Modal sheet allowing the cook to select specific ingredients,
//  choose shopping portions, and add them directly to their Grocery List.
//

import SwiftUI

struct AddToGrocerySheet: View {
    let recipe: Recipe
    let initialServings: Int
    var onAdded: ((Int) -> Void)? = nil

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var groceryServings: Int
    @State private var selectedKeys: Set<String> = []

    private var baseServings: Int {
        max(1, recipe.servings ?? 2)
    }

    private var allIngredientEntries: [(key: String, groupName: String?, item: String)] {
        var entries: [(key: String, groupName: String?, item: String)] = []
        for (gIdx, group) in recipe.ingredients.enumerated() {
            for (iIdx, item) in group.items.enumerated() {
                let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                entries.append((key: "\(gIdx):\(iIdx)", groupName: group.groupName, item: trimmed))
            }
        }
        return entries
    }

    init(recipe: Recipe, initialServings: Int = 2, onAdded: ((Int) -> Void)? = nil) {
        self.recipe = recipe
        self.initialServings = initialServings
        self.onAdded = onAdded
        self._groceryServings = State(initialValue: max(1, initialServings))
    }

    private var allSelected: Bool {
        !allIngredientEntries.isEmpty && selectedKeys.count == allIngredientEntries.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    portionsSelectorCard
                    selectionHeader
                    ingredientsChecklistCard
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, 120) // Leave clearance for bottom pinned bar
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Add to Grocery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.tap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.surfaceElevated, in: Circle())
                            .overlay(Circle().stroke(AppTheme.hairline, lineWidth: 0.8))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Close")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        withAnimation(reduceMotion ? .none : AppMotion.snappy) {
                            if allSelected {
                                selectedKeys.removeAll()
                            } else {
                                selectedKeys = Set(allIngredientEntries.map(\.key))
                            }
                        }
                    } label: {
                        Text(allSelected ? "Deselect All" : "Select All")
                            .font(AppFont.body(13, weight: .bold))
                            .foregroundStyle(AppTheme.brand)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.brand.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .overlay(alignment: .bottom) {
                bottomBar
            }
            .onAppear {
                if selectedKeys.isEmpty {
                    selectedKeys = Set(allIngredientEntries.map(\.key))
                }
            }
        }
    }

    // MARK: - Portions Stepper

    private var portionsSelectorCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("SHOPPING PORTIONS")
                    .font(AppFont.label(11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.textTertiary)

                Text("\(groceryServings) \(groceryServings == 1 ? "Serving" : "Servings")")
                    .font(AppFont.body(16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    if groceryServings > 1 {
                        Haptics.tap()
                        withAnimation(reduceMotion ? .none : AppMotion.snappy) {
                            groceryServings -= 1
                        }
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(groceryServings > 1 ? AppTheme.accentInk : AppTheme.textTertiary)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.accentSoft, in: Circle())
                }
                .buttonStyle(PressableStyle())
                .disabled(groceryServings <= 1)

                Button {
                    if groceryServings < 30 {
                        Haptics.tap()
                        withAnimation(reduceMotion ? .none : AppMotion.snappy) {
                            groceryServings += 1
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.accentInk)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.accentSoft, in: Circle())
                }
                .buttonStyle(PressableStyle())
                .disabled(groceryServings >= 30)
            }
            .padding(4)
            .background(AppTheme.surface, in: Capsule())
            .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
        }
        .padding(AppSpacing.md)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    // MARK: - Selection Header

    private var selectionHeader: some View {
        HStack {
            Text("Select Ingredients")
                .font(AppFont.body(15, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            Text("\(selectedKeys.count) of \(allIngredientEntries.count) selected")
                .font(AppFont.body(13, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    // MARK: - Ingredients Checklist Card

    private var ingredientsChecklistCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if allIngredientEntries.isEmpty {
                Text("No ingredients found for this recipe.")
                    .font(AppFont.body(14))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(AppSpacing.md)
            } else {
                ForEach(Array(allIngredientEntries.enumerated()), id: \.element.key) { index, entry in
                    let isChecked = selectedKeys.contains(entry.key)
                    let scaledText = IngredientListFormat.scaledLine(entry.item, from: baseServings, to: groceryServings)
                    let alreadyInList = isAlreadyInGrocery(entry.item)

                    Button {
                        Haptics.select()
                        withAnimation(reduceMotion ? .none : AppMotion.snappy) {
                            if isChecked {
                                selectedKeys.remove(entry.key)
                            } else {
                                selectedKeys.insert(entry.key)
                            }
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 14) {
                            Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(isChecked ? AppTheme.brand : AppTheme.textTertiary)
                                .contentTransition(.symbolEffect(.replace))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(scaledText)
                                    .font(AppFont.body(15, weight: isChecked ? .semibold : .regular))
                                    .foregroundStyle(isChecked ? AppTheme.textPrimary : AppTheme.textSecondary)
                                    .multilineTextAlignment(.leading)

                                if alreadyInList {
                                    HStack(spacing: 4) {
                                        Image(systemName: "cart.fill")
                                            .font(.system(size: 10))
                                        Text("Already on your list")
                                            .font(AppFont.body(11, weight: .medium))
                                    }
                                    .foregroundStyle(AppTheme.textTertiary)
                                }
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 13)
                        .padding(.horizontal, AppSpacing.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < allIngredientEntries.count - 1 {
                        Rectangle()
                            .fill(AppTheme.separator)
                            .frame(height: 1)
                            .padding(.leading, 50)
                    }
                }
            }
        }
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    // MARK: - Bottom Pinned Bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Divider()
                .background(AppTheme.hairline)

            Button {
                addSelectedToGrocery()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "basket.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(selectedKeys.isEmpty
                         ? "Select Ingredients to Add"
                         : "Add \(selectedKeys.count) \(selectedKeys.count == 1 ? "Item" : "Items") to Grocery List")
                        .font(AppFont.body(16, weight: .bold))
                }
                .foregroundStyle(AppTheme.onBrand)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    selectedKeys.isEmpty ? Color.gray.opacity(0.35) : AppTheme.brand,
                    in: Capsule()
                )
                .shadow(color: selectedKeys.isEmpty ? .clear : .black.opacity(0.12), radius: 6, y: 2)
            }
            .buttonStyle(PressableStyle())
            .disabled(selectedKeys.isEmpty)

            Button {
                dismiss()
                environment.pendingTabSwitch = .groceries
                environment.dismissRecipeDetail()
            } label: {
                Text("View Grocery List")
                    .font(AppFont.body(13, weight: .semibold))
                    .foregroundStyle(AppTheme.accentInk)
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(AppTheme.surface.ignoresSafeArea())
    }

    // MARK: - Helper Methods

    private func isAlreadyInGrocery(_ item: String) -> Bool {
        let core = GrocerySort.coreName(item)
        guard !core.isEmpty else { return false }
        return environment.groceryItems.contains {
            $0.recipeName == recipe.title && GrocerySort.coreName($0.ingredientName) == core
        }
    }

    private func addSelectedToGrocery() {
        let itemsToAdd = allIngredientEntries
            .filter { selectedKeys.contains($0.key) }
            .map(\.item)

        guard !itemsToAdd.isEmpty else { return }

        let count = environment.addSpecificIngredientsToGrocery(
            recipe: recipe,
            items: itemsToAdd,
            servings: groceryServings
        )

        Haptics.success()
        onAdded?(count)
        dismiss()
    }
}

