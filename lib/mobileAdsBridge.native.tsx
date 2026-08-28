import { BannerAd, BannerAdSize, default as mobileAds, MaxAdContentRating, AgeRestrictedTreatment } from "react-native-google-mobile-ads";

export type NativeAdConfiguration = {
  conservative: boolean;
};

export type NativeBannerAdProps = {
  unitId: string;
  requestNonPersonalizedAdsOnly: boolean;
};

export async function configureMobileAds(configuration: NativeAdConfiguration) {
  await mobileAds().setRequestConfiguration({
    maxAdContentRating: configuration.conservative ? MaxAdContentRating.PG : MaxAdContentRating.T,
    ageRestrictedTreatment: configuration.conservative ? AgeRestrictedTreatment.TEEN : AgeRestrictedTreatment.UNSPECIFIED,
    tagForUnderAgeOfConsent: configuration.conservative,
    testDeviceIdentifiers: ["EMULATOR"]
  });

  await mobileAds().initialize();
  return { initialized: true, reason: "Google Mobile Ads initialized." };
}

export function NativeBannerAd({ unitId, requestNonPersonalizedAdsOnly }: NativeBannerAdProps) {
  return (
    <BannerAd
      unitId={unitId}
      size={BannerAdSize.ANCHORED_ADAPTIVE_BANNER ?? BannerAdSize.BANNER}
      requestOptions={{ requestNonPersonalizedAdsOnly }}
    />
  );
}
