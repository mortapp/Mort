import type { ExpoConfig } from "expo/config";

const iosBundleIdentifier = process.env.IOS_BUNDLE_IDENTIFIER || "com.mortapp.mobile";
const androidPackageName = process.env.ANDROID_PACKAGE_NAME || "com.mortapp.mobile";
const easProjectId = process.env.EXPO_PUBLIC_PROJECT_ID || "00000000-0000-0000-0000-000000000000";
const appEnv = process.env.EXPO_PUBLIC_APP_ENV || "development";
const admobIosAppId = process.env.EXPO_PUBLIC_ADMOB_IOS_APP_ID || "ca-app-pub-9412242686563958~6217664808";
const admobAndroidAppId =
  process.env.EXPO_PUBLIC_ADMOB_ANDROID_APP_ID || "ca-app-pub-3940256099942544~3347511713";

const config: ExpoConfig = {
  name: "MORT",
  slug: "mort-mobile",
  scheme: "mort",
  version: "0.1.0",
  orientation: "portrait",
  userInterfaceStyle: "dark",
  assetBundlePatterns: ["**/*"],
  ios: {
    supportsTablet: false,
    bundleIdentifier: iosBundleIdentifier,
    buildNumber: "1",
    infoPlist: {
      NSCameraUsageDescription:
        "MORT lets users upload job completion proof, business verification images, and safety-related report attachments.",
      NSPhotoLibraryUsageDescription:
        "MORT lets users select job proof, verification documents, and report evidence from their photo library.",
      NSUserNotificationsUsageDescription:
        "MORT sends safety, guardian approval, application, and message notifications.",
      ITSAppUsesNonExemptEncryption: false
    }
  },
  android: {
    package: androidPackageName
  },
  web: {
    bundler: "metro",
    output: "static"
  },
  extra: {
    appEnv,
    eas: {
      projectId: easProjectId
    }
  },
  plugins: [
    "expo-router",
    "expo-secure-store",
    "expo-font",
    [
      "expo-notifications",
      {
        icon: "./assets/notification-icon.png",
        color: "#39ff88",
        defaultChannel: "mort"
      }
    ],
    [
      "expo-image-picker",
      {
        photosPermission: "MORT lets you upload proof, verification, and report images.",
        cameraPermission: "MORT lets you take proof, verification, and report photos."
      }
    ],
    [
      "react-native-google-mobile-ads",
      {
        iosAppId: admobIosAppId,
        androidAppId: admobAndroidAppId,
        delayAppMeasurementInit: true,
        optimizeInitialization: true,
        optimizeAdLoading: true
      }
    ]
  ],
  experiments: {
    typedRoutes: true
  }
};

export default config;
