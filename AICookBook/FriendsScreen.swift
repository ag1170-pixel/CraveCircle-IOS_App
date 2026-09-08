//
//  FriendsScreen.swift
//  CraveCircle (AICookBook)
//
//  Creators / Friends — matched to the web `friends` + `creators` pages. Two tabs:
//  a Feed of recipes shared by people you follow, and friend Requests (incoming/outgoing).
//

import SwiftUI

struct FriendsScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var tab = 0   // 0 Feed, 1 Requests
    @State private var showAddFriend = false
    @State private var selectedCreator: (handle: String, name: String?)?

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                LimeSegmentedControl(
                    segments: ["Feed", "Requests \(environment.incomingRequests.count)"],
                    selection: $tab
                )

                if tab == 0 {
                    circleFriendsBar
                    feed
                } else {
                    requests
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Circle")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Haptics.tap()
                    showAddFriend = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Add")
                            .font(AppFont.body(14, weight: .bold))
                    }
                    .foregroundStyle(AppTheme.accentInk)
                }
            }
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: Binding(
            get: { selectedCreator.map { IdentifiableCreator(handle: $0.handle, name: $0.name) } },
            set: { selectedCreator = $0.map { (handle: $0.handle, name: $0.name) } }
        )) { creator in
            CreatorProfileSheet(handle: creator.handle, name: creator.name)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            if environment.recipes.isEmpty { await environment.refreshRecipes() }
        }
        .tint(AppTheme.accentInk)
    }

    // MARK: - Circle friends horizontal bar

    private var circleFriendsBar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text("In Your Circle (\(environment.circleFriends.count))")
                    .font(AppFont.body(14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button {
                    Haptics.tap()
                    showAddFriend = true
                } label: {
                    Text("+ Add Friend")
                        .font(AppFont.body(12, weight: .semibold))
                        .foregroundStyle(AppTheme.accentInk)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(environment.circleFriends) { friend in
                        Button {
                            Haptics.tap()
                            selectedCreator = (handle: friend.username, name: friend.name)
                        } label: {
                            VStack(spacing: 5) {
                                Circle()
                                    .fill(AppTheme.accentSoft)
                                    .frame(width: 58, height: 58)
                                    .overlay(
                                        Text(friend.initials)
                                            .font(AppFont.serif(18, weight: .bold))
                                            .foregroundStyle(AppTheme.accentInk)
                                    )
                                    .overlay(Circle().stroke(AppTheme.accent, lineWidth: 1.5).padding(-2))

                                Text(friend.name.split(separator: " ").first.map(String.init) ?? friend.name)
                                    .font(AppFont.body(12, weight: .medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .lineLimit(1)

                                Text("\(friend.recipesCount) recipes")
                                    .font(AppFont.body(10))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            .frame(width: 68)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()
        }
        .padding(.bottom, AppSpacing.xs)
    }

    // MARK: Feed

    @ViewBuilder private var feed: some View {
        if environment.recipes.isEmpty {
            emptyFeed
        } else {
            LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                ForEach(environment.recipes) { recipe in
                    LibraryCard(recipe: recipe) { environment.selectRecipe(recipe) }
                }
            }
        }
    }

    private var emptyFeed: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "person.2").font(.system(size: 32)).foregroundStyle(AppTheme.textTertiary)
            Text("Your Circle is quiet").font(AppFont.body(16, weight: .semibold)).foregroundStyle(AppTheme.textPrimary)
            Text("Follow creators and friends to see what they're cooking.")
                .font(AppFont.body(14)).foregroundStyle(AppTheme.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, AppSpacing.xl)
    }

    // MARK: Requests

    private var requests: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            if !environment.incomingRequests.isEmpty {
                requestGroup("Incoming Requests (\(environment.incomingRequests.count))", environment.incomingRequests, incoming: true)
            } else {
                Text("No pending incoming requests.")
                    .font(AppFont.body(14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.vertical, AppSpacing.sm)
            }

            if !environment.outgoingRequests.isEmpty {
                requestGroup("Outgoing Requests (\(environment.outgoingRequests.count))", environment.outgoingRequests, incoming: false)
            }
        }
    }

    private func requestGroup(_ title: String, _ items: [FriendRequestItem], incoming: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title).sectionLabelStyle()
            VStack(spacing: 0) {
                ForEach(items) { item in
                    FriendRequestRow(
                        item: item,
                        incoming: incoming,
                        onAccept: {
                            Haptics.success()
                            withAnimation(AppMotion.snappy) {
                                environment.acceptFriendRequest(id: item.id)
                            }
                        },
                        onDecline: {
                            Haptics.tap()
                            withAnimation(AppMotion.snappy) {
                                environment.declineFriendRequest(id: item.id)
                            }
                        },
                        onCancel: {
                            Haptics.tap()
                            withAnimation(AppMotion.snappy) {
                                environment.cancelOutgoingRequest(id: item.id)
                            }
                        }
                    )
                    if item.id != items.last?.id {
                        Rectangle().fill(AppTheme.separator).frame(height: 1).padding(.leading, 60)
                    }
                }
            }
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
        }
    }
}

private struct IdentifiableCreator: Identifiable {
    var id: String { handle }
    let handle: String
    let name: String?
}

// MARK: - Request row

struct FriendRequestRow: View {
    let item: FriendRequestItem
    let incoming: Bool
    var onAccept: (() -> Void)? = nil
    var onDecline: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Circle().fill(AppTheme.accentSoft).frame(width: 42, height: 42)
                .overlay(Text(item.initials).font(AppFont.body(15, weight: .bold)).foregroundStyle(AppTheme.accentInk))
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(AppFont.body(16, weight: .semibold)).foregroundStyle(AppTheme.textPrimary)
                Text(item.username).font(AppFont.body(13)).foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            if incoming {
                HStack(spacing: 8) {
                    Button { onAccept?() } label: {
                        Text("Accept").font(AppFont.body(14, weight: .bold)).foregroundStyle(AppTheme.onAccent)
                            .padding(.horizontal, 14).padding(.vertical, 8).background(AppTheme.accent, in: Capsule())
                    }.buttonStyle(PressableStyle())
                    Button { onDecline?() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 32, height: 32).background(AppTheme.background, in: Circle())
                            .overlay(Circle().stroke(AppTheme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Decline request")
                }
            } else {
                HStack(spacing: 8) {
                    Text("Pending").font(AppFont.body(13, weight: .medium)).foregroundStyle(AppTheme.textTertiary)
                    Button { onCancel?() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(6)
                            .background(AppTheme.background, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel request")
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
    }
}
