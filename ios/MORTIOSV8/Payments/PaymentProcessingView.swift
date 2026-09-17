//
//  PaymentProcessingView.swift
//  MORT iOS V8 — Payment OS
//
//  In-flight funding. Rule R2: no back affordance. A second submission is
//  impossible, and exiting mid-flight routes through status reconciliation —
//  never back to review.
//

import SwiftUI

struct PaymentProcessingView: View {
    let jobId: String

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var elapsed: Int = 0
    @State private var showDuplicateBlock = false

    var body: some View {
        ZStack {
            MortAtmosphere(intensity: 0.45, allowShimmer: false)

            VStack(spacing: MortSpace.s6) {
                Spacer()

                ProcessingIndicator()

                VStack(spacing: MortSpace.s3) {
                    Text("PROCESSING")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(MortColor.info)
                    Text("We're confirming this with your payment provider.")
                        .mortH2()
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Keep this screen open. Don't submit again — we've got this one.")
                        .mortBody()
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .mortScreenPadding()

                MortDuplicateSafetyNote()
                    .mortScreenPadding()

                if elapsed > 12 {
                    VStack(spacing: MortSpace.s3) {
                        MortNote(
                            text: "This is taking longer than usual. Your payment is still being checked — we'll never charge it twice.",
                            tone: .warning
                        )
                        MortGhostButton(title: "Check the status instead", symbol: "arrow.triangle.2.circlepath") {
                            nav.push(.paymentStatusCheck(jobId))
                        }
                    }
                    .mortScreenPadding()
                }

                Spacer()
            }
        }
        // Rule R2: back is disabled during an in-flight payment.
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled(true)
        .task {
            while elapsed < 60 {
                try? await Task.sleep(for: .seconds(1))
                elapsed += 1
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Processing your payment. Please keep this screen open.")
    }
}

/// A subtle orbital ring. Under Reduce Motion the ring stops but the status
/// text still carries the full meaning.
private struct ProcessingIndicator: View {
    @Environment(\.mortReducedMotion) private var reducedMotion
    @State private var angle: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(MortColor.graphite4, lineWidth: 1)
                .frame(width: 104, height: 104)
            Circle()
                .strokeBorder(MortColor.hairline2, lineWidth: 1)
                .frame(width: 72, height: 72)

            Circle()
                .trim(from: 0, to: 0.18)
                .stroke(
                    LinearGradient(
                        colors: [MortColor.ice1.opacity(0), MortColor.ice1],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 104, height: 104)
                .rotationEffect(.degrees(angle))

            Image(systemName: "lock.shield")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(MortColor.silver2)
        }
        .onAppear {
            guard !reducedMotion else { return }
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                angle = 360
            }
        }
        .accessibilityHidden(true)
    }
}

/// Status reconciliation: the ONLY way to learn an outcome after a dropped
/// connection. Never offers a blind retry first.
struct PaymentStatusCheckView: View {
    let jobId: String

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var state: PaymentState?
    @State private var reason: PaymentFailureReason?
    @State private var isChecking = false
    @State private var error: MortError?

    var body: some View {
        MortScreen(
            title: "Checking the payment",
            subtitle: "We're asking your provider what actually happened.",
            atmosphereIntensity: 0.6
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if isChecking {
                    HStack(spacing: MortSpace.s3) {
                        MortSpinner(size: 18)
                        Text("Reconciling with MORT…").mortBody()
                    }
                }

                if let error {
                    MortStatusPanel(
                        tone: .warning,
                        symbol: "exclamationmark.circle",
                        label: "COULDN'T CHECK YET",
                        detail: error.userMessage
                    )
                }

                if let state {
                    let presentation = PaymentStatePresentation.of(state)
                    MortStatusPanel(
                        tone: presentation.tone,
                        symbol: presentation.symbol,
                        label: presentation.label,
                        detail: presentation.purpose
                    )
                    if presentation.showsNoReceiptBanner {
                        MortNoReceiptBanner()
                    }
                    if let reason {
                        PaymentErrorReasonView(reason: reason)
                    }
                    MortNote(text: presentation.guidance, tone: .neutral)
                }

                MortDuplicateSafetyNote()
            }
        } bottom: {
            MortBottomBar {
                if let state {
                    if state == .funded {
                        MortPrimaryButton(title: "Continue", symbol: "checkmark") {
                            nav.push(.paymentResult(jobId: jobId, state: .funded))
                        }
                    } else if state == .pending || state == .unknown || state == .processing {
                        MortPrimaryButton(
                            title: "Check again",
                            symbol: "arrow.clockwise",
                            isBusy: isChecking
                        ) {
                            Task { await check() }
                        }
                        MortQuietButton(title: "Return to the job") { nav.popToRoot() }
                    } else {
                        MortPrimaryButton(title: "See what to do next") {
                            nav.push(.paymentResult(jobId: jobId, state: state))
                        }
                    }
                } else {
                    MortPrimaryButton(
                        title: "Check the status",
                        symbol: "arrow.clockwise",
                        isBusy: isChecking
                    ) {
                        Task { await check() }
                    }
                }
            }
        }
        .navigationTitle("Status")
        .navigationBarTitleDisplayMode(.inline)
        .task { await check() }
    }

    private func check() async {
        isChecking = true
        error = nil
        do {
            let result = try await mort.payments.fundingStatus(jobId: jobId)
            state = result.state
            reason = result.reason
        } catch let failure as MortError {
            error = failure
        } catch {
            self.error = .unknown
        }
        isChecking = false
    }
}

#Preview("Processing") {
    NavigationStack {
        PaymentProcessingView(jobId: MortFixtures.job.id)
    }
    .environment(\.mort, MortDependencies.preview())
    .environment(MortNavigator())
    .preferredColorScheme(.dark)
}
