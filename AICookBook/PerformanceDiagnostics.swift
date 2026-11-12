//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: PerformanceDiagnostics.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Supporting utility and business logic for PerformanceDiagnostics.
//
// 2. ARCHITECTURAL ROLE:
//    Provides specialized helper functions, algorithms, or extensions for the CraveCircle ecosystem.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "PerformanceDiagnostics encapsulates focused domain logic and helper utilities used across the project."
//
// ==============================================================================
//

import SwiftUI

enum PerformanceDiagnostics {
    static let enabledKey = "performance_debug_enabled"

    struct Entry: Identifiable {
        let id = UUID()
        let name: String
        let milliseconds: Double
        let date: Date
    }

    struct Check: Identifiable, Sendable {
        let id = UUID()
        let name: String
        let detail: String
        let passed: Bool
    }

    private static let lock = NSLock()
    private static var entries: [Entry] = []

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    static func start() -> UInt64 {
        isEnabled ? DispatchTime.now().uptimeNanoseconds : 0
    }

    static func record(_ name: String, since start: UInt64) {
        guard start != 0, isEnabled else { return }
        let elapsed = DispatchTime.now().uptimeNanoseconds &- start
        lock.lock()
        entries.append(Entry(name: name, milliseconds: Double(elapsed) / 1_000_000, date: Date()))
        if entries.count > 40 { entries.removeFirst(entries.count - 40) }
        lock.unlock()
    }

    static func latest() -> [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    static func runChecks(recipes: [Recipe]) -> [Check] {
        guard !recipes.isEmpty else {
            return [Check(name: "Recipe data", detail: "Load recipes before running benchmarks.", passed: false)]
        }

        let queries = ["p", "pa", "pas", "past", "pasta", "pasta c"]
        let rounds = 4
        var searchHits = 0
        var lastImmediateIDs: [String] = []
        var start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<rounds {
            for query in queries {
                let matches = RecipeSearch.search(recipes, query: query, filters: RecipeFilters()).recipes
                if !matches.isEmpty {
                    searchHits += 1
                }
                if query == queries[queries.count - 1] { lastImmediateIDs = matches.map(\.id) }
            }
        }
        let immediateMS = elapsedMilliseconds(since: start)
        let immediateCalls = rounds * queries.count

        start = DispatchTime.now().uptimeNanoseconds
        var settledHits = 0
        var settledIDs: [String] = []
        for _ in 0..<rounds {
            let matches = RecipeSearch.search(recipes, query: queries.last!, filters: RecipeFilters()).recipes
            if !matches.isEmpty {
                settledHits += 1
            }
            settledIDs = matches.map(\.id)
        }
        let settledMS = elapsedMilliseconds(since: start)
        let searchPassed = searchHits == immediateCalls && settledHits == rounds && lastImmediateIDs == settledIDs
        let reduction = Int((1 - Double(rounds) / Double(immediateCalls)) * 100)
        let searchDetail = "\(immediateCalls) immediate vs \(rounds) settled searches (\(reduction)% fewer); \(format(immediateMS)) vs \(format(settledMS))"

        let history = recipes.prefix(10).map {
            AppEnvironment.InteractionEvent(id: UUID().uuidString, recipeId: $0.id,
                                            eventType: "cook", durationSeconds: nil, timestamp: Date())
        }
        start = DispatchTime.now().uptimeNanoseconds
        var suggestions: [Recipe] = []
        for _ in 0..<10 {
            suggestions = RecommendationEngine.suggestions(from: recipes, history: history,
                                                            excluding: [], limit: 8)
        }
        let feedMS = elapsedMilliseconds(since: start)
        let feedPassed = !suggestions.isEmpty && suggestions.count <= min(8, recipes.count)

        start = DispatchTime.now().uptimeNanoseconds
        let roundTrip = (try? JSONDecoder().decode([Recipe].self, from: JSONEncoder().encode(recipes)))
        let jsonMS = elapsedMilliseconds(since: start)
        let jsonPassed = roundTrip?.map(\.id) == recipes.map(\.id)

        return [
            Check(name: "Search debounce workload", detail: "\(searchDetail)", passed: searchPassed),
            Check(name: "Suggestion ranking", detail: "10 runs on \(recipes.count) recipes: \(format(feedMS)); \(suggestions.count) results", passed: feedPassed),
            Check(name: "Recipe JSON round-trip", detail: "\(recipes.count) recipes encoded and decoded in \(format(jsonMS))", passed: jsonPassed)
        ]
    }

    private static func elapsedMilliseconds(since start: UInt64) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds &- start) / 1_000_000
    }

    private static func format(_ milliseconds: Double) -> String {
        String(format: "%.1f ms", milliseconds)
    }
}

// MARK: - SwiftUI View Component
struct PerformanceHUD: View {
    @State private var expanded = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let entries = PerformanceDiagnostics.latest().suffix(8).reversed()
            VStack(alignment: .leading, spacing: 6) {
                Button { expanded.toggle() } label: {
                    HStack {
                        Text("PERF · \(PerformanceDiagnostics.latest().count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                if expanded {
                    ForEach(Array(entries)) { entry in
                        HStack(spacing: 8) {
                            Text(entry.name).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(String(format: "%.1f ms", entry.milliseconds))
                                .monospacedDigit()
                        }
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                    }
                }
            }
            .padding(9)
            .frame(maxWidth: 265, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(0.12)))
        }
        .padding(.top, 6)
        .padding(.trailing, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Performance timings")
    }
}

// MARK: - SwiftUI View Component
struct DeveloperToolsScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @AppStorage(PerformanceDiagnostics.enabledKey) private var performanceEnabled = false
    @State private var checks: [PerformanceDiagnostics.Check] = []
    @State private var running = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Toggle("Show performance timings", isOn: $performanceEnabled)
                    .font(AppFont.body(16, weight: .semibold))
                    .tint(AppTheme.accent)
                    .padding(AppSpacing.md)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))

                Text("When enabled, a floating panel shows recent startup, data, search, feed, and cover load times.")
                    .font(AppFont.body(13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, AppSpacing.xs)

                Button {
                    runChecks()
                } label: {
                    HStack {
                        if running { ProgressView().tint(AppTheme.onAccent) }
                        Text(running ? "Running checks…" : "Run all benchmarks")
                    }
                    .font(AppFont.body(16, weight: .bold))
                    .foregroundStyle(AppTheme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent, in: Capsule())
                }
                .disabled(running)

                ForEach(checks) { check in
                    VStack(alignment: .leading, spacing: 5) {
                        Label(check.name, systemImage: check.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(AppFont.body(15, weight: .semibold))
                            .foregroundStyle(check.passed ? .green : AppTheme.destructive)
                        Text(check.detail)
                            .font(AppFont.body(12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Developer Tools")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if performanceEnabled && checks.isEmpty { runChecks() }
        }
        .onChange(of: performanceEnabled) { _, enabled in
            if enabled { runChecks() }
        }
    }

    private func runChecks() {
        guard !running else { return }
        running = true
        let recipes = environment.recipes
        Task.detached(priority: .utility) {
            let results = PerformanceDiagnostics.runChecks(recipes: recipes)
            await MainActor.run {
                checks = results
                running = false
            }
        }
    }
}
