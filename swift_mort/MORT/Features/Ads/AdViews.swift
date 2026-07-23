import GoogleMobileAds
import SwiftUI
import UIKit

struct MortBannerPlacement: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(RevenueCatService.self) private var revenueCat
    @State private var decision: AdDecision?
    let placement: String

    var body: some View {
        Group {
            if let decision, decision.canShow, let adUnitID = decision.adUnitID {
                MortBannerAd(adUnitID: adUnitID, nonPersonalized: decision.requestNonPersonalized) {
                    Task {
                        do { try await container.monetization.recordAdImpression(placement: placement, format: "banner", adUnitID: adUnitID) }
                        catch { return }
                    }
                }
                .frame(height: 60)
                .accessibilityLabel("Advertisement")
            }
        }
        .task {
            decision = await container.ads.decision(
                placement: placement,
                format: "banner",
                adFree: revenueCat.entitlementState.isAdFree
            )
        }
    }
}

private struct MortBannerAd: UIViewRepresentable {
    let adUnitID: String
    let nonPersonalized: Bool
    let onLoaded: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onLoaded: onLoaded) }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = Self.topViewController()
        let request = Request()
        if nonPersonalized {
            let extras = Extras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
        }
        banner.load(request)
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        uiView.rootViewController = Self.topViewController()
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        let onLoaded: () -> Void
        init(onLoaded: @escaping () -> Void) { self.onLoaded = onLoaded }
        func bannerViewDidReceiveAd(_ bannerView: BannerView) { onLoaded() }
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        var controller = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }
}
