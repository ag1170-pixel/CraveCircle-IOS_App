//
//  QuickActionsWidget.swift
//  CookingWidget
//
//  Home-screen widget — Swiggy-style: search bar on top, three bubbly category icons below.
//  Each icon deep-links into the app. Uses brand art when available, SF Symbol fallback until then.
//

import WidgetKit
import SwiftUI

// MARK: - Brand tokens

private enum QA {
    static let coral  = Color(red: 0xEA / 255, green: 0x5A / 255, blue: 0x38 / 255)
    static let cream  = Color(red: 0.980, green: 0.972, blue: 0.953)
    static let dark   = Color(red: 0.086, green: 0.075, blue: 0.059)
}

private struct QuickAction {
    let title: String
    let symbol: String      // SF Symbol fallback
    let asset: String?      // Gemini 3D art asset name (nil = use SF Symbol)
    let url: String
}

private let quickActions: [QuickAction] = [
    .init(title: "Import",  symbol: "arrow.down.circle.fill", asset: "widget-import",  url: "cravecircle://add"),
    .init(title: "Write",   symbol: "square.and.pencil",      asset: "widget-write",   url: "cravecircle://new"),
    .init(title: "Grocery", symbol: "basket.fill",            asset: "widget-grocery", url: "cravecircle://grocery"),
]

// MARK: - Timeline (static — never needs refresh)

struct QuickActionsEntry: TimelineEntry { let date: Date }

struct QuickActionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickActionsEntry { .init(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (QuickActionsEntry) -> Void) {
        completion(.init(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickActionsEntry>) -> Void) {
        completion(Timeline(entries: [.init(date: .now)], policy: .never))
    }
}

// MARK: - Widget

struct QuickActionsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CraveCircleQuickActions", provider: QuickActionsProvider()) { _ in
            QuickActionsView()
                .containerBackground(for: .widget) { QuickActionsBackground() }
        }
        .configurationDisplayName("CraveCircle")
        .description("Import, cook, and shop in a tap.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Background

private struct QuickActionsBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        (scheme == .dark ? QA.dark : QA.cream)
    }
}

// MARK: - Main view (Swiggy-style)

struct QuickActionsView: View {
    @Environment(\.colorScheme) private var scheme

    private var textColor: Color {
        scheme == .dark ? QA.cream : QA.dark
    }
    private var searchBarBg: Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
    }
    private var tileBg: Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
    }

    var body: some View {
        VStack(spacing: 10) {
            // ── Search bar ──
            Link(destination: URL(string: "cravecircle://home")!) {
                HStack(spacing: 8) {
                    // Brand bowl glyph (di-brand lives in THIS widget's catalog — the app's
                    // CraveCircleLogo asset isn't visible to the widget bundle).
                    Image("di-brand")
                        .resizable().scaledToFit()
                        .frame(width: 24, height: 24)

                    Text("Search CraveCircle")
                        .font(.subheadline)
                        .foregroundStyle(textColor.opacity(0.5))

                    Spacer(minLength: 0)

                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(textColor.opacity(0.45))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(searchBarBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // ── Category icons row ──
            HStack(spacing: 0) {
                ForEach(quickActions, id: \.title) { action in
                    Link(destination: URL(string: action.url)!) {
                        categoryTile(action)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func categoryTile(_ action: QuickAction) -> some View {
        VStack(spacing: 6) {
            // ponytail: uses the Gemini 3D art if present in the asset catalog,
            // otherwise falls back to a coral-tinted SF Symbol in a bubbly circle.
            ZStack {
                Circle()
                    .fill(tileBg)
                    .frame(width: 58, height: 58)

                if let asset = action.asset, UIImage(named: asset) != nil {
                    Image(asset)
                        .resizable().scaledToFit()
                        .frame(width: 46, height: 46)
                } else {
                    Image(systemName: action.symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(QA.coral)
                }
            }

            Text(action.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(textColor)
                .lineLimit(1)
        }
    }
}
