import { assert, pass, read } from './play-release-qa-helpers.mjs';

const scope = 'qa-debug-feature-removal';
const source = read('flutter_mort/lib/app.dart') + read('flutter_mort/lib/main.dart');
const build = read('scripts/build-play-aab.ps1');
assert(!source.includes('debugShowCheckedModeBanner: true'), 'Flutter debug banner is enabled.');
assert(!/debug menu|developer menu/i.test(source), 'Ordinary app shell exposes a debug/developer menu.');
assert(build.includes('--release') && !build.includes('--debug'), 'Play build script is not release-only.');
pass(scope, 'release entry points do not expose Flutter debug banners or debug build mode');
