import PhotosUI
import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router
    @State private var avatarURL: URL?
    @State private var showingEditor = false

    var body: some View {
        ScrollView {
            if let profile = session.profile {
                VStack(alignment: .leading, spacing: MortSpacing.lg) {
                    HStack(spacing: MortSpacing.lg) {
                        Button { router.push(.avatar) } label: {
                            MortAvatar(displayName: profile.name, url: avatarURL, size: 88)
                        }
                        .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: MortSpacing.xs) {
                            Text(profile.name).font(MortTypography.title)
                            if let username = profile.username { Text("@\(username)").foregroundStyle(MortColors.textMuted) }
                            HStack {
                                MortBadge(text: profile.role?.title ?? "Member", tint: MortColors.safetyBlue)
                                MortBadge(text: profile.verificationStatus, tint: statusTint(profile.verificationStatus))
                            }
                        }
                    }
                    ProgressView(value: profile.completionRatio).tint(MortColors.neon)
                    Text("Profile \(Int(profile.completionRatio * 100))% complete")
                        .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                    profileSection("About", profile.bio ?? "No bio added yet.")
                    profileSection("Availability", profile.availability ?? "Not set")
                    profileSection("Approximate area", profile.approximateArea ?? [profile.city, profile.state].compactMap { $0 }.joined(separator: ", "))
                    profileSection("Preferred categories", profile.preferredJobCategories.isEmpty ? "Not set" : profile.preferredJobCategories.joined(separator: ", "))
                    HStack(spacing: MortSpacing.sm) {
                        MortSecondaryButton(title: "Edit profile", icon: "pencil") { showingEditor = true }
                        MortSecondaryButton(title: "Reviews", icon: "star.fill") { router.push(.reviews) }
                    }
                }
                .padding(MortSpacing.lg)
            } else {
                MortErrorState(message: "Your profile is not available.") { Task { await session.refreshProfile() } }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditor) { ProfileEditorView() }
        .task { await loadAvatar() }
        .mortScreen()
    }

    private func profileSection(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: MortSpacing.xs) {
            MortSectionHeader(title: title)
            Text(value).foregroundStyle(MortColors.textMuted)
        }
    }

    private func loadAvatar() async {
        guard let profile = session.profile else { return }
        do { avatarURL = try await container.storage.signedAvatarURL(profileID: profile.id, path: profile.avatarPath) }
        catch { avatarURL = nil }
    }
}

private struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @State private var displayName = ""
    @State private var bio = ""
    @State private var availability = ""
    @State private var area = ""
    @State private var goals = ""
    @State private var categories = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MortSpacing.lg) {
                    MortTextField(title: "Display name", text: $displayName, prompt: "Name shown in MORT", textContentType: .name)
                    MortTextField(title: "Bio", text: $bio, prompt: "A short introduction", axis: .vertical)
                    MortTextField(title: "Availability", text: $availability, prompt: "Weekends, evenings", axis: .vertical)
                    MortTextField(title: "Approximate area", text: $area, prompt: "General area only")
                    MortTextField(title: "Preferred categories", text: $categories, prompt: "cleaning, pet care, tutoring")
                    MortTextField(title: "Goals", text: $goals, prompt: "What you want to accomplish", axis: .vertical)
                    MortPrimaryButton(title: "Save profile", icon: "checkmark", isLoading: isWorking) { Task { await save() } }
                }
                .padding(MortSpacing.lg)
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .alert("Profile not saved", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .onAppear { hydrate() }
            .mortScreen()
        }
    }

    private func hydrate() {
        guard let profile = session.profile else { return }
        displayName = profile.displayName ?? ""
        bio = profile.bio ?? ""
        availability = profile.availability ?? ""
        area = profile.approximateArea ?? ""
        goals = profile.goals ?? ""
        categories = profile.preferredJobCategories.joined(separator: ", ")
    }

    private func save() async {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await container.profiles.saveDetails(ProfileDetailsUpdate(
                displayName: displayName.trimmed,
                bio: bio.nilIfBlank,
                availability: availability.nilIfBlank,
                preferredJobCategories: categories.split(separator: ",").map { String($0).trimmed.lowercased() }.filter { !$0.isEmpty }.prefix(12).map { $0 },
                approximateArea: area.nilIfBlank,
                goals: goals.nilIfBlank
            ))
            await session.refreshProfile()
            dismiss()
        } catch { errorMessage = mortMessage(error) }
    }
}

