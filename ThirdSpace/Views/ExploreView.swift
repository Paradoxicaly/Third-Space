import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var environment: AppEnvironment
    var body: some View {
        ExploreContent(model: environment.explore)
    }
}

private struct ExploreContent: View {
    @ObservedObject var model: ExploreViewModel
    @EnvironmentObject private var environment: AppEnvironment
    @State private var showingFilters = false
    @FocusState private var searching: Bool
    @AccessibilityFocusState private var resultsFocused: Bool
    @State private var confirmsQueryReset = false
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: FieldGuide.Spacing.base) {
                    if environment.isSynthetic {
                        SyntheticBadge(text: "Synthetic demo · not verified places")
                    }
                    Text("Find somewhere you can spend time—and know what to expect before you go.")
                        .foregroundStyle(FieldGuide.Palette.secondary)
                    HStack(spacing: FieldGuide.Spacing.xs) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(FieldGuide.Palette.secondary)
                            .accessibilityHidden(true)
                        TextField("Search owned places", text: $model.query.text,
                                  prompt: Text("Search owned places").foregroundColor(FieldGuide.Palette.secondary))
                            .focused($searching).submitLabel(.search)
                            .onSubmit { searching = false }
                    }
                    .padding(.horizontal, 12).frame(minHeight: 48)
                    .background(FieldGuide.Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(FieldGuide.Palette.controlBorder, lineWidth: 1))
                    FlowLayout {
                        areaMenu
                        Button { showingFilters = true } label: {
                            FieldGuideChip(title: activeFilterCount == 0 ? "Filters" : "Filters · \(activeFilterCount)",
                                           systemImage: "line.3.horizontal.decrease", isSelected: activeFilterCount > 0)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Explore filters")
                        .accessibilityValue("\(activeFilterCount) active")
                        Button {
                            searching = false
                            proxy.scrollTo("place-results", anchor: .top)
                            resultsFocused = true
                        } label: {
                            FieldGuideChip(title: "List", systemImage: "list.bullet")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Show results as list")
                        .accessibilityHint("Results are listed below. Map exploration comes in a later milestone.")
                    }
                    FlowLayout {
                        ForEach(ExploreIntent.allCases, id: \.self) { intent in
                            let selected = model.query.intents.contains(intent)
                            Button {
                                if selected { model.query.intents.remove(intent) } else { model.query.intents.insert(intent) }
                            } label: {
                                FieldGuideChip(title: intent.label, systemImage: intent.icon, isSelected: selected)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(intent.label)
                            .accessibilityHint("Visit intent filter")
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    if let problem = model.queryRestorationProblem {
                        VStack(alignment: .leading, spacing: FieldGuide.Spacing.sm) {
                            Label("Stored search needs attention", systemImage: "exclamationmark.triangle")
                                .font(.headline).foregroundStyle(FieldGuide.Palette.warning)
                            Text(problem).foregroundStyle(FieldGuide.Palette.secondary)
                            Button("Retry stored search restoration") { model.retryStoredQueryRestoration() }.frame(minHeight: 44)
                            Button("Reset stored search") { confirmsQueryReset = true }.frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("query-restoration-problem")
                    }
                    VStack(alignment: .leading, spacing: FieldGuide.Spacing.xxs) {
                        Text("Results").font(.title2.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($resultsFocused)
                        Text("List foundation — map exploration is not connected yet.")
                            .font(.footnote).foregroundStyle(FieldGuide.Palette.secondary)
                    }
                    .padding(.top, FieldGuide.Spacing.xs)
                    .id("place-results")
                    PlaceResultsList(model: model)
                }
                .padding(FieldGuide.Spacing.base)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("explore-results-scroll")
            }
            .scrollDismissesKeyboard(.interactively)
            .background(FieldGuide.Palette.canvas)
            .navigationTitle("Explore")
            .sheet(isPresented: $showingFilters) { ExploreFiltersView(query: $model.query) }
            .alert("Reset stored search?", isPresented: $confirmsQueryReset) {
                Button("Cancel", role: .cancel) { }
                Button("Reset search", role: .destructive) { model.resetStoredQuery() }
            } message: {
                Text("This deliberately replaces only the stored search with worldwide defaults. Existing saves and drafts are not changed.")
            }
            .task(id: model.query.queryID) { await model.refresh() }
        }
    }

    private var activeFilterCount: Int { model.query.intents.count + model.query.requiredFacts.count }

    private var areaMenu: some View {
        Menu {
            Picker("Browse area", selection: $model.query.area) {
                Text("Worldwide").tag(ExploreArea.world)
                if environment.isSynthetic {
                    ForEach(Region.syntheticUITestFixtures) { region in
                        Text(region.names["en"] ?? region.id).tag(ExploreArea.region(region.id))
                    }
                    Text("SYNTHETIC Unmapped area").tag(ExploreArea.region("test-empty"))
                }
            }
        } label: {
            FieldGuideChip(title: areaName, systemImage: "globe", showsMenuIndicator: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Browse area")
        .accessibilityValue(areaName)
    }

    private var areaName: String {
        switch model.query.area {
        case .world: "Worldwide"
        case .region("test-empty"): "SYNTHETIC Unmapped area"
        case .region(let id): Region.syntheticUITestFixtures.first { $0.id == id }?.names["en"] ?? id
        case .bounds: "Selected map area"
        }
    }
}
