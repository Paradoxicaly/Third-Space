import SwiftUI

/// Start a thread about an approved place. Every thread is held for moderator review.
struct NewThreadView: View {
    @ObservedObject var community: CommunityStore
    let onPosted: () async -> Void
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var results: [Place] = []
    @State private var moreResults = false
    @State private var place: Place?
    @State private var kind: CommunityPostKind = .question
    @State private var title = ""
    @State private var text = ""
    @State private var working = false
    @State private var error: String?
    @State private var showingAccount = false

    private var canPost: Bool {
        place != nil && !working && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (kind != .question || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                if !community.isSignedIn {
                    Section {
                        Text("Sign in to start a thread. You can still read every thread without an account.")
                        Button("Sign in") { showingAccount = true }.frame(minHeight: 44)
                    }
                }
                Section {
                    if let place {
                        HStack {
                            Label(place.name, systemImage: "mappin.and.ellipse")
                            Spacer()
                            Button("Change") { self.place = nil }.frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("thread-chosen-place")
                    } else {
                        TextField("Search places by name", text: $search)
                            .accessibilityIdentifier("thread-place-search")
                        ForEach(results) { result in
                            Button { place = result } label: {
                                Label(result.name, systemImage: "mappin").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }
                            .accessibilityLabel("Choose \(result.name)")
                        }
                        if moreResults {
                            Text("Keep typing to narrow the list.").font(.footnote).foregroundStyle(FieldGuide.Palette.secondary)
                        }
                    }
                } header: { Text("Place") } footer: { Text("Threads are always about a listed place.") }

                Section("Type") {
                    Picker("Thread type", selection: $kind) {
                        ForEach(CommunityPostKind.rootCases) { Label($0.label, systemImage: $0.icon).tag($0) }
                    }
                    .accessibilityIdentifier("thread-kind")
                }

                Section {
                    if kind == .question {
                        TextField("Question", text: $title)
                            .accessibilityIdentifier("thread-title")
                    }
                    TextField(kind == .question ? "Add context" : "What should people know?", text: $text, axis: .vertical)
                        .lineLimit(3...10)
                        .accessibilityIdentifier("thread-body")
                } footer: {
                    Text("A moderator checks every thread before it’s public. Don’t include anyone’s personal details.")
                }
                if let error {
                    Text(error).foregroundStyle(FieldGuide.Palette.destructive)
                }
            }
            .navigationTitle("New thread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { Task { await post() } }
                        .disabled(!canPost || !community.isSignedIn)
                        .accessibilityIdentifier("thread-post")
                }
            }
            .task(id: search) { await find() }
            .sheet(isPresented: $showingAccount) { AccountView(community: community) }
        }
    }

    private func find() async {
        do {
            let page = try await environment.repository.searchPlaces(ExploreQuery(text: search.trimmingCharacters(in: .whitespaces)), cursor: nil, generation: 0)
            results = page.places
            moreResults = page.nextCursor != nil
        } catch {
            results = []; moreResults = false
        }
    }

    private func post() async {
        guard let place else { return }
        working = true
        defer { working = false }
        do {
            try await community.service.addPost(placeID: place.id, kind: kind, title: kind == .question ? title : nil, body: text, parentID: nil)
            await onPosted()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
