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
    @State private var showFinish = false

    private var total: Int { environment.groceryItems.count }
    private var checked: Int { environment.groceryItems.filter(\.checked).count }
    private var progress: Double { total == 0 ? 0 : Double(checked) / Double(total) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    header
                    if environment.groceryItems.isEmpty {
                        GroceryEmptyState()
                    } else {
                        list
                    }
                    addRow
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, 120)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .navigationTitle("Grocery")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if environment.groceryItems.isEmpty {
                    await environment.loadGroceryList()
                }
            }
            .confirmationDialog("Finish grocery run", isPresented: $showFinish, titleVisibility: .visible) {
                Button("Clear checked items") {
                    withAnimation(AppMotion.smooth) { environment.clearCheckedGroceryItems() }
                }
                Button("Clear everything", role: .destructive) {
                    withAnimation(AppMotion.smooth) {
                        for item in environment.groceryItems {
                            environment.removeGroceryItem(id: item.id)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\(total - checked) unchecked item\(total - checked == 1 ? "" : "s") remaining.")
            }
        }
        .tint(AppTheme.accentInk)
    }

    // MARK: Header + progress ring

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your list")
                    .font(AppFont.display(22, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(total == 0 ? "Nothing to shop yet" : "\(checked) of \(total) picked up")
                    .font(AppFont.body(14))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            if total > 0 {
                ProgressRing(progress: progress, checked: checked, total: total)
                    .frame(width: 52, height: 52)
                Button {
                    Haptics.tap(); showFinish = true
                } label: {
                    Text("Finish")
                        .font(AppFont.body(14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(AppTheme.surface, in: Capsule())
                        .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    // MARK: List

    private var list: some View {
        VStack(spacing: AppSpacing.md) {
            ForEach(GrocerySort.grouped(environment.groceryItems), id: \.aisle) { section in
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Image(systemName: section.aisle.icon).font(.system(size: 12, weight: .semibold))
                        Text(section.aisle.label).font(AppFont.body(12, weight: .bold)).textCase(.uppercase)
                        Spacer()
                        Text("\(section.items.count)").font(AppFont.body(12, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.horizontal, AppSpacing.md).padding(.vertical, 10)

                    ForEach(section.items) { item in
                        GroceryRow(item: item) { toggle(item) }
                        if item.id != section.items.last?.id {
                            Rectangle().fill(AppTheme.separator).frame(height: 1).padding(.leading, 44)
                        }
                    }
                }
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
            }
        }
    }

    // MARK: Add row

    private var addRow: some View {
        HStack(spacing: AppSpacing.xs) {
            TextField("Add item to your list…", text: $newItem)
                .font(AppFont.body(16))
                .foregroundStyle(AppTheme.textPrimary)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit(addItem)
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 46)
                .background(AppTheme.surface, in: Capsule())
                .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
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

// MARK: - Grocery row

struct GroceryRow: View {
    let item: GroceryItem
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.checked ? AppTheme.accent : AppTheme.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
                Text(item.ingredientName)
                    .font(AppFont.body(17))
                    .foregroundStyle(item.checked ? AppTheme.textTertiary : AppTheme.textPrimary)
                    .strikethrough(item.checked, color: AppTheme.textTertiary)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
