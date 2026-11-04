#!/usr/bin/env node
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const helper = await readFile('scripts/android-java-common.ps1', 'utf8');
const apkBuilder = await readFile('scripts/build-android-device-test-apk.ps1', 'utf8');
const releaseBuilder = await readFile('scripts/android-release-profile-common.ps1', 'utf8');
const gradle = await readFile('flutter_mort/android/gradle/wrapper/gradle-wrapper.properties', 'utf8');

assert.match(helper, /function\s+Set-MortAndroidBuildJava\b/);
assert.ok(helper.indexOf('JAVA_HOME_17_X64') < helper.indexOf('JAVA_HOME_21_X64'), 'prefer the repository-supported JDK 17 before JDK 21');
assert.match(helper, /17\s*,\s*21/);
assert.match(apkBuilder, /android-java-common\.ps1/);
assert.match(apkBuilder, /Set-MortAndroidBuildJava/);
assert.match(releaseBuilder, /android-java-common\.ps1/);
assert.match(releaseBuilder, /Set-MortAndroidBuildJava/);
assert.match(gradle, /gradle-8\.14-all\.zip/);

console.log('ANDROID_GRADLE_JDK_COMPAT=PASS supported=17,21 gradle=8.14 builders=2');
