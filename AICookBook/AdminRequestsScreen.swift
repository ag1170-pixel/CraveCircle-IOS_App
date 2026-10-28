//
//  AdminRequestsScreen.swift
//  CraveCircle (AICookBook)
//
//  Admin-only queue of pending creator requests. Approve → the requester becomes a creator
//  (server-side via decide_creator_request); Reject → the request is closed. Gated by role == admin.
//

import SwiftUI

struct AdminRequestsScreen: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        List {
            if environment.pendingCreatorRequests.isEmpty {
                ContentUnavailableView("No pending requests",
                                       systemImage: "checkmark.seal",
                                       description: Text("New creator requests will appear here for review."))
            } else {
                ForEach(environment.pendingCreatorRequests) { req in
                    NavigationLink { CreatorRequestDetailView(request: req) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: platformIcon(req.socialPlatform))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(req.socialPlatform) · \(req.socialHandle)")
                                    .font(AppFont.body(15, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Tap to review")
                                    .font(AppFont.body(12))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Creator Requests")
        .task { await environment.loadPendingCreatorRequests() }
        .refreshable { await environment.loadPendingCreatorRequests() }
    }

    fileprivate static func platformIcon(_ platform: String) -> String {
        switch platform.lowercased() {
        case "youtube": return "play.rectangle.fill"
        case "tiktok":  return "music.note"
        case "facebook": return "person.2.fill"
        case "pinterest": return "pin.fill"
        default:        return "camera.fill"   // Instagram / other
        }
    }
    private func platformIcon(_ platform: String) -> String { Self.platformIcon(platform) }
}

/// Admin opens a request to see everything the applicant submitted (platform, handle, URL, note,
/// account id, time) so they can go verify the person on the actual network before approving.
/// Approve ⇒ role flips to creator. The blue-tick toggle grants verified in the same action.
private struct CreatorRequestDetailView: View {
    let request: CreatorRequest
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var grantVerified = false
    @State private var applicant: UserProfile?
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Applicant") {
                HStack(spacing: 12) {
                    CreatorAvatarView(handle: applicant?.username, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(applicant?.fullName ?? "—")
                            .font(AppFont.body(15, weight: .semibold))
                        Text(applicant?.username.map { "@\($0)" } ?? request.userId)
                            .font(AppFont.body(13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                row("Account id", value: request.userId, monospaced: true)
                if let bio = applicant?.bio, !bio.isEmpty {
                    row("Bio", value: bio)
                }
            }

            Section("Submitted") {
                row("Platform",  value: request.socialPlatform.capitalized)
                row("Handle",    value: request.socialHandle, monospaced: true)
                if let url = request.socialUrl, !url.isEmpty {
                    Link(destination: URL(string: url) ?? URL(string: "about:blank")!) {
                        HStack {
                            Image(systemName: "link")
                            Text("Open \(url)").lineLimit(1).truncationMode(.middle)
                        }
                        .font(AppFont.body(14, weight: .semibold))
                        .foregroundStyle(AppTheme.accentInk)
                    }
                }
                if let note = request.note, !note.isEmpty {
                    row("Note", value: note)
                }
                row("Requested", value: request.createdAt.formatted(date: .abbreviated, time: .shortened))
            }

            Section {
                Toggle(isOn: $grantVerified) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.blue)
                        Text("Grant blue tick").font(AppFont.body(15, weight: .semibold))
                    }
                }
            } footer: {
                Text("Toggle on if you've verified this person off-platform and want their profile to show a blue tick.")
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(AppTheme.destructive)
            }

            Section {
                Button {
                    decide(approve: true)
                } label: {
                    Label("Approve as creator", systemImage: "checkmark").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(.green).disabled(busy)

                Button(role: .destructive) {
                    decide(approve: false)
                } label: {
                    Label("Reject", systemImage: "xmark").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).disabled(busy)
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            applicant = await environment.fetchPublicProfileById(request.userId)
        }
    }

    private func row(_ label: String, value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(AppFont.body(12)).foregroundStyle(AppTheme.textTertiary)
            Text(value)
                .font(monospaced ? .system(.body, design: .monospaced) : AppFont.body(15))
                .foregroundStyle(AppTheme.textPrimary)
                .textSelection(.enabled)
        }
    }

    private func decide(approve: Bool) {
        busy = true; errorMessage = nil
        Haptics.select()
        Task {
            await environment.decideCreatorRequest(request, approve: approve)
            if approve, grantVerified {
                let ok = await environment.setUserVerified(userId: request.userId, verified: true)
                if !ok { await MainActor.run { errorMessage = "Approved, but couldn't set verified. Retry from Supabase if needed." } }
            }
            await MainActor.run {
                busy = false
                if errorMessage == nil { dismiss() }
            }
        }
    }
}

/// Dishes enough people searched for that we still do not have. Admin publishes those from this account.
struct AdminSearchDemandScreen: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        List {
            if environment.searchDemands.isEmpty {
                ContentUnavailableView(
                    "No dish has reached \(SearchDemand.peopleNeeded) people yet",
                    systemImage: "magnifyingglass",
                    description: Text("When enough people search for the same missing recipe, it shows up here.")
                )
            } else {
                ForEach(environment.searchDemands) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.queryKey)
                            .font(AppFont.body(16, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("\(row.askCount) people searched for this")
                            .font(AppFont.body(13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Recipes people want")
        .navigationBarTitleDisplayMode(.inline)
        .task { await environment.loadSearchDemands() }
        .refreshable { await environment.loadSearchDemands() }
    }
}
