import SwiftUI

struct ExploreFiltersView: View {
    @Binding var query: ExploreQuery
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Visit intent — match any selected") {
                    ForEach(ExploreIntent.allCases, id: \.self) { intent in
                        Toggle(intent.rawValue.capitalized, isOn: Binding(
                            get: { query.intents.contains(intent) },
                            set: { if $0 { query.intents.insert(intent) } else { query.intents.remove(intent) } }
                        ))
                    }
                }
                Section("Practical facts — match all selected") {
                    ForEach([FactKey.wifi, .outlets, .stepFreeEntrance, .accessibleToilet], id: \.self) { key in
                        Toggle(key.label, isOn: Binding(
                            get: { query.requiredFacts.contains(key) },
                            set: { if $0 { query.requiredFacts.insert(key) } else { query.requiredFacts.remove(key) } }
                        ))
                    }
                    Toggle("Include unknown facts", isOn: $query.includeUnknown)
                    Text("Unknown is not a positive access claim. Check dated details before visiting.")
                        .foregroundStyle(FieldGuide.Palette.secondary)
                }
                Button("Clear filters") { query.intents = []; query.requiredFacts = []; query.includeUnknown = false }
            }
            .navigationTitle("Explore filters")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.frame(minHeight: 44) } }
        }
        .tint(FieldGuide.Palette.action)
    }
}
