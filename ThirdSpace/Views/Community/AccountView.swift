import SwiftUI

/// Email + password sign-in / sign-up. Usernames are public; emails are never shown to other members.
struct AccountView: View {
    @ObservedObject var community: CommunityStore
    @Environment(\.dismiss) private var dismiss
    @State private var creating = false
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var working = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Account", selection: $creating) {
                    Text("Sign in").tag(false)
                    Text("Create account").tag(true)
                }
                .pickerStyle(.segmented)
                Section {
                    if creating {
                        TextField("Username", text: $username, prompt: Text("Username (shown publicly)").foregroundColor(FieldGuide.Palette.secondary))
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .accessibilityIdentifier("account-username")
                    }
                    TextField("Email", text: $email, prompt: Text("Email").foregroundColor(FieldGuide.Palette.secondary))
                        .keyboardType(.emailAddress).textContentType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("account-email")
                    SecureField("Password", text: $password, prompt: Text("Password (6+ characters)").foregroundColor(FieldGuide.Palette.secondary))
                        .textContentType(creating ? .newPassword : .password)
                        .accessibilityIdentifier("account-password")
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(FieldGuide.Palette.destructive)
                        .accessibilityIdentifier("account-error")
                }
                Button {
                    Task { await submit() }
                } label: {
                    Text(working ? "Working…" : creating ? "Create account" : "Sign in")
                }
                .buttonStyle(FieldGuideActionStyle())
                .disabled(working || email.isEmpty || password.isEmpty || (creating && username.isEmpty))
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("account-submit")
                #if DEBUG
                if community.isTestBackend {
                    Section("Synthetic test accounts") {
                        Button("Use test moderator") { Task { await community.useTestAccount(email: InMemoryCommunityService.moderatorEmail); dismiss() } }
                            .frame(minHeight: 44)
                        Button("Use test neighbour") { Task { await community.useTestAccount(email: InMemoryCommunityService.neighborEmail); dismiss() } }
                            .frame(minHeight: 44)
                    }
                }
                #endif
            }
            .navigationTitle(creating ? "Create account" : "Sign in")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.frame(minHeight: 44) } }
        }
        .tint(FieldGuide.Palette.action)
    }

    private func submit() async {
        working = true; error = nil
        community.message = nil
        let ok = creating
            ? await community.signUp(email: email.trimmingCharacters(in: .whitespaces), password: password, username: username.trimmingCharacters(in: .whitespaces))
            : await community.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
        working = false
        if ok { dismiss() } else { error = community.message ?? "Something went wrong. Try again." }
    }
}
