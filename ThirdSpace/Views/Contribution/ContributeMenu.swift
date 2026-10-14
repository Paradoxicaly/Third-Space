import SwiftUI

// M2 only: preserve a local draft. No remote submission or approval is implied.
struct ContributeMenu: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment
    var initialDraft: Submission? = nil
    @State private var draftID = UUID()
    @State private var kind: SubmissionKind = .newPlace
    @State private var language = "en"
    @State private var text = ""
    @State private var status = ""
    @State private var saving = false
    @State private var confirmClose = false
    private let kinds: [SubmissionKind] = [.newPlace, .fieldNote, .question, .update, .accessNote, .event]

    var body: some View {
        NavigationStack {
            Form {
                if let community = environment.community {
                    Section {
                        NavigationLink {
                            SubmitPlaceView(community: community, startingCenter: environment.map.viewport.flatMap {
                                GeoPoint(latitude: $0.centerLatitude, longitude: $0.centerLongitude)
                            })
                        } label: {
                            Label("Submit a new place for review", systemImage: "mappin.and.ellipse")
                        }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("submit-place-link")
                    } footer: {
                        Text("A moderator approves new places before they appear publicly.")
                    }
                }
                Section {
                    Text("Local draft only — not submitted or public.")
                        .foregroundStyle(FieldGuide.Palette.warning)
                    Picker("Contribution type", selection: $kind) {
                        ForEach(kinds, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    TextField("Draft title or notes", text: $text,
                              prompt: Text("Draft title or notes").foregroundColor(FieldGuide.Palette.secondary), axis: .vertical)
                        .lineLimit(3...8)
                        .accessibilityIdentifier("draft-text")
                }
                if !status.isEmpty { Text(status).accessibilityIdentifier("draft-status") }
            }
            .navigationTitle("Add or contribute")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { if text.isEmpty { dismiss() } else { confirmClose = true } }.frame(minHeight: 44) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Keep draft") {
                        saving = true
                        Task {
                            if await environment.keepDraft(id: draftID, kind: kind, text: text, language: language) { dismiss() }
                            else { status = "Could not save. Your text is kept in this form." }
                            saving = false
                        }
                    }
                    .disabled(saving || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .frame(minHeight: 44)
                }
            }
        }
        .interactiveDismissDisabled(!text.isEmpty)
        .confirmationDialog("Keep your local draft before closing?", isPresented: $confirmClose) {
            Button("Discard unsaved changes", role: .destructive) { dismiss() }
            Button("Continue editing", role: .cancel) {}
        }
        .task {
            do {
                let available = try await environment.drafts.all()
                if let draft = initialDraft ?? available.last { draftID = draft.id; kind = draft.kind; text = draft.body; language = draft.originalLanguage }
            } catch { status = "Could not read existing drafts. They have not been overwritten." }
        }
    }
}
