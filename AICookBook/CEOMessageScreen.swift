//
//  CEOMessageScreen.swift
//  CraveCircle (AICookBook)
//
//  A warm "A message from our team" screen (opened by the Write-to-CEO app-icon quick action and
//  from Profile). A decorative letter with a prominent "Write to CEO" button that opens the feedback
//  form. Brand: cream card, charcoal serif, coral CTA.
//

import SwiftUI

struct CEOMessageScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showFeedback = false

    private let coral = AppTheme.brand

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    header
                    letterCard
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, 110)   // room for the pinned button
            }
            .background(AppTheme.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { writeButton }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.surface, in: Circle())
                            .overlay(Circle().stroke(AppTheme.hairline, lineWidth: 1))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFeedback) {
                FeedbackFormView()
            }
        }
        .tint(AppTheme.accentInk)
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text("A MESSAGE ")
                    .font(AppFont.display(20, weight: .bold)).foregroundStyle(AppTheme.textPrimary)
                + Text("from")
                    .font(AppFont.serif(18, weight: .semibold)).italic().foregroundStyle(AppTheme.textSecondary)
                Text("OUR TEAM")
                    .font(AppFont.display(20, weight: .bold)).foregroundStyle(AppTheme.textPrimary)
            }
            Spacer()
            Text("✉️").font(.system(size: 40))
        }
        .padding(.top, AppSpacing.sm)
    }

    private var letterCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // decorative opening quote
            Text("\u{201C}")
                .font(.system(size: 54, weight: .bold, design: .serif))
                .foregroundStyle(coral.opacity(0.8))
                .frame(height: 24, alignment: .top)

            Text("I'd love to hear from you.")
                .font(AppFont.serif(24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Hello! We at CraveCircle really value your views. My team and I read through every piece of feedback shared here.")
                .font(AppFont.body(16)).foregroundStyle(AppTheme.textSecondary).lineSpacing(4)

            (Text("If something didn't feel right, or you wish things were better, ")
                .font(AppFont.body(16)).foregroundStyle(AppTheme.textSecondary)
            + Text("share your feedback directly with us.")
                .font(AppFont.body(16, weight: .bold)).foregroundStyle(AppTheme.textPrimary))
                .lineSpacing(4)

            Text("Your feedback helps us make CraveCircle better for everyone.")
                .font(AppFont.body(16)).foregroundStyle(AppTheme.textSecondary).lineSpacing(4)

            // diamond divider
            HStack {
                Rectangle().fill(AppTheme.hairline).frame(height: 1)
                Image(systemName: "diamond.fill").font(.system(size: 7)).foregroundStyle(coral)
                Rectangle().fill(AppTheme.hairline).frame(height: 1)
            }
            .padding(.vertical, 4)

            Text("Warmly,")
                .font(AppFont.body(15)).foregroundStyle(AppTheme.textSecondary)
            Text("The CraveCircle Team")
                .font(AppFont.serif(18, weight: .bold)).foregroundStyle(AppTheme.textPrimary)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
        // subtle double-border flourish
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card - 5, style: .continuous)
                .stroke(coral.opacity(0.12), lineWidth: 1)
                .padding(6)
        )
    }

    private var writeButton: some View {
        Button {
            Haptics.tap(); showFeedback = true
        } label: {
            Text("Write to CEO")
                .font(AppFont.body(17, weight: .bold))
                .foregroundStyle(AppTheme.onBrand)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(coral, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
        .background(.ultraThinMaterial)
    }
}

#Preview { CEOMessageScreen() }
