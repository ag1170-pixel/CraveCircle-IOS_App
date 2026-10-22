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
    @State private var busyId: String?

    var body: some View {
        List {
            if environment.pendingCreatorRequests.isEmpty {
                ContentUnavailableView("No pending requests",
                                       systemImage: "checkmark.seal",
                                       description: Text("New creator requests will appear here for review."))
            } else {
                ForEach(environment.pendingCreatorRequests) { req in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: platformIcon(req.socialPlatform))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(req.socialPlatform) · \(req.socialHandle)")
                                    .font(AppFont.body(15, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                if let u = req.socialUrl, !u.isEmpty {
                                    Text(u).font(AppFont.body(12)).foregroundStyle(AppTheme.textSecondary).lineLimit(1)
                                }
                            }
                        }
                        HStack(spacing: 10) {
                            Button {
                                decide(req, approve: true)
                            } label: {
                                Label("Approve", systemImage: "checkmark").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent).tint(.green)

                            Button(role: .destructive) {
                                decide(req, approve: false)
                            } label: {
                                Label("Reject", systemImage: "xmark").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .disabled(busyId == req.id)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Creator Requests")
        .task { await environment.loadPendingCreatorRequests() }
        .refreshable { await environment.loadPendingCreatorRequests() }
    }

    private func decide(_ req: CreatorRequest, approve: Bool) {
        busyId = req.id
        Haptics.select()
        Task {
            await environment.decideCreatorRequest(req, approve: approve)
            await MainActor.run { busyId = nil }
        }
    }

    private func platformIcon(_ platform: String) -> String {
        switch platform.lowercased() {
        case "youtube": return "play.rectangle.fill"
        case "tiktok":  return "music.note"
        case "facebook": return "person.2.fill"
        default:        return "camera.fill"   // Instagram / other
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
