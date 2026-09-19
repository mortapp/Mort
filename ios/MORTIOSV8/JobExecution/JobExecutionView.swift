//
//  JobExecutionView.swift
//  MORT iOS V8 — Job Execution
//
//  Start (PIN handshake), do the work, submit proof, mark complete.
//  A job cannot start unless the backend says it is FUNDED.
//

import PhotosUI
import SwiftUI
import UIKit

struct JobStartPinView: View {
    let jobId: String
    let user: MortUser

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @Environment(\.dismiss) private var dismiss

    @State private var pin = ""
    @State private var issuedPin: String?
    @State private var isWorking = false
    @State private var error: MortError?
    @State private var started = false
    @State private var personMatchesProfile = false

    private var isPoster: Bool { user.role == .adult }

    var body: some View {
        MortScreen(
            title: started ? "Job started" : (isPoster ? "Your start code" : "Enter the start code"),
            subtitle: started
                ? "The clock is running. Stay safe and check in if we ask."
                : (isPoster
                    ? "Read this to your worker when they arrive. It confirms they're really there."
                    : "Ask the person who posted the job for their 6-digit code."),
            atmosphereIntensity: 0.6
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if started {
                    MortStatusPanel(
                        tone: .success,
                        symbol: "play.circle",
                        label: "IN PROGRESS",
                        detail: "Funding is confirmed. MORT still records completion and settlement before any earnings transfer or payout."
                    )
                } else if isPoster {
                    MortCard {
                        VStack(spacing: MortSpace.s3) {
                            Text("START CODE").mortEyebrow()
                            Text(issuedPin ?? "––––")
                                .font(MortFont.money(46, weight: .light))
                                .tracking(8)
                                .foregroundStyle(MortColor.textPrimary)
                            Text("Only share this in person.")
                                .mortMicro()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    MortNote(
                        text: "Never send the code by message. Handing it over in person is what makes it meaningful.",
                        tone: .warning
                    )
                } else {
                    if let error {
                        MortNote(text: error.userMessage, tone: .danger)
                    }
                    MortTextField(
                        label: "Start code",
                        placeholder: "6 digits",
                        text: $pin,
                        symbol: "number",
                        keyboard: .numberPad
                    )
                    MortNote(
                        text: "If they can't give you a code, don't start the job. Report it instead.",
                        tone: .info
                    )

                    Button {
                        personMatchesProfile.toggle()
                        MortHaptic.select()
                    } label: {
                        HStack(alignment: .top, spacing: MortSpace.s3) {
                            Image(systemName: personMatchesProfile ? "checkmark.square.fill" : "square")
                                .foregroundStyle(
                                    personMatchesProfile ? MortColor.silver1 : MortColor.textMuted
                                )
                            Text("I confirm the person here matches the MORT profile for this job.")
                                .mortBody()
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(personMatchesProfile ? "Checked" : "Unchecked")
                }
            }
        } bottom: {
            MortBottomBar {
                if started {
                    MortPrimaryButton(title: "Done") { dismiss() }
                } else if isPoster {
                    MortPrimaryButton(title: "Close") { dismiss() }
                } else {
                    MortPrimaryButton(
                        title: "Start the job",
                        symbol: "play.fill",
                        isBusy: isWorking,
                        isEnabled: pin.count == 6 && personMatchesProfile && !isWorking
                    ) {
                        Task { await start() }
                    }
                    MortQuietButton(title: "Something's wrong", tone: .danger) {
                        dismiss()
                        nav.present(.safetyReport(jobId: jobId))
                    }
                }
            }
        }
        .navigationTitle("Start job")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
                    .foregroundStyle(MortColor.textSecondary)
            }
        }
        .task {
            if isPoster { issuedPin = try? await mort.execution.startPin(jobId: jobId) }
        }
    }

    private func start() async {
        isWorking = true
        error = nil
        do {
            try await mort.execution.startJob(
                jobId: jobId,
                pin: pin,
                personMatchesProfile: personMatchesProfile
            )
            started = true
            MortHaptic.success()
        } catch let failure as MortError {
            error = failure
            MortHaptic.failure()
        } catch {
            self.error = .unknown
        }
        isWorking = false
    }
}

struct JobExecutionView: View {
    let jobId: String
    let user: MortUser

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var job: LoadState<MortJob> = .idle
    @State private var checkIn: SafetyCheckIn?
    @State private var conversationId: String?
    @State private var isWorking = false

