import { assert, pass, read } from './play-release-qa-helpers.mjs';

const scope = 'qa-debug-feature-removal';
const source = read('flutter_mort/lib/app.dart') + read('flutter_mort/lib/main.dart');
const build = read('scripts/build-play-aab.ps1');
const profileBuild = read('scripts/build-closed-test-aab.ps1');
const commonBuild = read('scripts/android-release-profile-common.ps1');
assert(!source.includes('debugShowCheckedModeBanner: true'), 'Flutter debug banner is enabled.');
assert(!/debug menu|developer menu/i.test(source), 'Ordinary app shell exposes a debug/developer menu.');
assert(build.includes('build-closed-test-aab.ps1'), 'Play build does not delegate to the reviewed release profile.');
assert(
  profileBuild.includes('android-release-profile-common.ps1') && profileBuild.includes('-ArtifactKind Aab'),
  'Reviewed Play profile does not delegate to the shared AAB release builder.',
);
assert(
  commonBuild.includes('flutter build appbundle --release') &&
    commonBuild.includes('flutter build apk --release') &&
    !/(?:^|\s)--debug(?:\s|$)/m.test(commonBuild),
  'Shared Android builder is not release-only.',
);
pass(scope, 'release entry points do not expose Flutter debug banners or debug build mode');