struct AvatarEditorView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @State private var selectedItem: PhotosPickerItem?
    @State private var sourceData: Data?
    @State private var cropSelection: AvatarCropSelection?
    @State private var pendingCameraData: Data?
    @State private var currentURL: URL?
    @State private var showingCamera = false
    @State private var cameraUnavailable = false
    @State private var confirmRemove = false
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(spacing: MortSpacing.lg) {
                if let sourceData, let image = UIImage(data: sourceData) {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: 180, height: 180).clipShape(Circle())
                } else {
                    MortAvatar(displayName: session.profile?.name ?? "MORT member", url: currentURL, size: 180)
                }
                HStack(spacing: MortSpacing.sm) {
                    PhotosPicker(selection: $selectedItem, matching: .images) { Label("Library", systemImage: "photo.on.rectangle") }
                        .buttonStyle(.bordered).tint(MortColors.neon)
                    Button {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) { showingCamera = true }
                        else { cameraUnavailable = true }
                    } label: { Label("Camera", systemImage: "camera.fill") }
                        .buttonStyle(.bordered).tint(MortColors.safetyBlue)
                }
                if sourceData != nil {
                    MortPrimaryButton(title: "Upload avatar", icon: "arrow.up.circle.fill", isLoading: isWorking) { Task { await upload() } }
                }
                if session.profile?.avatarPath != nil {
                    MortDangerButton(title: "Remove current photo") { confirmRemove = true }
                }
                MortSafetyBanner(message: "Choose the crop before upload. MORT downsizes and re-encodes the image to remove metadata, then stores it privately. Do not upload IDs or sensitive documents as an avatar.")
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Profile photo")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItem) { _, item in guard let item else { return }; Task { await load(item) } }
        .fullScreenCover(isPresented: $showingCamera, onDismiss: {
            guard let data = pendingCameraData else { return }
            pendingCameraData = nil
            presentCrop(for: data)
        }) {
            CameraPicker(
                purpose: .avatar,
                onImageData: { data in
                    pendingCameraData = data
                    showingCamera = false
                },
                onCancel: { showingCamera = false },
                onError: { error in
                    message = mortMessage(error)
                    showingCamera = false
                }
            )
                .ignoresSafeArea()
        }
        .fullScreenCover(item: $cropSelection) { selection in
            AvatarCropView(image: selection.image) { data in
                sourceData = data
                cropSelection = nil
            } onCancel: {
                cropSelection = nil
            }
        }
        .confirmationDialog("Remove profile photo?", isPresented: $confirmRemove) {
            Button("Remove", role: .destructive) { Task { await remove() } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("MORT", isPresented: Binding(get: { message != nil || cameraUnavailable }, set: { if !$0 { message = nil; cameraUnavailable = false } })) {
            Button("OK", role: .cancel) { message = nil; cameraUnavailable = false }
        } message: { Text(message ?? "Camera is unavailable on this device. Use Photo Library.") }
        .task { await refreshURL() }
        .mortScreen()
    }

    private func load(_ item: PhotosPickerItem) async {
        defer { selectedItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw MortError.invalidInput("That image could not be loaded.") }
            presentCrop(for: data)
        } catch { message = mortMessage(error) }
    }

    private func presentCrop(for data: Data) {
        do {
            cropSelection = AvatarCropSelection(image: try ImageProcessingService.decodeSource(data, purpose: .avatar))
        } catch {
            message = mortMessage(error)
        }
    }

    private func upload() async {
        guard let sourceData else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let image = try ImageProcessingService.prepare(sourceData, purpose: .avatar)
            _ = try await container.storage.uploadAvatar(image, replacing: session.profile?.avatarPath)
            self.sourceData = nil
            await session.refreshProfile()
            await refreshURL()
            message = "Profile photo updated."
        } catch { message = mortMessage(error) }
    }

    private func remove() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await container.storage.removeAvatar(path: session.profile?.avatarPath)
            await session.refreshProfile()
            currentURL = nil
            message = "Profile photo removed."
        } catch { message = mortMessage(error) }
    }

    private func refreshURL() async {
        guard let profile = session.profile else { return }
        do { currentURL = try await container.storage.signedAvatarURL(profileID: profile.id, path: profile.avatarPath) }
        catch { currentURL = nil }
    }
}

private struct AvatarCropSelection: Identifiable {
    let id = UUID()
    let image: UIImage
}
