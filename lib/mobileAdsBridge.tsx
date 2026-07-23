export type NativeAdConfiguration = {
  conservative: boolean;
};

export type NativeBannerAdProps = {
  unitId: string;
  requestNonPersonalizedAdsOnly: boolean;
};

export async function configureMobileAds(_configuration: NativeAdConfiguration) {
  return { initialized: false, reason: "Google Mobile Ads requires a native iOS or Android build." };
}

export function NativeBannerAd(_props: NativeBannerAdProps) {
  return null;
}
