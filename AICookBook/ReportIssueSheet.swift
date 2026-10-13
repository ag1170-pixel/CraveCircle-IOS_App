import SwiftUI

/// What a recipe report stores: the user's words, who sent them, and the recipe they were looking at.
enum RecipeReport {
    struct Payload: Codable, Equatable {
        var note: String
        var reporter: String?
        var reporterId: String?
        var recipe: Recipe
    }

    static func content(note: String, reporter: String?, reporterId: String?, recipe: Recipe) -> String {
        let payload = Payload(note: note, reporter: reporter, reporterId: reporterId, recipe: recipe)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(payload), let text = String(data: data, encoding: .utf8) {
            return text
        }
        return note
    }

    static func parse(_ content: String?) -> Payload? {
        guard let content, let data = content.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }
}

struct ReportIssueSheet: View {
    let recipe: Recipe
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var issueText = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if showSuccess {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.green)
                        Text("Report Sent")
                            .font(AppFont.display(24, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Thanks for letting us know. We'll review \"\(recipe.title)\" with the note you sent.")
                            .font(AppFont.body(16))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("What's wrong with this recipe?")
                                .font(AppFont.display(24, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)

                            Text("Did the AI mishear an ingredient? Did it miss a step from the video? Let us know below so we can fix it.")
                                .font(AppFont.body(16))
                                .foregroundStyle(AppTheme.textSecondary)

                            Text(recipe.title)
                                .font(AppFont.body(14, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)

                            TextEditor(text: $issueText)
                                .font(AppFont.body(16))
                                .padding(12)
                                .frame(height: 150)
                                .background(AppTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                                .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppTheme.hairline, lineWidth: 1))
                                .padding(.top, 8)

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(AppFont.body(14, weight: .medium))
                                    .foregroundStyle(.red)
                            }

                            Button {
                                submitReport()
                            } label: {
                                HStack {
                                    if isSubmitting {
                                        ProgressView().tint(.white)
                                    }
                                    Text("Submit Report")
                                        .font(AppFont.body(18, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(issueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.5) : AppTheme.brand)
                                .clipShape(Capsule())
                            }
                            .disabled(issueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                        }
                        .padding(24)
                    }
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !showSuccess {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .font(AppFont.body(16, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    private func submitReport() {
        let note = issueText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty, !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        let content = RecipeReport.content(
            note: note,
            reporter: environment.currentUser?.username,
            reporterId: environment.currentUser?.id,
            recipe: recipe
        )
        Task {
            do {
                try await environment.submitFeedback(
                    type: "recipe_report",
                    content: content,
                    handle: environment.currentUser?.username
                )
                await MainActor.run {
                    Haptics.success()
                    withAnimation(.spring()) { showSuccess = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { dismiss() }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Couldn't send the report. Check your connection and try again."
                    Haptics.warning()
                }
            }
        }
    }
}

struct AdminRecipeReportsScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var reports: [AdminFeedback] = []
    @State private var loaded = false
    @State private var loadError: String?

    var body: some View {
        List {
            if !loaded {
                ProgressView()
            } else if let loadError {
                ContentUnavailableView("Couldn't load reports",
                                       systemImage: "wifi.exclamationmark",
                                       description: Text(loadError))
            } else if reports.isEmpty {
                ContentUnavailableView("No recipe reports",
                                       systemImage: "exclamationmark.bubble",
                                       description: Text("When someone reports a recipe, their note and the recipe show up here."))
            } else {
                ForEach(reports) { row in
                    NavigationLink {
                        RecipeReportDetail(row: row)
                    } label: {
                        reportRow(row)
                    }
                }
            }
        }
        .navigationTitle("Recipe Reports")
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func reportRow(_ row: AdminFeedback) -> some View {
        let payload = RecipeReport.parse(row.content)
        return VStack(alignment: .leading, spacing: 4) {
            Text(payload?.recipe.title ?? "Recipe report")
                .font(AppFont.body(16, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(payload?.note ?? row.content ?? "")
                .font(AppFont.body(14))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
            Text([payload?.reporter ?? row.userHandle, row.createdAt].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                .font(AppFont.body(12))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(.vertical, 4)
    }

    private func reload() async {
        do {
            let rows = try await environment.fetchRecipeReports()
            await MainActor.run {
                reports = rows
                loadError = nil
                loaded = true
            }
        } catch {
            await MainActor.run {
                loadError = "Check the kitchen server, then pull to refresh."
                loaded = true
            }
        }
    }
}

struct RecipeReportDetail: View {
    let row: AdminFeedback
    @EnvironmentObject private var environment: AppEnvironment

    private var payload: RecipeReport.Payload? { RecipeReport.parse(row.content) }

    /// The live library copy when we already have it, otherwise the snapshot that was reported.
    private var recipe: Recipe? {
        guard let payload else { return nil }
        return environment.recipes.first { $0.id == payload.recipe.id } ?? payload.recipe
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let payload {
                    Text(payload.note)
                        .font(AppFont.body(17))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text([payload.reporter ?? row.userHandle, row.createdAt].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(AppFont.body(13))
                        .foregroundStyle(AppTheme.textSecondary)

                    if let recipe {
                        NavigationLink {
                            RecipeDetailScreen(recipe: recipe)
                        } label: {
                            Text("Open \(recipe.title)")
                                .font(AppFont.body(16, weight: .bold))
                                .foregroundStyle(AppTheme.onBrand)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppTheme.brand, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        if let source = recipe.sourceUrl, !source.isEmpty {
                            Text(source)
                                .font(AppFont.body(13))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Text("Ingredients")
                            .font(AppFont.body(13, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                        ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, group in
                            if let name = group.groupName, !name.isEmpty {
                                Text(name).font(AppFont.body(14, weight: .semibold))
                            }
                            ForEach(Array(group.items.enumerated()), id: \.offset) { _, item in
                                Text(item).font(AppFont.body(15))
                            }
                        }

                        Text("Steps")
                            .font(AppFont.body(13, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.top, 8)
                        ForEach(recipe.directions.sorted { $0.stepIndex < $1.stepIndex }, id: \.stepIndex) { step in
                            Text("\(step.stepIndex). \(step.text)")
                                .font(AppFont.body(15))
                        }
                    }
                } else {
                    Text(row.content ?? "")
                        .font(AppFont.body(16))
                }
            }
            .padding(20)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(payload?.recipe.title ?? "Report")
        .navigationBarTitleDisplayMode(.inline)
    }
}
