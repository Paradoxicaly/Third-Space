import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Color.thirdCoral.opacity(0.15))
                            Image(systemName: "person.fill")
                                .font(.title2)
                                .foregroundStyle(Color.thirdCoral)
                        }
                        .frame(width: 58, height: 58)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Welcome to Third Space")
                                .font(.headline)
                            Text("Your local community guide")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 5)
                }

                Section("Your activity") {
                    Label("Saved places", systemImage: "bookmark.fill")
                    Label("Your reviews", systemImage: "star.bubble.fill")
                    Label("Suggested places", systemImage: "plus.circle.fill")
                }

                Section("About") {
                    Label("How Third Space works", systemImage: "lightbulb.fill")
                    Label("Community guidelines", systemImage: "heart.text.square.fill")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.thirdCream)
            .navigationTitle("Profile")
        }
    }
}