    var body: some View {
        MortScreen(
            title: "Finishing up",
            subtitle: "Wrap up the job so you can get paid.",
            atmosphereIntensity: 0.65
        ) {
            switch job {
            case .idle, .loading:
                MortSkeletonList(rows: 3)
            case .failed(let error):
                MortErrorState(message: error.userMessage) { Task { await load() } }
            case .loaded(let value), .offlineCache(let value):
                VStack(alignment: .leading, spacing: MortSpace.s5) {
                    JobContextStrip(
                        title: value.title,
                        orderNumber: value.orderNumber,
                        counterpartyHandle: value.posterHandle
                    )

                    MortStatusPanel(
                        tone: .success,
                        symbol: "lock.shield",
                        label: "JOB FUNDED",
                        detail: "Funding for \(value.basePay.formatted) base pay is confirmed. Completion, settlement, and payout remain separate backend steps."
                    )

                    if let checkIn, checkIn.state != .confirmed {
                        CheckInPrompt(checkIn: checkIn) {
                            nav.push(.safetyCheckIn(jobId))
                        }
                    }

                    if value.requiresProof {
                        MortCard {
                            VStack(alignment: .leading, spacing: MortSpace.s3) {
                                MortSectionHeader(
                                    title: "Proof needed",
                                    subtitle: "This poster asked for a photo or note"
                                )
                                MortPrimaryButton(title: "Add proof", symbol: "camera") {
                                    nav.push(.jobProof(jobId))
                                }
                            }
                        }
                    }

                    VStack(spacing: MortSpace.s2) {
                        if let conversationId {
                            MortNavRow(title: "Message the poster", symbol: "bubble.left") {
                                nav.push(.conversation(conversationId))
                            }
                            MortDivider()
                        }
                        MortNavRow(title: "Safety Center", symbol: "shield.lefthalf.filled") {
                            nav.push(.safetyCenter)
                        }
                        MortDivider()
                        MortNavRow(title: "Report a problem", symbol: "flag", tone: .danger) {
                            nav.present(.safetyReport(jobId: jobId))
                        }
                    }
                }
            }
        } bottom: {
            MortBottomBar {
                MortPrimaryButton(
                    title: "I've finished the work",
                    symbol: "checkmark.circle",
                    isBusy: isWorking
                ) {
                    Task { await markComplete() }
                }
                MortNote(
                    text: "Submitting confirms that you completed the approved job scope. The poster confirms next; settlement and payout remain separate backend decisions.",
                    tone: .neutral
                )
            }
        }
        .navigationTitle("Job")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        job = .loading
        do {
            job = .loaded(try await mort.jobs.job(id: jobId))
            checkIn = try? await mort.safety.activeCheckIn()
            if let threads = try? await mort.messages.conversations() {
                conversationId = threads.first(where: { $0.jobId == jobId })?.id
            }
        } catch let error as MortError {
            job = .failed(error)
        } catch {
            job = .failed(.unknown)
        }
    }

    private func markComplete() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await mort.execution.markComplete(jobId: jobId)
            MortHaptic.success()
            nav.popToRoot()
        } catch {
            MortHaptic.failure()
        }
    }
}

struct JobProofView: View {
    let jobId: String

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var note = ""
    @State private var attachment: JobProofAttachment?
    @State private var previewImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showsCamera = false
    @State private var isWorking = false
    @State private var error: MortError?

