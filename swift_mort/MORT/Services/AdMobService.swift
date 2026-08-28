import Foundation
import GoogleMobileAds
import Observation
import UIKit

struct AdDecision: Equatable, Sendable {
    let canShow: Bool
    let reason: String
    let adUnitID: String?
    let requestNonPersonalized: Bool
}

@MainActor
@Observable
final class AdMobService {
    static let sensitivePlacements: Set<String> = [
        "auth", "onboarding", "age_gate", "safety_ping", "report", "messages",
        "guardian_approval", "proof_upload", "verification", "payment_preference",
        "admin", "paywall",
    ]

    static let testBannerID = "ca-app-pub-3940256099942544/2435281174"
    static let testRewardedID = "ca-app-pub-3940256099942544/1712485313"

    private let configuration: AppConfiguration
    private let repository: MonetizationRepositoryProtocol
    private(set) var isStarted = false
    private(set) var rewardedAd: RewardedAd?
    private(set) var isLoadingReward = false

    init(configuration: AppConfiguration, repository: MonetizationRepositoryProtocol) {
        self.configuration = configuration
        self.repository = repository
    }

    func startIfEnabled() async {
        guard configuration.adsEnabled, !isStarted else { return }
        MobileAds.shared.start(completionHandler: nil)
        isStarted = true
    }

    func decision(placement: String, format: String, adFree: Bool) async -> AdDecision {
        guard !Self.sensitivePlacements.contains(placement) else {
            return AdDecision(canShow: false, reason: "Ads are blocked on safety-sensitive screens.", adUnitID: nil, requestNonPersonalized: true)
        }
        guard configuration.adsEnabled else {
            return AdDecision(canShow: false, reason: "Ads are disabled for this build.", adUnitID: nil, requestNonPersonalized: true)
        }
        guard !adFree else {
            return AdDecision(canShow: false, reason: "Ad-free entitlement active.", adUnitID: nil, requestNonPersonalized: true)
        }
        do {
            let backend = try await repository.adEligibility(placement: placement, format: format)
            guard backend.allowed else {
                return AdDecision(canShow: false, reason: backend.reason, adUnitID: nil, requestNonPersonalized: true)
            }
            let configuredID = format == "rewarded" ? configuration.admobRewardedID : configuration.admobBannerID
            let testID = format == "rewarded" ? Self.testRewardedID : Self.testBannerID
            let unitID = configuration.useTestAds ? testID : configuredID
            guard let unitID = unitID?.nilIfBlank else {
                return AdDecision(canShow: false, reason: "No ad unit is configured.", adUnitID: nil, requestNonPersonalized: true)
            }
            return AdDecision(
                canShow: true,
                reason: configuration.useTestAds ? "Eligible for a test ad." : "Eligible for a reviewed live ad.",
                adUnitID: unitID,
                requestNonPersonalized: backend.requestNonPersonalized
            )
        } catch {
            return AdDecision(canShow: false, reason: "Backend ad eligibility could not be confirmed.", adUnitID: nil, requestNonPersonalized: true)
        }
    }

    func loadRewarded(decision: AdDecision) async throws {
        guard decision.canShow, let adUnitID = decision.adUnitID else {
            throw MortError.featureUnavailable(decision.reason)
        }
        isLoadingReward = true
        defer { isLoadingReward = false }
        let request = Request()
        if decision.requestNonPersonalized {
            let extras = Extras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
        }
        rewardedAd = try await RewardedAd.load(with: adUnitID, request: request)
    }

    func presentRewarded(from viewController: UIViewController, reward: @escaping @MainActor () -> Void) throws {
        guard let rewardedAd else { throw MortError.featureUnavailable("The rewarded ad is not ready yet.") }
        rewardedAd.present(from: viewController) {
            Task { @MainActor in reward() }
        }
        self.rewardedAd = nil
    }
}
