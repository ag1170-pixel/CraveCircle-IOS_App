//
//  FriendsScreen.swift
//  CraveCircle (AICookBook)
//
//  "Circle" tab — people, in Apple-y shape. Big title + "Add", search by username at the top,
//  then Suggested / Contacts segments. Each row is a person with a Follow button; incoming
//  friend requests get a small banner above the list; the bottom carries an invite CTA with
//  the share-link so the recipe app itself is viral.
//

import SwiftUI

struct FriendsScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var query = ""
    @State private var segment: Segment = .suggested
    @State private var selectedCreator: (handle: String, name: String?)?
    @State private var showAddFriend = false

    private enum Segment: String, CaseIterable, Identifiable {
        case suggested = "Suggested"
        case contacts = "Contacts"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                searchField
                if !environment.incomingRequests.isEmpty { requestsBanner }
                segmentedControl
                listSection
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, 140)   // room for the invite banner + FAB
        }
        .background(AppTheme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        // Invite banner only lives under the Suggested list — Contacts has its own CTA.
        .safeAreaInset(edge: .bottom) {
            if segment == .suggested { inviteBanner }
        }
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
                        Text("Add").font(AppFont.body(14, weight: .bold))
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
            await environment.loadFriendships()
            await environment.syncShares()
        }
        .tint(AppTheme.accentInk)
    }

    // MARK: Search field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
            TextField("Search by username", text: $query)
                .font(AppFont.body(16))
                .foregroundStyle(AppTheme.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    Haptics.tap()
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(AppTheme.surface, in: Capsule())
        .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
    }

    // MARK: Pending requests banner (incoming)

    private var requestsBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(AppTheme.brand.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: "person.2.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.brand)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(environment.incomingRequests.count) friend request\(environment.incomingRequests.count == 1 ? "" : "s")")
                    .font(AppFont.body(14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Review and accept to add them to your circle.")
                    .font(AppFont.body(12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            NavigationLink {
                RequestsScreen()
            } label: {
                Text("View")
                    .font(AppFont.body(13, weight: .bold))
                    .foregroundStyle(AppTheme.onAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(AppTheme.accent, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
    }

    // MARK: Segment

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(Segment.allCases) { seg in
                let on = segment == seg
                Button {
                    Haptics.select()
                    withAnimation(AppMotion.snappy) { segment = seg }
                } label: {
                    VStack(spacing: 6) {
                        Text(seg.rawValue)
                            .font(AppFont.body(15, weight: on ? .bold : .semibold))
                            .foregroundStyle(on ? AppTheme.textPrimary : AppTheme.textTertiary)
                        Rectangle()
                            .fill(on ? AppTheme.accent : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: List

    @ViewBuilder private var listSection: some View {
        switch segment {
        case .suggested: suggestedList
        case .contacts:  contactsEmpty
        }
    }

    private var suggestedList: some View {
        let people = suggestedPeople(matching: query)
        return LazyVStack(spacing: 0) {
            if people.isEmpty {
                emptyMessage(
                    icon: "person.crop.circle.badge.questionmark",
                    title: query.isEmpty ? "No one to suggest yet" : "No one by that name",
                    subtitle: query.isEmpty
                        ? "Import a recipe or two — people whose dishes you save start showing up here."
                        : "Try a different username, or tap Add to send a request."
                )
            } else {
                ForEach(people) { person in
                    PersonRow(
                        person: person,
                        isFollowing: environment.isFollowing(creatorHandle: person.handle),
                        onTap: {
                            Haptics.tap()
                            selectedCreator = (handle: person.handle, name: person.name)
                        },
                        onFollow: {
                            Haptics.tap()
                            environment.toggleFollow(creatorHandle: person.handle)
                        }
                    )
                    if person.id != people.last?.id {
                        Divider().overlay(AppTheme.separator).padding(.leading, 74)
                    }
                }
            }
        }
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
    }

    private var contactsEmpty: some View {
        emptyMessage(
            icon: "person.crop.rectangle.stack",
            title: "Connect your contacts",
            subtitle: "Find friends who are already on CraveCircle. We'll ask once before reading your address book — it stays on your phone.",
            cta: "Open Settings"
        ) {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }

    private func emptyMessage(icon: String, title: String, subtitle: String,
                              cta: String? = nil, action: (() -> Void)? = nil) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AppTheme.textTertiary)
                .padding(.bottom, 2)
            Text(title)
                .font(AppFont.body(16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(AppFont.body(13))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)
            if let cta, let action {
                Button(action: action) {
                    Text(cta)
                        .font(AppFont.body(14, weight: .bold))
                        .foregroundStyle(AppTheme.onAccent)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(AppTheme.accent, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, AppSpacing.md)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
    }

    // MARK: Invite banner (safe-area inset at the bottom)

    private var inviteBanner: some View {
        VStack(spacing: 6) {
            Text("Invite friends that aren't on CraveCircle")
                .font(AppFont.body(13, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            ShareLink(item: URL(string: "https://cravecircle.cc")!,
                      subject: Text("CraveCircle"),
                      message: Text("Cook with me on CraveCircle — my living cookbook.")) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold))
                    Text("Invite")
                        .font(AppFont.body(15, weight: .bold))
                }
                .foregroundStyle(AppTheme.onBrand)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.brand, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            LinearGradient(colors: [AppTheme.background.opacity(0), AppTheme.background],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: Suggestions — derived from imported recipes

    private func suggestedPeople(matching q: String) -> [SuggestedPerson] {
        let myHandle = environment.currentUser?.username?.lowercased()
        let friendHandles = Set(environment.circleFriends.map {
            $0.username.replacingOccurrences(of: "@", with: "").lowercased()
        })
        // Group recipes by their creator handle and count them — a creator with more recipes in
        // the catalog is a better suggestion than a one-off.
        var buckets: [String: (handle: String, name: String?, count: Int)] = [:]
        for recipe in environment.recipes {
            guard let raw = recipe.ownerUsername else { continue }
            let clean = raw.replacingOccurrences(of: "@", with: "").lowercased()
            guard !clean.isEmpty else { continue }
            if clean == myHandle { continue }
            if friendHandles.contains(clean) { continue }
            if let existing = buckets[clean] {
                buckets[clean] = (existing.handle, existing.name, existing.count + 1)
            } else {
                buckets[clean] = (raw, nil, 1)
            }
        }
        let needle = q.replacingOccurrences(of: "@", with: "").lowercased()
        let matched = buckets.values
            .filter { needle.isEmpty || $0.handle.lowercased().contains(needle) }
            .sorted { $0.count > $1.count }
            .prefix(30)
        return matched.map { bucket in
            SuggestedPerson(
                id: bucket.handle.lowercased(),
                handle: bucket.handle,
                name: bucket.name ?? bucket.handle.replacingOccurrences(of: "@", with: "").capitalized,
                subtitle: bucket.count == 1 ? "1 recipe" : "\(bucket.count) recipes"
            )
        }
    }
}

// MARK: - Supporting models

private struct IdentifiableCreator: Identifiable {
    var id: String { handle }
    let handle: String
    let name: String?
}

private struct SuggestedPerson: Identifiable, Hashable {
    let id: String
    let handle: String
    let name: String
    let subtitle: String

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        let clean = handle.replacingOccurrences(of: "@", with: "")
        return String(clean.prefix(2)).uppercased()
    }
}

// MARK: - Row

private struct PersonRow: View {
    let person: SuggestedPerson
    let isFollowing: Bool
    let onTap: () -> Void
    let onFollow: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(AppTheme.accentSoft)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(person.initials)
                            .font(AppFont.serif(15, weight: .bold))
                            .foregroundStyle(AppTheme.accentInk)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(person.name)
                        .font(AppFont.body(15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    Text(person.subtitle)
                        .font(AppFont.body(12))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                FollowPill(isFollowing: isFollowing, action: onFollow)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Follow / Following pill — accent-filled when not yet following, hairline outline once you are.
struct FollowPill: View {
    let isFollowing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(isFollowing ? "Following" : "Follow")
                .font(AppFont.body(13, weight: .bold))
                .foregroundStyle(isFollowing ? AppTheme.textPrimary : AppTheme.onAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(isFollowing ? AppTheme.surface : AppTheme.accent, in: Capsule())
                .overlay(Capsule().stroke(isFollowing ? AppTheme.hairline : Color.clear, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Requests screen (pushed from the banner)

struct RequestsScreen: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                if !environment.incomingRequests.isEmpty {
                    requestGroup("Incoming", environment.incomingRequests, incoming: true)
                } else {
                    Text("No pending incoming requests.")
                        .font(AppFont.body(14))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                if !environment.outgoingRequests.isEmpty {
                    requestGroup("Outgoing", environment.outgoingRequests, incoming: false)
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Requests")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func requestGroup(_ title: String, _ items: [FriendRequestItem], incoming: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("\(title) (\(items.count))").sectionLabelStyle()
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
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            )
        }
    }
}

// MARK: - Request row (shared, retained from the old implementation)

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
