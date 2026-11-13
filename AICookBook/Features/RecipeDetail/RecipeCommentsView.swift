//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: RecipeCommentsView.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Interactive discussion thread for reviews, tips, and cooking modifications on recipes.
//
// 2. ARCHITECTURAL ROLE:
//    Displays community comments with author avatars, timestamps, and moderation controls synced to Supabase.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "RecipeCommentsView provides a community space on each dish where cooks can share modifications, ask ingredient swap questions, and leave reviews."
//
// ==============================================================================
//

//
//  RecipeCommentsView.swift
//  CraveCircle (AICookBook)
//
//  Community comments section for recipes with live posting, likes, and creator handles.
//

import SwiftUI
#if !XTOOL_WSL
import PhotosUI
#endif

// MARK: - SwiftUI View Component
struct RecipeCommentsSection: View {
    let recipeId: String
    @Environment(AppEnvironment.self) private var environment
    @State private var commentText = ""
    @State private var isSubmitting = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var notice: String?
    @FocusState private var isFocused: Bool

    private var comments: [RecipeComment] {
        environment.comments(for: recipeId)
    }

    private var canPost: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pickedImage != nil
    }

    private func post() {
        guard canPost else { return }
        let text = commentText
        let image = pickedImage
        Haptics.tap()
        Task {
            if let message = await environment.addComment(recipeId: recipeId, text: text, image: image) {
                notice = message
                Haptics.warning()
                return
            }
            withAnimation(AppMotion.snappy) {
                commentText = ""
                pickedImage = nil
                pickedItem = nil
                notice = nil
                isFocused = false
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header with comment count
            HStack(alignment: .firstTextBaseline) {
                Text("Circle Comments")
                    .sectionLabelStyle(AppTheme.accentInk)
                Spacer()
                Text("\(comments.count) \(comments.count == 1 ? "comment" : "comments")")
                    .font(AppFont.body(13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            // Attached-photo preview (how their dish turned out) with a remove button.
            if let img = pickedImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 96)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Button {
                        withAnimation(AppMotion.snappy) { pickedImage = nil; pickedItem = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white, .black.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .accessibilityLabel("Remove photo")
                }
            }

            // Composer: one rounded field, photo on the left, send button inside on the right.
            HStack(alignment: .bottom, spacing: AppSpacing.xs) {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Image(systemName: "photo")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add a photo")

                TextField("Add a comment", text: $commentText, axis: .vertical)
                    .lineLimit(1...4)
                    .font(AppFont.body(15))
                    .focused($isFocused)
                    .padding(.vertical, 7)

                Button(action: post) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(canPost ? AppTheme.accent : AppTheme.textTertiary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .disabled(!canPost)
                .accessibilityLabel("Post comment")
            }
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 4)
            .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        await MainActor.run { withAnimation(AppMotion.snappy) { pickedImage = ui } }
                    }
                }
            }
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        await MainActor.run { withAnimation(AppMotion.snappy) { pickedImage = ui } }
                    }
                }
            }
            if let notice {
                Text(notice)
                    .font(AppFont.body(13, weight: .medium))
                    .foregroundStyle(Color(hex: "C7362A"))
            }

            // Comments list
            if comments.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("No comments yet. Be the first to cook & review!")
                        .font(AppFont.body(13))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
                .background(AppTheme.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(comments.enumerated()), id: \.element.id) { index, comment in
                        CommentRow(comment: comment) {
                            Haptics.tap()
                            withAnimation(AppMotion.snappy) {
                                environment.toggleCommentLike(recipeId: recipeId, commentId: comment.id)
                            }
                        }
                        // Long-press menu only appears for the three roles that can actually
                        // delete server-side (author, recipe owner, admin). Everyone else sees
                        // no affordance, so it doesn't look like a broken button.
                        .contextMenu {
                            if environment.canDeleteComment(comment, recipeId: recipeId) {
                                Button(role: .destructive) {
                                    Haptics.warning()
                                    withAnimation(AppMotion.snappy) {
                                        environment.deleteComment(recipeId: recipeId, commentId: comment.id)
                                    }
                                } label: {
                                    Label("Delete comment", systemImage: "trash")
                                }
                            }
                        }
                        if index < comments.count - 1 {
                            Divider().overlay(AppTheme.separator)
                        }
                    }
                }
            }
        }
        .task(id: recipeId) {
            while !Task.isCancelled {
                await environment.refreshComments(for: recipeId)
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }
}

// MARK: - Comment Row

// MARK: - SwiftUI View Component
struct CommentRow: View {
    let comment: RecipeComment
    var onLike: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar initials
            Circle()
                .fill(AppTheme.accentSoft)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(comment.initials)
                        .font(AppFont.serif(11, weight: .bold))
                        .foregroundStyle(AppTheme.accentInk)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(comment.authorName)
                        .font(AppFont.body(13, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(comment.authorUsername)
                        .font(AppFont.body(11, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                    Spacer()
                    Text(comment.displayTime)
                        .font(AppFont.body(11))
                        .foregroundStyle(AppTheme.textTertiary)
                }

                if !comment.text.isEmpty {
                    Text(comment.text)
                        .font(AppFont.body(14))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Photo of how their dish turned out.
                if let data = comment.imageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 170)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(.top, 2)
                }
            }

            // Like button on the trailing edge (Instagram-style): heart with the count underneath.
            Button(action: onLike) {
                VStack(spacing: 2) {
                    Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .semibold))
                    if comment.likesCount > 0 {
                        Text("\(comment.likesCount)")
                            .font(AppFont.body(11, weight: .semibold))
                            .monospacedDigit()
                    }
                }
                .foregroundStyle(comment.isLiked ? Color.red : AppTheme.textTertiary)
                .frame(minWidth: 32, minHeight: 32)     // comfortable tap target without adding row height
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(comment.isLiked ? "Unlike comment" : "Like comment")
        }
        .padding(.vertical, AppSpacing.xs)
    }
}
