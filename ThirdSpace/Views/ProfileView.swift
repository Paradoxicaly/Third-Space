import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @AppStorage("appearance") private var appearance = "system"
    @State private var selectedDraft: Submission?
    @State private var showingAccount = false
    var body: some View {
        NavigationStack {
            List {
                if let community = environment.community {
                    CommunityAccountSection(community: community, showingAccount: $showingAccount)
                }
                Section("On this device") {
                    Label("Browse without signing in", systemImage: "person.crop.circle")
                    Text("Saved places and drafts stay on this device. Account sync and remote contributions are not connected in this prototype.")
                        .foregroundStyle(FieldGuide.Palette.secondary)
                }
                Section("Product status") {
                    Label("Public submissions not available", systemImage: "clock")
                    Label("No verified regions yet", systemImage: "map")
                }
                Section("Local drafts") {
                    if environment.localDrafts.isEmpty { Text("No local drafts yet") }
                    ForEach(environment.localDrafts) { draft in
                        Button { selectedDraft = draft } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Local draft · \(draft.kind.displayName)", systemImage: "pencil")
                                Text(draft.body).foregroundStyle(FieldGuide.Palette.primary)
                            }.frame(minHeight: 44)
                        }
                    }
                }
                Section("Appearance") {
                    Picker("Color appearance", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(FieldGuide.Palette.canvas)
            .navigationTitle("Profile")
            .task { await environment.restoreLocalState() }
            .sheet(item: $selectedDraft) { ContributeMenu(initialDraft: $0) }
            .sheet(isPresented: $showingAccount) { if let community = environment.community { AccountView(community: community) } }
        }
    }
}

/// Account, the member's submissions with moderation decisions, and the moderator queue entry point.
private struct CommunityAccountSection: View {
    @ObservedObject var community: CommunityStore
    @Binding var showingAccount: Bool

    var body: some View {
        Section("Account") {
            if let profile = community.profile {
                Label("@\(profile.username)", systemImage: "person.crop.circle.fill")
                    .accessibilityIdentifier("signed-in-username")
                if community.isModerator {
                    NavigationLink { ModerationQueueView(community: community) } label: {
                        Label("Moderation queue", systemImage: "checkmark.shield")
                    }
                    .accessibilityIdentifier("moderation-queue")
                }
                Button("Sign out") { Task { await community.signOut() } }.frame(minHeight: 44)
            } else {
                Text("Sign in to submit places, rate, review, like and follow.").foregroundStyle(FieldGuide.Palette.secondary)
                Button("Sign in or create account") { showingAccount = true }
                    .frame(minHeight: 44).accessibilityIdentifier("open-account")
            }
        }
        if community.isSignedIn {
            Section("My submissions") {
                if community.submissions.isEmpty { Text("No submissions yet.").foregroundStyle(FieldGuide.Palette.secondary) }
                ForEach(community.submissions) { submission in
                    VStack(alignment: .leading, spacing: FieldGuide.Spacing.xxs) {
                        Text(submission.name).font(.headline)
                        ModerationStatusLabel(status: submission.status)
                        if let note = submission.decisionNote, !note.isEmpty {
                            Text("Moderator note: \(note)").font(.footnote).foregroundStyle(FieldGuide.Palette.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("submission-\(submission.name)")
                }
            }
            .task(id: community.profile?.id) { await community.refreshSubmissions() }
        }
    }
}
