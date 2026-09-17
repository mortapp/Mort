//
//  ProfileViews.swift
//  MORT iOS V8 — Profile
//
//  Public profiles show handle + display name only. Never legal name, phone
//  number, exact address or personal email. Ratings and verifications come
//  from the backend — the app never computes or invents reputation.
//

import SwiftUI

struct ProfileHomeView: View {
    let user: MortUser

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @Environment(MortSession.self) private var session

    var body: some View {
        MortScreen(atmosphereIntensity: 0.6) {
            VStack(alignment: .leading, spacing: MortSpace.s6) {
                MortCard {
                    VStack(alignment: .leading, spacing: MortSpace.s4) {
                        HStack(spacing: MortSpace.s3) {
                            MortAvatar(initials: user.avatarInitials, size: 58)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(user.displayName).mortH2()
                                Text(user.handle).mortLabel()
                                MortRatingView(
                                    rating: user.rating,
                                    completedJobs: user.completedJobs
                                )
                            }
                            Spacer(minLength: 0)
                        }

                        if !user.verifications.isEmpty {
                            HStack(spacing: MortSpace.s2) {
                                ForEach(user.verifications, id: \.self) { badge in
                                    MortStatusPill(
                                        tone: .success,
                                        symbol: "checkmark.seal",
                                        label: badge,
                                        compact: true
                                    )
                                }
                            }
                        }

                        if let bio = user.bio, !bio.isEmpty {
                            Text(bio)
                                .mortBody()
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        MortGhostButton(title: "Edit profile", symbol: "pencil") {
                            nav.push(.editProfile)
                        }
                    }
                }

                if user.role == .teen {
                    VStack(alignment: .leading, spacing: MortSpace.s3) {
                        MortSectionHeader(title: "Money")
                        MortCard {
                            VStack(spacing: 0) {
                                MortNavRow(title: "Earnings", symbol: "chart.line.uptrend.xyaxis") {
                                    nav.push(.earnings)
                                }
                                MortDivider()
                                MortNavRow(title: "Payouts", symbol: "building.columns") {
                                    nav.push(.payoutStatus)
                                }
                                MortDivider()
                                MortNavRow(title: "Money basics", symbol: "book") {
                                    nav.push(.financialGuide)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: MortSpace.s3) {
                    MortSectionHeader(title: "Your record")
                    MortCard {
                        VStack(spacing: 0) {
                            MortNavRow(
                                title: "Job & payment history",
                                symbol: "clock.arrow.circlepath"
                            ) {
                                nav.push(.history)
                            }
                            MortDivider()
                            MortNavRow(title: "Reviews", symbol: "star") {
                                nav.push(.reviews(user.id))
                            }
                            MortDivider()
                            MortNavRow(title: "Annual summary", symbol: "square.and.arrow.down") {
                                nav.push(.annualExport)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: MortSpace.s3) {
                    MortSectionHeader(title: "MORT")
                    MortCard {
                        VStack(spacing: 0) {
                            MortNavRow(title: "Safety Center", symbol: "shield.lefthalf.filled") {
                                nav.push(.safetyCenter)
                            }
                            MortDivider()
                            MortNavRow(title: "How Fair Pay works", symbol: "scalemass") {
                                nav.push(.fairPayInfo)
                            }
                            MortDivider()
                            MortNavRow(title: "Support", symbol: "headphones") {
                                nav.push(.supportHome)
                            }
                            MortDivider()
                            MortNavRow(title: "Settings", symbol: "gearshape") {
                                nav.push(.settings)
                            }
                        }
                    }
                }

                MortQuietButton(title: "Sign out", symbol: "rectangle.portrait.and.arrow.right") {
                    Task { await session.signOut() }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PublicProfileView: View {
    let userId: String

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var profile: LoadState<MortUser> = .idle
    @State private var reviews: [MortReview] = []

    var body: some View {
        MortScreen(atmosphereIntensity: 0.6) {
            switch profile {
            case .idle, .loading:
                MortSkeletonList(rows: 4)
            case .failed(let error):
                MortErrorState(message: error.userMessage) { Task { await load() } }
            case .loaded(let user), .offlineCache(let user):
                VStack(alignment: .leading, spacing: MortSpace.s5) {
                    MortCard {
                        VStack(alignment: .leading, spacing: MortSpace.s4) {
                            HStack(spacing: MortSpace.s3) {
                                MortAvatar(initials: user.avatarInitials, size: 58)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(user.displayName).mortH2()
                                    Text(user.handle).mortLabel()
                                    MortRatingView(
                                        rating: user.rating,
                                        completedJobs: user.completedJobs
                                    )
                                }
                                Spacer(minLength: 0)
                            }
                            if !user.verifications.isEmpty {
                                HStack(spacing: MortSpace.s2) {
                                    ForEach(user.verifications, id: \.self) { badge in
                                        MortStatusPill(
                                            tone: .success,
                                            symbol: "checkmark.seal",
                                            label: badge,
                                            compact: true
                                        )
                                    }
                                }
                            }
                            if let bio = user.bio, !bio.isEmpty {
                                Text(bio)
                                    .mortBody()
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            MortDivider()
                            MortKeyValueRow(label: "AREA", value: user.area ?? "Not shared")
                            MortKeyValueRow(label: "ON MORT SINCE", value: user.memberSince)
                        }
                    }

                    if !reviews.isEmpty {
                        VStack(alignment: .leading, spacing: MortSpace.s3) {
                            MortSectionHeader(title: "Reviews", subtitle: "From completed jobs")
                            ForEach(reviews.prefix(3)) { review in
                                ReviewCard(review: review)
                            }
                            MortGhostButton(title: "All reviews", symbol: "star") {
                                nav.push(.reviews(userId))
                            }
                        }
                    }

                    MortQuietButton(title: "Report this person", tone: .danger) {
                        nav.present(.safetyReport(jobId: nil))
                    }
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        profile = .loading
        do {
            profile = .loaded(try await mort.profiles.profile(userId: userId))
            reviews = (try? await mort.profiles.reviews(userId: userId)) ?? []
        } catch let error as MortError {
            profile = .failed(error)
        } catch {
            profile = .failed(.unknown)
        }
    }
}

struct ReviewsView: View {
    let userId: String

    @Environment(\.mort) private var mort
    @State private var reviews: LoadState<[MortReview]> = .idle

    var body: some View {
        MortScreen(title: "Reviews", atmosphereIntensity: 0.6) {
            switch reviews {
            case .idle, .loading:
                MortSkeletonList(rows: 3)
            case .failed(let error):
                MortErrorState(message: error.userMessage) { Task { await load() } }
            case .loaded(let items), .offlineCache(let items):
                if items.isEmpty {
                    MortEmptyState(
                        symbol: "star",
                        title: "No reviews yet",
                        message: "Reviews appear after a job is confirmed complete."
                    )
                } else {
                    VStack(spacing: MortSpace.s3) {
                        ForEach(items) { review in
                            ReviewCard(review: review)
                        }
                    }
                }
            }
        }
        .navigationTitle("Reviews")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        reviews = .loading
        do {
            reviews = .loaded(try await mort.profiles.reviews(userId: userId))
        } catch let error as MortError {
            reviews = .failed(error)
        } catch {
            reviews = .failed(.unknown)
        }
    }
}

private struct ReviewCard: View {
    let review: MortReview

    var body: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpace.s2) {
                HStack(spacing: MortSpace.s2) {
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { i in
                            Image(systemName: i < review.rating ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundStyle(MortColor.silver2)
                        }
                    }
                    Text("\(review.rating)/5")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MortColor.textPrimary)
                    Spacer(minLength: MortSpace.s2)
                    Text(review.dateText).mortMicro()
                }
                Text(review.body)
                    .mortBody()
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(review.authorDisplayName) · \(review.jobTitle)")
                    .mortMicro()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(review.rating) out of 5. \(review.body). By \(review.authorDisplayName).")
    }
}

struct EditProfileView: View {
    let user: MortUser

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var draft = MortProfileDraft()
    @State private var isSaving = false
    @State private var error: MortError?

    var body: some View {
        MortScreen(
            title: "Edit profile",
            subtitle: "This is what other people on MORT see.",
            atmosphereIntensity: 0.6
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if let error {
                    MortNote(text: error.userMessage, tone: .danger)
                }

                MortTextField(
                    label: "Display name",
                    placeholder: "First name and last initial",
                    text: $draft.displayName,
                    symbol: "person",
                    helpText: "We never show your full legal name."
                )

                MortTextField(
                    label: "Area",
                    placeholder: "Neighborhood",
                    text: $draft.area,
                    symbol: "mappin.and.ellipse",
                    helpText: "Approximate only — never your exact address."
                )

                MortTextArea(
                    label: "About you",
                    placeholder: "What you're good at, what tools you have, when you're free.",
                    text: $draft.bio,
                    helpText: "Don't include your phone number, email or address."
                )

                if user.role == .teen {
                    VStack(alignment: .leading, spacing: MortSpace.s2) {
                        Text("WORK YOU DO").mortEyebrow()
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 112), spacing: MortSpace.s2)],
                            spacing: MortSpace.s2
                        ) {
                            ForEach(MortFixtures.categories, id: \.self) { category in
                                MortChip(
                                    label: category,
                                    isSelected: draft.categories.contains(category)
                                ) {
                                    if let index = draft.categories.firstIndex(of: category) {
                                        draft.categories.remove(at: index)
                                    } else {
                                        draft.categories.append(category)
                                    }
                                }
                            }
                        }
                    }
                }

                MortNote(
                    text: "Your @handle can't be changed — it's how your receipts and reviews stay linked to you.",
                    tone: .info
                )
            }
        } bottom: {
            MortBottomBar {
                MortPrimaryButton(
                    title: "Save changes",
                    isBusy: isSaving,
                    isEnabled: !draft.displayName.isEmpty && !isSaving
                ) {
                    Task { await save() }
                }
            }
        }
        .navigationTitle("Edit")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            draft.displayName = user.displayName
            draft.area = user.area ?? ""
            draft.bio = user.bio ?? ""
        }
    }

    private func save() async {
        isSaving = true
        error = nil
        do {
            _ = try await mort.profiles.updateProfile(userId: user.id, draft: draft)
            MortHaptic.success()
            nav.pop()
        } catch let failure as MortError {
            error = failure
        } catch {
            self.error = .unknown
        }
        isSaving = false
    }
}

#Preview {
    NavigationStack { ProfileHomeView(user: MortFixtures.teen) }
        .environment(\.mort, MortDependencies.preview())
        .environment(MortDependencies.preview().session)
        .environment(MortNavigator())
        .preferredColorScheme(.dark)
}
