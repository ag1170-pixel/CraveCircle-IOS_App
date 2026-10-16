//
//  GroceryScreen.swift
//  CraveCircle (AICookBook)
//
//  Grocery list — matched to the web `grocery` page: a progress ring, checkable items,
//  add-your-own field, and a "Finish run" action. Kitchen-friendly rows, coral accent.
//  Uses the live grocery list when signed in; falls back to local demo items otherwise.
//

import SwiftUI

struct GroceryScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var newItem = ""
    @State private var catHeld = false          // true while dragging the grocery cat → freeze scroll
    @State private var selectedDish: String? = nil   // nil = All; else show only that dish's ingredients
    @State private var listHeight: CGFloat = 0
    @AppStorage("grocery_sort_mode") private var sortModeRaw = GrocerySortMode.recipe.rawValue

    private var sortMode: GrocerySortMode { GrocerySortMode(rawValue: sortModeRaw) ?? .recipe }

    // Swiggy-style rotating terms — only the quoted word cycles ("Add 'milk'").
    static let addHints = ["milk", "eggs", "bananas", "coffee", "paneer"]

    private var groups: [(dish: String, items: [GroceryItem])] { GrocerySort.groupedByDish(environment.groceryItems) }
    private var visibleGroups: [(dish: String, items: [GroceryItem])] {
        guard let d = selectedDish else { return groups }
        return groups.filter { $0.dish == d }
    }
    private var shownItems: [GroceryItem] {
        if sortMode == .recipe { return visibleGroups.flatMap(\.items) }
        // Aisle mode: still honor the dish filter so you can focus one recipe's items.
        guard let d = selectedDish else { return environment.groceryItems }
        return environment.groceryItems.filter { ($0.recipeName ?? GrocerySort.handAddedLabel) == d }
    }

    // Progress reflects the CURRENT view — cooking just the burger shows the burger's progress.
    private var total: Int { shownItems.count }
    private var checked: Int { shownItems.filter(\.checked).count }
    private var progress: Double { total == 0 ? 0 : Double(checked) / Double(total) }
    private var progressLine: String {
        if total == 0 { return "Nothing to shop yet" }
        if let dish = selectedDish { return "\(checked) of \(total) · \(dish)" }
        return "\(checked) of \(total) picked up"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    header
                    if environment.groceryItems.isEmpty {
                        GroceryEmptyState()
                    } else {
                        sortBar
                        if groups.count > 1 { dishFilter }   // filter by recipe in BOTH modes
                        checklist
                    }
                    addRow
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xl)
            }
            .doodleScreenBackground()   // static wallpaper behind text/gaps; item boxes stay opaque
            .overlayPreferenceValue(GRowKey.self) { rows in
                GroceryCat(rows: rows, catHeld: $catHeld)   // fishes the list; draggable like the Home cat
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(catHeld)          // don't let the page scroll (and cancel the drag) while held
            .navigationTitle("Grocery")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if environment.groceryItems.isEmpty {
                    await environment.loadGroceryList()
                }
            }
            .onChange(of: environment.groceryItems) { _, items in
                // If the focused dish is fully cleared, fall back to All.
                if let d = selectedDish, !GrocerySort.groupedByDish(items).contains(where: { $0.dish == d }) {
                    selectedDish = nil
                }
            }
            // When switching to By Aisle, the per-dish filter no longer applies — reset to All.
            .onChange(of: sortModeRaw) { _, mode in
                listHeight = 0
                if mode == GrocerySortMode.aisle.rawValue { selectedDish = nil }
            }
            .onChange(of: selectedDish) { _, _ in listHeight = 0 }
        }
        .tint(AppTheme.accentInk)
    }

    // MARK: Sort bar (By Recipe / By Aisle — Osta-style ⇅ toggle)

    private var sortBar: some View {
        HStack(spacing: 8) {
            Button {
                Haptics.success()
                let dish = selectedDish
                withAnimation(AppMotion.snappy) {
                    environment.finishGrocery(dish: dish)
                    selectedDish = nil
                }
            } label: {
                Text("Finish")
                    .font(AppFont.body(14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.surface, in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selectedDish == nil ? "Finish the whole list" : "Finish \(selectedDish ?? "this recipe")")
            Picker("Sort by", selection: sortModeBinding) {
                ForEach(GrocerySortMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.textSecondary)
            .accessibilityLabel("Sort list")
            Spacer()
        }
    }

    private var sortModeBinding: Binding<GrocerySortMode> {
        Binding(get: { sortMode },
                set: { newMode in withAnimation(AppMotion.smooth) { sortModeRaw = newMode.rawValue } })
    }

    // MARK: Header + progress ring

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your list")
                    .font(AppFont.display(22, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(progressLine)
                    .font(AppFont.body(14))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            if total > 0 {
                ProgressRing(progress: progress, checked: checked, total: total)
                    .frame(width: 52, height: 52)
                listMenu
            }
        }
    }

    // Osta-style "Share & collaborate" menu (replaces the old Finish button).
    private var listMenu: some View {
        Menu {
            ShareLink(item: shareText) {
                Label("Invite friend", systemImage: "person.badge.plus")
            }
            Button {
                Haptics.tap(); UIPasteboard.general.string = shareText
            } label: {
                Label("Copy to clipboard", systemImage: "doc.on.doc")
            }
            Button {
                Haptics.select()
                withAnimation(AppMotion.snappy) { environment.markAllGroceryComplete(dish: selectedDish) }
            } label: {
                Label("Mark all as complete", systemImage: "checkmark.circle")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 36, height: 36)
                .background(AppTheme.surface, in: Circle())
                .overlay(Circle().stroke(AppTheme.hairline, lineWidth: 1))
        }
        .accessibilityLabel("List options")
    }

    /// Plain-text snapshot of the list — shared via "Invite friend" and "Copy to clipboard".
    private var shareText: String {
        let lines = environment.groceryItems.map { "• \($0.ingredientName)" }
        return "My CraveCircle grocery list:\n" + lines.joined(separator: "\n")
    }

    // MARK: Dish filter (focus one dish to cook)

    private var dishFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                dishChip(title: "All", active: selectedDish == nil) { selectedDish = nil }
                ForEach(groups, id: \.dish) { g in
                    dishChip(title: g.dish, active: selectedDish == g.dish) { selectedDish = g.dish }
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
        // Report this horizontal strip so the tab-switch swipe ignores it (a sideways swipe on the
        // dish chips should scroll them, not flip to the next tab).
        .background(GeometryReader { geo in
            Color.clear.preference(key: HorizontalScrollFrameKey.self, value: [geo.frame(in: .global)])
        })
    }

    private func dishChip(title: String, active: Bool, _ tap: @escaping () -> Void) -> some View {
        Button {
            Haptics.select()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { tap() }
        } label: {
            Text(title)
                .font(AppFont.body(14, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(active ? AppTheme.onAccent : AppTheme.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(active ? AppTheme.accent : AppTheme.surface, in: Capsule())
                .overlay(Capsule().stroke(active ? Color.clear : AppTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Checklist (inset grouped — recipe groups or aisle groups)

    private var checklist: some View {
        List {
            if sortMode == .recipe {
                ForEach(visibleGroups, id: \.dish) { section in
                    grocerySection(title: section.dish,
                                   icon: section.dish == GrocerySort.handAddedLabel ? "pencil" : "fork.knife",
                                   items: section.items,
                                   showRecipe: false)
                }
            } else {
                ForEach(GrocerySort.grouped(shownItems), id: \.aisle) { section in
                    grocerySection(title: section.aisle.label, icon: section.aisle.icon, items: section.items, showRecipe: true)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
        .frame(height: listHeight > 1 ? listHeight : estimatedListHeight)
        .padding(.horizontal, -AppSpacing.md)
    }

    private var estimatedListHeight: CGFloat {
        let sections = sortMode == .recipe ? visibleGroups.count : GrocerySort.grouped(shownItems).count
        return CGFloat(shownItems.count) * 60 + CGFloat(max(sections, 1)) * 40 + 12
    }

    @ViewBuilder
    private func grocerySection(title: String, icon: String, items: [GroceryItem], showRecipe: Bool) -> some View {
        Section {
            ForEach(items) { item in
                groceryRow(item, showRecipe: showRecipe)
            }
        } header: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text("\(items.filter { !$0.checked }.count)/\(items.count)")
            }
        }
    }

    private func groceryRow(_ item: GroceryItem, showRecipe: Bool) -> some View {
        let parts = IngredientListFormat.displayParts(item.ingredientName)
        let subtitle: AttributedString? = {
            guard showRecipe, let recipe = item.recipeName, !recipe.isEmpty else { return nil }
            return AttributedString(recipe)
        }()
        return ChecklistRow(
            title: parts.nameDashAmount ? ingredientLine(item.ingredientName, size: 17) : AttributedString(parts.name),
            subtitle: subtitle,
            trailing: parts.nameDashAmount ? nil : parts.amount,
            checked: item.checked
        ) {
            toggle(item)
        }
        .listRowBackground(AppTheme.surface)
        .readChecklistHeight($listHeight)
        .reportsGroceryRow(id: item.id, done: item.checked)
    }

    // MARK: Add row

    private var addRow: some View {
        HStack(spacing: AppSpacing.xs) {
            TextField("", text: $newItem)
                .font(AppFont.body(16))
                .foregroundStyle(AppTheme.textPrimary)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit(addItem)
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 46)
                .background(AppTheme.surface, in: Capsule())
                .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
                .overlay(alignment: .leading) {
                    if newItem.isEmpty {
                        CyclingPlaceholder(prefix: "Add ", phrases: Self.addHints)
                            .padding(.leading, AppSpacing.md)
                            .allowsHitTesting(false)
                    }
                }
            Button {
                addItem()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.onAccent)
                    .frame(width: 46, height: 46)
                    .background(AppTheme.accent, in: Circle())
                    .opacity(newItem.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Add item")
            .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: Actions

    private func toggle(_ item: GroceryItem) {
        Haptics.toggle(!item.checked)
        withAnimation(AppMotion.snappy) {
            environment.toggleGroceryItemLocal(id: item.id)
        }
        Task { await environment.toggleGroceryItem(id: item.id, checked: !item.checked) }
    }

    private func addItem() {
        let name = newItem.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        Haptics.tap()
        withAnimation(AppMotion.snappy) {
            environment.addCustomGroceryItem(name: name)
        }
        newItem = ""
    }
}

// MARK: - Add-item sheet (opened by the context-aware + FAB on the Grocery tab)

/// Osta-style "Add item to your list" bottom sheet: one field + a round send button. Stays open so
/// you can add several items in a row; dismiss by swiping down.
struct AddGroceryItemSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var text = ""
    @FocusState private var focused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Add item to your list")
                .font(AppFont.display(20, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            HStack(spacing: AppSpacing.xs) {
                TextField("", text: $text)
                    .font(AppFont.body(17))
                    .foregroundStyle(AppTheme.textPrimary)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(add)
                    .padding(.horizontal, AppSpacing.md)
                    .frame(height: 50)
                    .background(AppTheme.surface, in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
                    .overlay(alignment: .leading) {
                        if text.isEmpty {
                            CyclingPlaceholder(prefix: "Add ", phrases: GroceryScreen.addHints)
                                .padding(.leading, AppSpacing.md)
                                .allowsHitTesting(false)
                        }
                    }
                Button(action: add) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.onAccent)
                        .frame(width: 50, height: 50)
                        .background(AppTheme.accent, in: Circle())
                        .opacity(trimmed.isEmpty ? 0.5 : 1)
                }
                .buttonStyle(PressableStyle())
                .disabled(trimmed.isEmpty)
                .accessibilityLabel("Add item")
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.background)
        .presentationDetents([.height(180)])
        .onAppear { focused = true }
    }

    private func add() {
        guard !trimmed.isEmpty else { return }
        Haptics.tap()
        withAnimation(AppMotion.snappy) { environment.addCustomGroceryItem(name: trimmed) }
        text = ""
        focused = true      // keep the keyboard up for the next item
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    let progress: Double
    let checked: Int
    let total: Int

    var body: some View {
        ZStack {
            Circle().stroke(AppTheme.separator, lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(AppMotion.smooth, value: progress)
            Text("\(checked)/\(total)")
                .font(AppFont.mono(11, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}

// MARK: - Empty state

struct GroceryEmptyState: View {
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "basket")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(AppTheme.textTertiary)
            Text("Your grocery list is empty")
                .font(AppFont.body(16, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Open a recipe and tap \u{201C}Add to Grocery\u{201D} or type an ingredient below.")
                .font(AppFont.body(14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
        .padding(.horizontal, AppSpacing.md)
    }
}

// MARK: - Scaffold demo items

extension GroceryItem {
    static let demo: [GroceryItem] = [
        .init(id: "1", ingredientName: "2 chicken breasts (diced)", checked: true),
        .init(id: "2", ingredientName: "200g rigatoni pasta", checked: true),
        .init(id: "3", ingredientName: "1 cup heavy cream", checked: false),
        .init(id: "4", ingredientName: "1 block paneer (cubed)", checked: false),
        .init(id: "5", ingredientName: "3 cloves garlic (minced)", checked: false),
        .init(id: "6", ingredientName: "1 bunch fresh basil", checked: false),
        .init(id: "7", ingredientName: "2 salmon fillets", checked: false),
        .init(id: "8", ingredientName: "1 jar sun-dried tomatoes", checked: false),
        .init(id: "9", ingredientName: "1 tub Greek yogurt", checked: true),
        .init(id: "10", ingredientName: "2 tbsp hot honey", checked: false),
        .init(id: "11", ingredientName: "1 can crushed tomatoes", checked: false),
        .init(id: "12", ingredientName: "1 cup panko breadcrumbs", checked: false)
    ]
}
