import SwiftUI

struct BusinessProfileView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var name = ""
    @State private var type = "individual"
    @State private var verificationNotes: String?
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Adult / business profile", subtitle: "This writes the existing private adult_profiles contract. Public trust status still comes from verification review.")
                MortTextField(title: "Account or business name", text: $name, prompt: "Name associated with job posts")
                Picker("Account type", selection: $type) {
                    Text("Individual adult").tag("individual")
                    Text("Business").tag("business")
                    Text("Nonprofit").tag("nonprofit")
                }
                .pickerStyle(.menu)
                if let verificationNotes, !verificationNotes.trimmed.isEmpty {
                    MortAlertBanner(title: "Verification note", message: verificationNotes, tint: MortColors.safetyBlue, icon: "checkmark.shield.fill")
                }
                MortPrimaryButton(title: "Save adult profile", icon: "checkmark", isLoading: isWorking) { Task { await save() } }
                MortSafetyBanner(message: "A business name is not proof of identity, licensing, insurance, background checks, or safety. Use the separate verification flow where appropriate.")
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Business profile")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Adult profile", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        do {
            guard let profile = try await container.profiles.adultBusinessProfile() else { return }
            name = profile.businessName ?? ""
            type = profile.businessType ?? "individual"
            verificationNotes = profile.verificationNotes
        } catch { message = mortMessage(error) }
    }

    private func save() async {
        isWorking = true
        defer { isWorking = false }
        do { try await container.profiles.saveAdultBusinessProfile(name: name, type: type); message = "Adult / business profile saved." }
        catch { message = mortMessage(error) }
    }
}

struct EmergencyContactView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var name = ""
    @State private var phone = ""
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Emergency contact", subtitle: "Stored in your private guardian_profiles row and readable only under backend policy.")
                MortTextField(title: "Contact name", text: $name, prompt: "Trusted contact", textContentType: .name)
                MortTextField(title: "Phone number", text: $phone, prompt: "Phone number", keyboardType: .phonePad, textContentType: .telephoneNumber)
                MortPrimaryButton(title: "Save emergency contact", icon: "checkmark", isLoading: isWorking) { Task { await save() } }
                MortSafetyBanner(message: "MORT does not automatically call this person or emergency services. Keep this information current and use local emergency services for immediate danger.")
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Emergency contact")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Emergency contact", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        do {
            guard let contact = try await container.guardians.emergencyContact() else { return }
            name = contact.name ?? ""
            phone = contact.phone ?? ""
        } catch { message = mortMessage(error) }
    }

    private func save() async {
        isWorking = true
        defer { isWorking = false }
        do { try await container.guardians.saveEmergencyContact(name: name, phone: phone); message = "Emergency contact saved." }
        catch { message = mortMessage(error) }
    }
}
