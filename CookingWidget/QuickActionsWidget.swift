//
//  QuickActionsWidget.swift
//  CookingWidget
//
//  Home-screen widget with CraveCircle quick actions — one tap from the home screen to Import a
//  recipe, Write from scratch, open the Grocery list, or Search. Each tile deep-links into the app.
//  Warm brand look, adaptive to light/dark, coral accents.
//

import WidgetKit
import SwiftUI

private enum QA {
    static let coral = Color(red: 0xEA / 255, green: 0x5A / 255, blue: 0x38 / 255)
}

private struct QuickAction {
    let title: String
    let symbol: String
    let url: String
}

private let quickActions: [QuickAction] = [
    .init(title: "Import",  symbol: "square.and.arrow.down.fill", url: "cravecircle://add"),
    .init(title: "Write",   symbol: "square.and.pencil",          url: "cravecircle://new"),
    .init(title: "Grocery", symbol: "basket.fill",                url: "cravecircle://grocery"),
    .init(title: "Search",  symbol: "magnifyingglass",            url: "cravecircle://home"),
]

struct QuickActionsEntry: TimelineEntry { let date: Date }

struct QuickActionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickActionsEntry { .init(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (QuickActionsEntry) -> Void) {
        completion(.init(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickActionsEntry>) -> Void) {
        completion(Timeline(entries: [.init(date: .now)], policy: .never))   // static — never needs refresh
    }
}

struct QuickActionsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CraveCircleQuickActions", provider: QuickActionsProvider()) { _ in
            QuickActionsView()
                .containerBackground(for: .widget) { QuickActionsBackground() }
        }
        .configurationDisplayName("CraveCircle")
        .description("Import, cook, and shop in a tap.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct QuickActionsBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        (scheme == .dark ? Color(red: 0.086, green: 0.075, blue: 0.059)
                         : Color(red: 0.980, green: 0.972, blue: 0.953))
    }
}

struct QuickActionsView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme

    private var textColor: Color {
        scheme == .dark ? Color(red: 0.96, green: 0.95, blue: 0.925)
                        : Color(red: 0.106, green: 0.090, blue: 0.071)
    }

    var body: some View {
        if family == .systemSmall {
            // Small widget supports a single tap target → the primary action (Import).
            VStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(QA.coral)
                Text("Import a recipe")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetURL(URL(string: "cravecircle://add"))
        } else {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text("CraveCircle")
                        .font(.caption.weight(.bold)).foregroundStyle(textColor)
                    Spacer()
                }
                let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(quickActions, id: \.title) { action in
                        Link(destination: URL(string: action.url)!) { tile(action) }
                    }
                }
            }
        }
    }

    private func tile(_ action: QuickAction) -> some View {
        HStack(spacing: 8) {
            Image(systemName: action.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(QA.coral)
                .frame(width: 22)
            Text(action.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(textColor)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .background(QA.coral.opacity(scheme == .dark ? 0.16 : 0.10),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}
