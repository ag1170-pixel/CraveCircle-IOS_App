//
//  AdminSignalsScreen.swift
//  CraveCircle (AICookBook)
//
//  Admin-only "Signals" page — three ranked lists so you can see what the audience actually
//  responds to: most liked, most saved, most viewed recipes. Backed by the server RPC
//  `admin_signals(top_n)` which runs as SECURITY DEFINER + role check so a non-admin PostgREST
//  call raises instead of leaking aggregates.
//

import SwiftUI

struct AdminSignalRow: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let thumbnailUrl: String
    let ownerUsername: String
    let n: Int
}

struct AdminSignals: Decodable {
    let topLiked: [AdminSignalRow]
    let topSaved: [AdminSignalRow]
    let topViewed: [AdminSignalRow]
    let generatedAt: Date?
}

struct AdminSignalsScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var signals: AdminSignals?
    @State private var loading = true

    var body: some View {
        List {
            if loading {
                Section { ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20) }
            } else if let s = signals {
                section(title: "Most liked",  rows: s.topLiked,  tint: Color.pink)
                section(title: "Most saved",  rows: s.topSaved,  tint: Color.orange)
                section(title: "Most viewed", rows: s.topViewed, tint: Color.blue)
                if let at = s.generatedAt {
                    Section {
                        Text("As of \(at.formatted(date: .abbreviated, time: .shortened))")
                            .font(AppFont.body(12))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
            } else {
                ContentUnavailableView("No signals yet",
                                       systemImage: "chart.bar",
                                       description: Text("Likes, saves and views will show up here once your users start interacting."))
            }
        }
        .navigationTitle("Signals")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        signals = await environment.loadAdminSignals()
        loading = false
    }

    @ViewBuilder
    private func section(title: String, rows: [AdminSignalRow], tint: Color) -> some View {
        Section(title) {
            if rows.isEmpty {
                Text("Nothing yet").font(AppFont.body(13)).foregroundStyle(AppTheme.textTertiary)
            } else {
                ForEach(rows) { row in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.accentSoft)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "fork.knife")
                                    .foregroundStyle(AppTheme.accentInk)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title).font(AppFont.body(14, weight: .semibold)).lineLimit(2)
                            if !row.ownerUsername.isEmpty {
                                Text("@\(row.ownerUsername.replacingOccurrences(of: "@", with: ""))")
                                    .font(AppFont.body(12)).foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        Spacer(minLength: 4)
                        Text("\(row.n)")
                            .font(AppFont.body(14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(tint, in: Capsule())
                    }
                }
            }
        }
    }
}
