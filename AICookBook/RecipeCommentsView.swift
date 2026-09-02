//
//  RecipeCommentsView.swift
//  CraveCircle (AICookBook)
//
//  Community comments section for recipes with live posting, likes, and creator handles.
//

import SwiftUI

struct RecipeCommentsSection: View {
    let recipeId: String
    @EnvironmentObject private var environment: AppEnvironment
    @State private var commentText = ""
    @State private var isSubmitting = false
    @FocusState private var isFocused: Bool

    private var comments: [RecipeComment] {
        environment.comments(for: recipeId)
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

                TextField("Share your tips, twists, or review...", text: $commentText)
                    .font(AppFont.body(14))
                    .focused($isFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))

                Button {
                    guard !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    Haptics.tap()
                    withAnimation(AppMotion.snappy) {
                        environment.addComment(recipeId: recipeId, text: commentText)
                        commentText = ""
                        isFocused = false
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppTheme.textTertiary : AppTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.bottom, 4)

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
                    Text(comment.timeAgo)
                        .font(AppFont.body(11))
                        .foregroundStyle(AppTheme.textTertiary)
                }

                Text(comment.text)
                    .font(AppFont.body(14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

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
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }
}
