import PhotosUI
import SwiftUI
import UIKit

struct ProofUploadView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var selectedItem: PhotosPickerItem?
    @State private var sourceData: Data?
    @State private var note = ""
    @State private var showingCamera = false
    @State private var isUploading = false
    @State private var uploadStage = ""
    @State private var errorMessage: String?
    @State private var cameraUnavailable = false
    let applicationID: UUID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Submit work proof", subtitle: "Use one clear image that shows the completed result without exposing private information.")
                preview
                HStack(spacing: MortSpacing.sm) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Photo library", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.bordered)
                    .tint(MortColors.neon)
                    Button {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) { showingCamera = true }
                        else { cameraUnavailable = true }
                    } label: { Label("Camera", systemImage: "camera.fill") }
                    .buttonStyle(.bordered)
                    .tint(MortColors.safetyBlue)
                }
                MortTextField(title: "Note (optional)", text: $note, prompt: "What the image shows", axis: .vertical)
                MortSafetyBanner(message: "Do not include faces, IDs, school details, exact addresses, access codes, or unrelated personal information in proof.")
                if isUploading {
                    VStack(alignment: .leading, spacing: MortSpacing.xs) {
                        ProgressView().tint(MortColors.neon)
                        Text(uploadStage).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                    }
                }
                MortPrimaryButton(title: "Submit proof", icon: "arrow.up.doc.fill", isLoading: isUploading, isDisabled: sourceData == nil) {
                    Task { await upload() }
                }
                Text("Submitting creates a private storage object and then calls submit_application_proof. If the database step fails, MORT attempts to remove the orphan upload.")
                    .font(MortTypography.caption)
                    .foregroundStyle(MortColors.textMuted)
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Proof")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker(
                purpose: .proof,
                onImageData: { data in
                    sourceData = data
                    showingCamera = false
                },
                onCancel: { showingCamera = false },
                onError: { error in
                    errorMessage = mortMessage(error)
                    showingCamera = false
                }
            )
                .ignoresSafeArea()
        }
        .alert("Camera unavailable", isPresented: $cameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: { Text("Use Photo Library on this device.") }
        .alert("Proof not submitted", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .mortScreen()
    }

    @ViewBuilder
    private var preview: some View {
        if let sourceData, let image = UIImage(data: sourceData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 360)
                .background(MortColors.card)
                .clipShape(RoundedRectangle(cornerRadius: MortRadius.medium))
                .overlay(alignment: .topTrailing) {
                    Button { self.sourceData = nil; selectedItem = nil } label: {
                        Image(systemName: "xmark.circle.fill").font(.title).symbolRenderingMode(.palette).foregroundStyle(.white, MortColors.danger)
                    }
                    .padding(MortSpacing.sm)
                    .accessibilityLabel("Remove selected proof image")
                }
        } else {
            MortEmptyState(title: "Choose proof", message: "Take a new photo or select one from your library.", systemImage: "photo.badge.plus")
                .frame(minHeight: 220)
        }
    }

    private func load(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw MortError.invalidInput("That image could not be loaded.")
            }
            sourceData = data
        } catch { errorMessage = mortMessage(error) }
    }

    private func upload() async {
        guard let sourceData else { return }
        isUploading = true
        defer { isUploading = false; uploadStage = "" }
        do {
            uploadStage = "Preparing image and removing metadata..."
            let prepared = try ImageProcessingService.prepare(sourceData, purpose: .proof)
            uploadStage = "Uploading to private storage and verifying submission..."
            _ = try await container.storage.uploadProof(
                applicationID: applicationID,
                submissionID: UUID(),
                image: prepared,
                note: note.nilIfBlank
            )
            router.pop()
        } catch { errorMessage = mortMessage(error) }
    }
}
