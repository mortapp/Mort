import { assert, pass, read } from './play-release-qa-helpers.mjs';

const scope = 'qa-release-network-security';
const manifest = read('flutter_mort/android/app/src/main/AndroidManifest.xml');
const network = read('flutter_mort/android/app/src/main/res/xml/network_security_config.xml');
const config = read('flutter_mort/lib/core/config/app_config.dart');
const build = read('scripts/android-release-profile-common.ps1');
assert(manifest.includes('android:usesCleartextTraffic="false"'), 'Manifest allows cleartext.');
assert(network.includes('cleartextTrafficPermitted="false"'), 'Network security config allows cleartext.');
assert(!/(localhost|127\.0\.0\.1|10\.0\.2\.2|http:\/\/)/i.test(config + build), 'Release config contains a local/cleartext endpoint.');
assert(build.includes('configuredExpectedProjectRef'), 'Release build must check any separately configured Supabase project reference.');
assert(build.includes("Host -notmatch '^(?<projectRef>[a-z0-9]+)\\.supabase\\.co$'"), 'Release build must derive the project reference only from a standard HTTPS Supabase host.');
assert(build.includes('https://$expectedProjectRef.supabase.co'), 'Release build does not bind the configured project reference to its HTTPS URL.');
assert(!build.includes('rakjydmgwwgtdislanbt'), 'Release builder still pins the legacy Supabase project.');
pass(scope, 'release networking is HTTPS-only and binds each build to its configured Supabase project');
