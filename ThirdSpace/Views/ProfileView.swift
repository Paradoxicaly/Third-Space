import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @AppStorage("appearance") private var appearance = "system"
    @State private var selectedDraft: Submission?
    var body: some View {
        NavigationStack {
            List {
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
        }
    }
}