    var body: some View {
        MortScreen(
            title: "Add proof",
            subtitle: "Add one clear photo and an optional note.",
            atmosphereIntensity: 0.65
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if let error {
                    MortNote(text: error.userMessage, tone: .danger)
                }

                MortCard {
                    VStack(alignment: .leading, spacing: MortSpace.s3) {
                        MortSectionHeader(
                            title: "Proof photo",
                            subtitle: "Stored privately with this job record"
                        )

                        if let previewImage {
                            Image(uiImage: previewImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 210)
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: MortRadius.md,
                                        style: .continuous
                                    )
                                )
                                .accessibilityLabel("Selected proof photo")

                            MortQuietButton(title: "Remove photo", tone: .danger) {
                                attachment = nil
                                self.previewImage = nil
                                selectedPhoto = nil
                            }
                        } else {
                            Text("No photo added yet.")
                                .mortMicro()
                        }

                        HStack(spacing: MortSpace.s2) {
                            PhotosPicker(
                                selection: $selectedPhoto,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label("Photo Library", systemImage: "photo.on.rectangle")
                                    .font(MortFont.label())
                                    .foregroundStyle(MortColor.textPrimary)
                                    .frame(
                                        maxWidth: .infinity,
                                        minHeight: MortMetric.minTouchTarget
                                    )
                                    .background {
                                        RoundedRectangle(
                                            cornerRadius: MortRadius.md,
                                            style: .continuous
                                        )
                                        .fill(MortColor.graphite2)
                                    }
                            }
                            .buttonStyle(.plain)

                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button {
                                    showsCamera = true
                                } label: {
                                    Label("Camera", systemImage: "camera")
                                        .font(MortFont.label())
                                        .foregroundStyle(MortColor.textPrimary)
                                        .frame(
                                            maxWidth: .infinity,
                                            minHeight: MortMetric.minTouchTarget
                                        )
                                        .background {
                                            RoundedRectangle(
                                                cornerRadius: MortRadius.md,
                                                style: .continuous
                                            )
                                            .fill(MortColor.graphite2)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                MortTextArea(
                    label: "Note",
                    placeholder: "e.g. Front and back done, clippings bagged by the side gate.",
                    text: $note
                )

                MortNote(
                    text: "MORT converts the image to JPEG before upload. Proof stays in the private proof bucket and is attached only after the backend validates the job and storage object.",
                    tone: .info
                )
            }
        } bottom: {
            MortBottomBar {
                MortPrimaryButton(
                    title: "Submit proof",
                    isBusy: isWorking,
                    isEnabled: attachment != nil && !isWorking
                ) {
                    Task { await submit() }
                }
            }
        }
        .navigationTitle("Proof")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
        .sheet(isPresented: $showsCamera) {
            MortCameraPicker(isPresented: $showsCamera) { image in
                accept(image: image, filename: "camera-proof.jpg")
            }
            .ignoresSafeArea()
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                error = .rejected("That image couldn't be read. Choose another photo.")
                return
            }
            accept(image: image, filename: "library-proof.jpg")
        } catch {
            self.error = .rejected("That image couldn't be loaded. Choose another photo.")
        }
    }

    private func accept(image: UIImage, filename: String) {
        error = nil
        guard
            let jpeg = normalizedJPEG(image),
            !jpeg.isEmpty,
            jpeg.count <= 10 * 1024 * 1024
        else {
            error = .rejected("That image is too large to use as job proof.")
            return
        }
        previewImage = image
        attachment = JobProofAttachment(
            data: jpeg,
            filename: filename,
            contentType: "image/jpeg"
        )
        MortHaptic.select()
    }

    private func normalizedJPEG(_ image: UIImage) -> Data? {
        let qualities: [CGFloat] = [0.88, 0.72, 0.58, 0.44]
        for quality in qualities {
            if let data = image.jpegData(compressionQuality: quality),
               data.count <= 10 * 1024 * 1024 {
                return data
            }
        }
        return nil
    }

    private func submit() async {
        guard let attachment else {
            error = .rejected("Add a proof photo before submitting.")
            return
        }
        isWorking = true
        error = nil
        do {
            try await mort.execution.submitProof(
                jobId: jobId,
                note: note,
                attachment: attachment
            )
            MortHaptic.success()
            nav.pop()
        } catch let failure as MortError {
            error = failure
        } catch {
            self.error = .unknown
        }
        isWorking = false
    }
}

private struct MortCameraPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImage: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: MortCameraPicker

        init(parent: MortCameraPicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.isPresented = false
        }
    }
}

#Preview("Start PIN — teen") {
    NavigationStack {
        JobStartPinView(jobId: MortFixtures.job.id, user: MortFixtures.teen)
    }
    .environment(\.mort, MortDependencies.preview())
    .environment(MortNavigator())
    .preferredColorScheme(.dark)
}
