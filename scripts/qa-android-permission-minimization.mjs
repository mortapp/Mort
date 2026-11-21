import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const scope = 'qa-android-permission-minimization';
const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const source = read('flutter_mort/android/app/src/main/AndroidManifest.xml');
const noAds = read('flutter_mort/android/app/src/noAds/AndroidManifest.xml');
const pubspec = read('flutter_mort/pubspec.yaml');

for (const forbidden of [
  'ACCESS_BACKGROUND_LOCATION',
  'READ_MEDIA_IMAGES',
  'READ_EXTERNAL_STORAGE',
  'WRITE_EXTERNAL_STORAGE',
  'com.android.vending.BILLING',
]) {
  assert(!source.includes(forbidden) && !noAds.includes(forbidden), `Forbidden permission remains: ${forbidden}`);
}
assert(!pubspec.includes('in_app_purchase:'), 'in_app_purchase remains in the free pilot dependency graph.');

function assertRemoved(manifest, name) {
  const explicitlyRemoved = new RegExp(`${name.replaceAll('.', '\\.')}[^>]+tools:node="remove"`).test(manifest);
  assert(explicitlyRemoved, `Missing Android manifest removal: ${name}`);
}
for (const permission of [
  'com.google.android.gms.permission.AD_ID',
  'android.permission.ACCESS_ADSERVICES_AD_ID',
  'android.permission.ACCESS_ADSERVICES_ATTRIBUTION',
  'android.permission.ACCESS_ADSERVICES_TOPICS',
]) {
  assertRemoved(source, permission);
}
for (const component of [
  'com.google.android.gms.ads.APPLICATION_ID',
  'com.google.android.gms.ads.MobileAdsInitProvider',
  'com.google.android.gms.ads.AdActivity',
  'com.google.android.gms.ads.OutOfContextTestingActivity',
  'com.google.android.gms.ads.NotificationHandlerActivity',
  'com.google.android.gms.ads.AdService',
  'android.adservices.AD_SERVICES_CONFIG',
]) {
  assertRemoved(noAds, component);
}
assert(source.includes('android.permission.WAKE_LOCK'), 'FCM wake-lock capability is missing.');
console.log(`[${scope}] PASS: source policy only. Inspect the packaged APK or signed AAB separately.`);
