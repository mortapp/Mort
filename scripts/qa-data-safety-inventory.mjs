import { assert, pass, read } from './play-release-qa-helpers.mjs';

const scope = 'qa-data-safety-inventory';
const collection = read('docs/play/MORT_PLAY_DATA_COLLECTION_INVENTORY.csv');
const sdk = read('docs/play/MORT_PLAY_SDK_DATA_INVENTORY.csv');
const pubspec = read('flutter_mort/pubspec.yaml');
for (const category of ['Email','Date of birth and age band','Approximate location','Messages','Photos/files','Safety reports','Payment preference']) {
  assert(collection.includes(`"${category}"`), `Data inventory omits ${category}.`);
}
for (const dependency of ['supabase_flutter','local_auth','image_picker','geolocator','flutter_local_notifications']) {
  assert(pubspec.includes(`${dependency}:`), `Expected dependency ${dependency} changed without inventory review.`);
}
for (const dependency of ['purchases_flutter', 'purchases_ui_flutter', 'google_mobile_ads']) {
  assert(!pubspec.includes(`${dependency}:`), `Excluded dependency ${dependency} returned without inventory review.`);
}
for (const sdkName of ['Supabase','RevenueCat','google_mobile_ads','flutter_local_notifications']) {
  assert(sdk.toLowerCase().includes(sdkName.toLowerCase()), `SDK inventory omits ${sdkName}.`);
}
for (const excludedRow of [
  '"purchases_flutter / RevenueCat","No"',
  '"google_mobile_ads","No"',
]) {
  assert(sdk.includes(excludedRow), `SDK inventory does not mark ${excludedRow} as excluded.`);
}
pass(scope, 'declared data categories and detected privacy-relevant Flutter SDKs are inventoried');
