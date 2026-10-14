import SwiftUI

/// Moderator queue. Visible only after the backend confirms the moderator role; every action is
/// re-checked server-side (`moderate_place`, `resolve_report`), including the no-self-approval rule.
struct ModerationQueueView: View {
    @ObservedObject var community: CommunityStore
    @State private var pending: [SubmittedPlace] = []
    @State private var pendingPosts: [PlacePost] = []
    @State private var reports: [CommunityReport] = []
    @State private var error: String?
    @State private var rejecting: SubmittedPlace?
    @State private var note = ""

    var body: some View {
        List {
            Section("Pending places (\(pending.count))") {
                if pending.isEmpty { Text("Nothing waiting.").foregroundStyle(FieldGuide.Palette.secondary) }
                ForEach(pending) { place in
                    VStack(alignment: .leading, spacing: FieldGuide.Spacing.xs) {
                        Text(place.name).font(.headline)
                        Label(place.category.rawValue.capitalized, systemImage: place.category.icon).font(.subheadline)
                        if !place.description.isEmpty { Text(place.description) }
                        if let address = place.address { Label(address, systemImage: "mappin.and.ellipse").font(.subheadline) }
                        Text(String(format: "%.5f, %.5f · submitted %@", place.latitude, place.longitude, place.createdAt.formatted(date: .abbreviated, time: .shortened)))
                            .font(.footnote).foregroundStyle(FieldGuide.Palette.secondary)
                        HStack {
                            Button { Task { await decide(place, .approved, note: nil) } } label: {
                                Text("Approve").foregroundStyle(FieldGuide.Palette.onAction)
                            }
                                .buttonStyle(.borderedProminent).tint(FieldGuide.Palette.action).frame(minHeight: 44)
                                .accessibilityLabel("Approve \(place.name)")
                            Button("Reject", role: .destructive) { note = ""; rejecting = place }
                                .buttonStyle(.bordered).frame(minHeight: 44)
                                .accessibilityLabel("Reject \(place.name)")
                        }
                    }
                }
            }
            Section("Open reports (\(reports.count))") {
                if reports.isEmpty { Text("No open reports.").foregroundStyle(FieldGuide.Palette.secondary) }
                ForEach(reports) { report in
                    VStack(alignment: .leading, spacing: FieldGuide.Spacing.xs) {
                        Text("\(report.target.type.capitalized) · \(report.reason.label)").font(.headline)
                            .accessibilityIdentifier("report-\(report.target.type)")
                        if !report.details.isEmpty { Text(report.details) }
                        Text("Target \(report.target.id.uuidString.prefix(8)) · \(report.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.footnote).foregroundStyle(FieldGuide.Palette.secondary)
                        HStack {
                            if case .review = report.target {
                                Button { Task { await resolve(report, dismiss: false, hide: true) } } label: {
                                    Text("Hide review").foregroundStyle(FieldGuide.Palette.onAction)
                                }.buttonStyle(.borderedProminent).tint(FieldGuide.Palette.action)
                            } else if case .post = report.target {
                                Button { Task { await resolve(report, dismiss: false, hide: true) } } label: {
                                    Text("Hide post").foregroundStyle(FieldGuide.Palette.onAction)
                                }.buttonStyle(.borderedProminent).tint(FieldGuide.Palette.action)
                            } else {
                                Button { Task { await resolve(report, dismiss: false, hide: false) } } label: {
                                    Text("Mark resolved").foregroundStyle(FieldGuide.Palette.onAction)
                                }.buttonStyle(.borderedProminent).tint(FieldGuide.Palette.action)
                            }
                            Button("Dismiss") { Task { await resolve(report, dismiss: true, hide: false) } }.buttonStyle(.bordered)
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
            Section("Pending community posts (\(pendingPosts.count))") {
                if pendingPosts.isEmpty { Text("Nothing waiting.").foregroundStyle(FieldGuide.Palette.secondary) }
                ForEach(pendingPosts) { post in
                    VStack(alignment: .leading, spacing: FieldGuide.Spacing.xs) {
                        Label(post.kind.label, systemImage: post.kind.icon).font(.subheadline.weight(.semibold))
                        if let title = post.title { Text(title).font(.headline) }
                        Text(post.body)
                        Text("@\(post.author.username) · \(post.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.footnote).foregroundStyle(FieldGuide.Palette.secondary)
                        HStack {
                            Button { Task { await decide(post, .approved) } } label: { Text("Approve").foregroundStyle(FieldGuide.Palette.onAction) }
                                .buttonStyle(.borderedProminent).tint(FieldGuide.Palette.action)
                                .accessibilityLabel("Approve post \(post.title ?? post.kind.label)")
                            Button("Reject", role: .destructive) { Task { await decide(post, .rejected) } }
                                .buttonStyle(.bordered)
                                .accessibilityLabel("Reject post \(post.title ?? post.kind.label)")
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
            if let error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(FieldGuide.Palette.destructive) }
        }
        .navigationTitle("Moderation")
        .refreshable { await load() }
        .task { await load() }
        .alert("Reject \(rejecting?.name ?? "")?", isPresented: Binding(get: { rejecting != nil }, set: { if !$0 { rejecting = nil } })) {
            TextField("Reason shown to the submitter", text: $note)
            Button("Cancel", role: .cancel) { rejecting = nil }
            Button("Reject", role: .destructive) { if let place = rejecting { Task { await decide(place, .rejected, note: note) } } }
        }
    }

    private func load() async {
        do {
            pending = try await community.service.pendingSubmissions()
            pendingPosts = try await community.service.pendingPosts()
            reports = try await community.service.openReports()
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func decide(_ place: SubmittedPlace, _ decision: ModerationStatus, note: String?) async {
        do { try await community.service.moderate(placeID: place.id, decision: decision, note: note); rejecting = nil; await load() }
        catch { self.error = error.localizedDescription }
    }

    private func decide(_ post: PlacePost, _ decision: ModerationStatus) async {
        do { try await community.service.moderatePost(id: post.id, decision: decision, note: nil); await load() }
        catch { self.error = error.localizedDescription }
    }

    private func resolve(_ report: CommunityReport, dismiss: Bool, hide: Bool) async {
        do { try await community.service.resolveReport(report.id, dismiss: dismiss, hideReview: hide); await load() }
        catch { self.error = error.localizedDescription }
    }
}

/// Submission status as word + icon + colour, never colour alone.
struct ModerationStatusLabel: View {
    let status: ModerationStatus
    var body: some View {
        switch status {
        case .pending: Label("Pending review", systemImage: "clock").foregroundStyle(FieldGuide.Palette.warning)
        case .approved: Label("Approved", systemImage: "checkmark.circle").foregroundStyle(FieldGuide.Palette.action)
        case .rejected: Label("Not approved", systemImage: "xmark.circle").foregroundStyle(FieldGuide.Palette.destructive)
        }
    }
}
