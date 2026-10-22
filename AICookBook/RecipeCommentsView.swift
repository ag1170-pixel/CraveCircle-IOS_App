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

struct RecipeCommentsSection: View {
    let recipeId: String
    @EnvironmentObject private var environment: AppEnvironment
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
        VStack(alignment: .leading, spacing: AppSpacing.md) {
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
                        .frame(height: 130)
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

            // Input field
            HStack(spacing: 8) {
                Circle()
                    .fill(AppTheme.accentSoft)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Text("CC")
                            .font(AppFont.serif(12, weight: .bold))
                            .foregroundStyle(AppTheme.accentInk)
                    )

                // Attach a photo of how it turned out.
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add a photo")

                TextField("Share your tips, twists, or review...", text: $commentText)
                    .font(AppFont.body(14))
                    .focused($isFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))

                Button(action: post) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(canPost ? AppTheme.accent : AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(!canPost)
                .accessibilityLabel("Post comment")
            }
            .padding(.bottom, 4)
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
                VStack(spacing: AppSpacing.sm) {
                    ForEach(comments) { comment in
                        CommentRow(comment: comment) {
                            Haptics.tap()
                            withAnimation(AppMotion.snappy) {
                                environment.toggleCommentLike(recipeId: recipeId, commentId: comment.id)
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, AppSpacing.md)
        .task(id: recipeId) {
            while !Task.isCancelled {
                await environment.refreshComments(for: recipeId)
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }
        }
    }
}

// MARK: - Comment Row

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

                // Like interaction
                HStack(spacing: 4) {
                    Button(action: onLike) {
                        HStack(spacing: 3) {
                            Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(comment.isLiked ? Color.red : AppTheme.textTertiary)
                            if comment.likesCount > 0 {
                                Text("\(comment.likesCount)")
                                    .font(AppFont.body(11, weight: .semibold))
                                    .foregroundStyle(comment.isLiked ? Color.red : AppTheme.textTertiary)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.trailing, 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(comment.isLiked ? "Unlike comment" : "Like comment")
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }
}
