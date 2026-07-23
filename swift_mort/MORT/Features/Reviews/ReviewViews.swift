import SwiftUI

struct ReviewsView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var state: LoadState<[MortReview]> = .idle

    var body: some View {
        Group {
            switch state {
            case .idle, .loading: MortLoadingState(label: "Loading reviews")
            case let .failed(message): MortErrorState(message: message) { Task { await load() } }
            case let .loaded(reviews) where reviews.isEmpty:
                MortEmptyState(title: "No approved reviews", message: "Reviews from completed jobs appear after moderation.", systemImage: "star")
            case let .loaded(reviews):
                List(reviews) { review in
                    MortCard {
                        VStack(alignment: .leading, spacing: MortSpacing.sm) {
                            HStack {
                                ForEach(1...5, id: \.self) { value in
                                    Image(systemName: value <= review.rating ? "star.fill" : "star").foregroundStyle(MortColors.warning)
                                }
                                Spacer()
                                Button { router.push(.report(.review(review.id))) } label: { Image(systemName: "flag") }
                                    .accessibilityLabel("Report review")
                            }
                            if let body = review.body { Text(body).foregroundStyle(MortColors.textSoft) }
                            Text(DateFormatting.displayDateTime(review.createdAt)).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                        }
                    }
                    .listRowBackground(MortColors.background)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Reviews")
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await container.reviews.received()) }
        catch { state = .failed(mortMessage(error)) }
    }
}

struct LeaveReviewView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var rating = 5
    @State private var bodyText = ""
    @State private var existing: MortReview?
    @State private var isWorking = false
    @State private var errorMessage: String?
    let jobID: UUID
    let subjectID: UUID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Leave a review", subtitle: "Completed jobs only. Each side may submit one factual review.")
                if let existing {
                    MortAlertBanner(title: "Review already submitted", message: "You rated this job \(existing.rating) out of 5. One review per side is allowed.", tint: MortColors.safetyBlue, icon: "checkmark.circle.fill")
                } else {
                    HStack {
                        ForEach(1...5, id: \.self) { value in
                            Button { rating = value } label: {
                                Image(systemName: value <= rating ? "star.fill" : "star").font(.title).foregroundStyle(MortColors.warning)
                            }
                            .accessibilityLabel("\(value) star rating")
                        }
                    }
                    MortTextField(title: "Comment (optional)", text: $bodyText, prompt: "Share specific, respectful feedback", axis: .vertical)
                    MortSafetyBanner(message: "Do not include private contact details, addresses, health information, or retaliatory threats.")
                    MortPrimaryButton(title: "Submit review", icon: "star.fill", isLoading: isWorking) { Task { await submit() } }
                }
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Review not submitted", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        do { existing = try await container.reviews.currentUsersReview(jobID: jobID) }
        catch { errorMessage = mortMessage(error) }
    }

    private func submit() async {
        isWorking = true
        defer { isWorking = false }
        do { _ = try await container.reviews.create(jobID: jobID, subjectID: subjectID, rating: rating, body: bodyText.nilIfBlank); router.pop() }
        catch { errorMessage = mortMessage(error) }
    }
}
