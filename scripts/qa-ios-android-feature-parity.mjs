import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname.replace(/^\/(.:)/, "$1");
const matrixPath = join(root, "docs", "mobile", "MORT_PLATFORM_CAPABILITY_MATRIX.json");
const matrix = JSON.parse(readFileSync(matrixPath, "utf8"));
const requiredFields = [
  "featureId",
  "capability",
  "androidUiStatus",
  "androidServiceStatus",
  "androidPermissionStatus",
  "androidTestStatus",
  "iosUiStatus",
  "iosServiceStatus",
  "iosPermissionStatus",
  "iosTestStatus",
  "webStatus",
  "fallbackBehavior",
  "knownLimitation",
];
const requiredCapabilities = [
  "Authentication",
  "DOB age gate",
  "Role selection and onboarding",
  "Job feed",
  "Job posting",
  "Applications",
  "Messaging",
  "Notification center",
  "Legal center",
  "Contracts and payment records",
  "Start handshake",
  "Completion handshake",
  "General-area job search",
  "Temporary safety location",
  "Reports",
  "Blocking",
  "Safety Circle",
  "Optional Guardian Mode",
  "Discreet Mode",
  "Earnings goals",
  "Future Independence",
  "Resource directory",
  "App lock",
  "Device authentication",
  "Passkeys",
  "Camera capture",
  "Photo picker",
  "Deep links",
  "Account deletion",
  "Data export",
  "Accessibility",
  "Dark mode",
  "Offline and degraded states",
  "Session management",
  "Leaderboard",
];

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

assert(Array.isArray(matrix.records), "Parity matrix records are missing");
assert(matrix.records.length === requiredCapabilities.length, "Parity matrix does not contain all audited capabilities");
assert(new Set(matrix.records.map((record) => record.featureId)).size === matrix.records.length, "Feature IDs are not unique");
for (const capability of requiredCapabilities) {
  assert(matrix.records.some((record) => record.capability === capability), `Missing capability: ${capability}`);
}
for (const record of matrix.records) {
  for (const field of requiredFields) {
    assert(typeof record[field] === "string" && record[field].trim().length > 0, `${record.featureId} missing ${field}`);
  }
  assert(!/physical(?: android)? device (?:tested|passed)|play(?: console)? tested/i.test(record.androidTestStatus.replace(/pending/gi, "")), `${record.featureId} overclaims Android testing`);
  assert(!/iphone tested|testflight tested|xcode build passed/i.test(record.iosTestStatus), `${record.featureId} overclaims iOS testing`);
  assert(!/production.ready|foolproof|guarantees safety/i.test(JSON.stringify(record)), `${record.featureId} contains an unsafe claim`);
}

const manifest = readFileSync(join(root, "flutter_mort", "android", "app", "src", "main", "AndroidManifest.xml"), "utf8");
const gradle = readFileSync(join(root, "flutter_mort", "android", "app", "build.gradle.kts"), "utf8");
const activity = readFileSync(join(root, "flutter_mort", "android", "app", "src", "main", "kotlin", "com", "mortapp", "mobile", "MainActivity.kt"), "utf8");
assert(gradle.includes('namespace = "com.mortapp.mobile"'), "Android namespace mismatch");
assert(gradle.includes('applicationId = "com.mortapp.mobile"'), "Android application ID mismatch");
assert(activity.includes("package com.mortapp.mobile"), "MainActivity package mismatch");
assert(activity.includes("FlutterFragmentActivity"), "Android device authentication activity is not configured");
assert(!manifest.includes("ACCESS_BACKGROUND_LOCATION"), "Background location must remain absent");
assert(manifest.includes('android:scheme="com.mortapp.mobile"'), "Android deep-link scheme missing");
assert(!manifest.includes('android:scheme="mort"'), "Android deep-link scheme must stay the exact package identifier, not a broad legacy scheme");
assert(manifest.includes('android:usesCleartextTraffic="false"'), "Android cleartext traffic is not blocked");

console.log(`PASS: ${matrix.records.length} Android/iOS capability records validated without device-test overclaims.`);
