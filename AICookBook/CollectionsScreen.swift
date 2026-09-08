//
//  CollectionsScreen.swift
//  CraveCircle (AICookBook)
//
//  Collections — matched to the web `collections` page: recipes grouped into shareable
//  sets. "Yours" and "Shared with you" sections, a create-collection sheet. Coral + cream.
//

import SwiftUI

struct CollectionsScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var showCreate = false
    @State private var selectedCollection: CollectionItem?

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    section("Yours", environment.ownedCollections)
                    section("Shared with you", environment.sharedCollections)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .navigationTitle("Collections")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap(); showCreate = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.onAccent)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.accent, in: Circle())
                    }
                    .accessibilityLabel("New collection")
                }
            }
            .navigationDestination(item: $selectedCollection) { collection in
                CollectionDetailScreen(collection: collection)
            }
            .sheet(isPresented: $showCreate) {
                CreateCollectionSheet()
                    .presentationDetents([.height(320)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(AppTheme.background)
            }
            .tint(AppTheme.accentInk)
        }
    }

    private func section(_ title: String, _ collections: [CollectionItem]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppFont.display(22, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                ForEach(collections) { item in
                    Button {
                        Haptics.tap()
                        selectedCollection = item
                    } label: {
                        CollectionCard(item: item)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            Haptics.tap()
                            withAnimation(AppMotion.snappy) {
                                environment.deleteCollection(id: item.id)
                            }
                        } label: {
                            Label("Delete Collection", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Collection card

struct CollectionCard: View {
    let item: CollectionItem

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            ZStack(alignment: .topTrailing) {
                Image(item.imageName)
                    .resizable().scaledToFill()
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                if item.shared {
                    Label("Shared", systemImage: "person.2.fill")
                        .font(AppFont.body(11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(8)
                }
            }
            Text(item.name)
                .font(AppFont.body(16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
            Text("\(item.count) recipes")
                .font(AppFont.body(13))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}

// MARK: - Create sheet

struct CreateCollectionSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var shared = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("New collection")
                .font(AppFont.display(24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            TextField("Collection name", text: $name)
                .font(AppFont.body(16))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 50)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))

            Toggle(isOn: $shared) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Shared collection").font(AppFont.body(16, weight: .semibold)).foregroundStyle(AppTheme.textPrimary)
                    Text("Friends can add recipes too").font(AppFont.body(13)).foregroundStyle(AppTheme.textSecondary)
                }
            }
            .tint(AppTheme.accent)

            PillButton(title: "Create collection", systemImage: "plus", kind: .filled, fullWidth: true) {
                Haptics.success()
                environment.createCollection(name: name, isShared: shared)
                dismiss()
            }
            .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.top, AppSpacing.xxs)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.background)
    }
}
