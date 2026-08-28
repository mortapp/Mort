import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname.replace(/^\/(.:)/, "$1");
const feed = readFileSync(join(root, "flutter_mort", "lib", "features", "jobs", "teen_job_screens.dart"), "utf8");
const service = readFileSync(join(root, "flutter_mort", "lib", "services", "native_permissions_service.dart"), "utf8");
const permissionScreen = readFileSync(join(root, "flutter_mort", "lib", "features", "settings", "native_permissions_screen.dart"), "utf8");
const manifest = readFileSync(join(root, "flutter_mort", "android", "app", "src", "main", "AndroidManifest.xml"), "utf8");
const plist = readFileSync(join(root, "flutter_mort", "ios", "Runner", "Info.plist"), "utf8");

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

assert(feed.includes("Manual entry works even when location access is denied"), "Manual area fallback copy is missing");
assert(feed.includes("MortTextField(label: 'City'"), "Manual city input is missing");
assert(feed.includes("label: 'State code'"), "Manual state input is missing");
assert(service.includes("LocationPermission.deniedForever"), "Permanent denial is not handled");
assert(permissionScreen.includes("Raw coordinates were discarded"), "Coordinate disposal is not disclosed");
assert(manifest.includes("ACCESS_COARSE_LOCATION"), "Android approximate location permission is missing");
assert(manifest.includes("ACCESS_FINE_LOCATION"), "Android precise-choice permission is missing");
assert(!manifest.includes("ACCESS_BACKGROUND_LOCATION"), "Android background location must be absent");
assert(plist.includes("NSLocationWhenInUseUsageDescription"), "iOS when-in-use description is missing");
assert(!plist.includes("NSLocationAlwaysUsageDescription"), "iOS always-location description must be absent");

console.log("PASS: denied-location flow retains manual city/state search and requests no background location.");
