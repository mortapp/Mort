import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/(.:)/, '$1')), '..');
const projectDirectory = path.join(root, 'MORT.xcodeproj');
const projectPath = path.join(projectDirectory, 'project.pbxproj');
const posix = (value) => value.split(path.sep).join('/');
const id = (value) => crypto.createHash('sha1').update(value).digest('hex').slice(0, 24).toUpperCase();
const q = (value) => `"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"`;

function walk(directory, extension) {
  if (!fs.existsSync(directory)) return [];
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(full, extension) : entry.name.endsWith(extension) ? [full] : [];
  }).sort();
}

const appSources = walk(path.join(root, 'MORT'), '.swift');
const testSources = walk(path.join(root, 'MORTTests'), '.swift');
const uiTestSources = walk(path.join(root, 'MORTUITests'), '.swift');
const appResources = [
  path.join(root, 'MORT', 'Assets.xcassets'),
  path.join(root, 'MORT', 'Resources', 'PrivacyInfo.xcprivacy'),
];
const appSupport = [
  path.join(root, 'MORT', 'Info.plist'),
  path.join(root, 'MORT', 'MORT.entitlements'),
];
const configs = [
  path.join(root, 'Config', 'Base.xcconfig'),
  path.join(root, 'Config', 'Debug.xcconfig'),
  path.join(root, 'Config', 'Release.xcconfig'),
  path.join(root, 'Config', 'Secrets.example.xcconfig'),
];

const projectID = id('project');
const rootGroupID = id('group:root');
const appGroupID = id('group:app');
const testsGroupID = id('group:tests');
const uiTestsGroupID = id('group:uitests');
const configGroupID = id('group:config');
const productsGroupID = id('group:products');
const appTargetID = id('target:app');
const testsTargetID = id('target:tests');
const uiTestsTargetID = id('target:uitests');
const appProductID = id('product:app');
const testsProductID = id('product:tests');
const uiTestsProductID = id('product:uitests');

const packageDefinitions = [
  ['SupabasePackage', 'https://github.com/supabase/supabase-swift', '2.51.0'],
  ['RevenueCatPackage', 'https://github.com/RevenueCat/purchases-ios-spm.git', '5.80.3'],
  ['GoogleMobileAdsPackage', 'https://github.com/googleads/swift-package-manager-google-mobile-ads.git', '13.6.0'],
];
const products = [
  ['Supabase', 'SupabasePackage'],
  ['RevenueCat', 'RevenueCatPackage'],
  ['RevenueCatUI', 'RevenueCatPackage'],
  ['GoogleMobileAds', 'GoogleMobileAdsPackage'],
];

const fileID = (file) => id(`file:${posix(path.relative(root, file))}`);
const buildID = (target, file) => id(`build:${target}:${posix(path.relative(root, file))}`);
const lines = [];
const section = (name, values) => {
  lines.push(`/* Begin ${name} section */`, ...values, `/* End ${name} section */`, '');
};

const buildFiles = [];
for (const file of appSources) buildFiles.push(`\t\t${buildID('app', file)} /* ${path.basename(file)} in Sources */ = {isa = PBXBuildFile; fileRef = ${fileID(file)} /* ${path.basename(file)} */; };`);
for (const file of testSources) buildFiles.push(`\t\t${buildID('tests', file)} /* ${path.basename(file)} in Sources */ = {isa = PBXBuildFile; fileRef = ${fileID(file)} /* ${path.basename(file)} */; };`);
for (const file of uiTestSources) buildFiles.push(`\t\t${buildID('uitests', file)} /* ${path.basename(file)} in Sources */ = {isa = PBXBuildFile; fileRef = ${fileID(file)} /* ${path.basename(file)} */; };`);
for (const file of appResources) buildFiles.push(`\t\t${buildID('app', file)} /* ${path.basename(file)} in Resources */ = {isa = PBXBuildFile; fileRef = ${fileID(file)} /* ${path.basename(file)} */; };`);
for (const [product] of products) buildFiles.push(`\t\t${id(`build:package:${product}`)} /* ${product} in Frameworks */ = {isa = PBXBuildFile; productRef = ${id(`package-product:${product}`)} /* ${product} */; };`);

const fileReferences = [];
for (const file of appSources) fileReferences.push(`\t\t${fileID(file)} /* ${path.basename(file)} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${q(posix(path.relative(path.join(root, 'MORT'), file)))}; sourceTree = "<group>"; };`);
for (const file of testSources) fileReferences.push(`\t\t${fileID(file)} /* ${path.basename(file)} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${q(posix(path.relative(path.join(root, 'MORTTests'), file)))}; sourceTree = "<group>"; };`);
for (const file of uiTestSources) fileReferences.push(`\t\t${fileID(file)} /* ${path.basename(file)} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${q(posix(path.relative(path.join(root, 'MORTUITests'), file)))}; sourceTree = "<group>"; };`);
for (const file of appResources) {
  const type = file.endsWith('.xcassets') ? 'folder.assetcatalog' : 'text.plist.xml';
  fileReferences.push(`\t\t${fileID(file)} /* ${path.basename(file)} */ = {isa = PBXFileReference; lastKnownFileType = ${type}; path = ${q(posix(path.relative(path.join(root, 'MORT'), file)))}; sourceTree = "<group>"; };`);
}
for (const file of appSupport) fileReferences.push(`\t\t${fileID(file)} /* ${path.basename(file)} */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = ${q(path.basename(file))}; sourceTree = "<group>"; };`);
for (const file of configs) fileReferences.push(`\t\t${fileID(file)} /* ${path.basename(file)} */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = ${q(path.basename(file))}; sourceTree = "<group>"; };`);
fileReferences.push(
  `\t\t${appProductID} /* MORT.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = MORT.app; sourceTree = BUILT_PRODUCTS_DIR; };`,
  `\t\t${testsProductID} /* MORTTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = MORTTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };`,
  `\t\t${uiTestsProductID} /* MORTUITests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = MORTUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };`,
);

const childList = (files) => files.map((file) => `\t\t\t\t${fileID(file)} /* ${path.basename(file)} */,`).join('\n');
const groupLines = [
  `\t\t${rootGroupID} = {isa = PBXGroup; children = (\n\t\t\t\t${appGroupID} /* MORT */,\n\t\t\t\t${testsGroupID} /* MORTTests */,\n\t\t\t\t${uiTestsGroupID} /* MORTUITests */,\n\t\t\t\t${configGroupID} /* Config */,\n\t\t\t\t${productsGroupID} /* Products */,\n\t\t\t); sourceTree = "<group>"; };`,
  `\t\t${appGroupID} /* MORT */ = {isa = PBXGroup; children = (\n${childList([...appSources, ...appResources, ...appSupport])}\n\t\t\t); path = MORT; sourceTree = "<group>"; };`,
  `\t\t${testsGroupID} /* MORTTests */ = {isa = PBXGroup; children = (\n${childList(testSources)}\n\t\t\t); path = MORTTests; sourceTree = "<group>"; };`,
  `\t\t${uiTestsGroupID} /* MORTUITests */ = {isa = PBXGroup; children = (\n${childList(uiTestSources)}\n\t\t\t); path = MORTUITests; sourceTree = "<group>"; };`,
  `\t\t${configGroupID} /* Config */ = {isa = PBXGroup; children = (\n${childList(configs)}\n\t\t\t); path = Config; sourceTree = "<group>"; };`,
  `\t\t${productsGroupID} /* Products */ = {isa = PBXGroup; children = (\n\t\t\t\t${appProductID} /* MORT.app */,\n\t\t\t\t${testsProductID} /* MORTTests.xctest */,\n\t\t\t\t${uiTestsProductID} /* MORTUITests.xctest */,\n\t\t\t); name = Products; sourceTree = "<group>"; };`,
];

const phase = (phaseName, target, files, isa) => `\t\t${id(`phase:${target}:${phaseName}`)} /* ${phaseName} */ = {isa = ${isa}; buildActionMask = 2147483647; files = (\n${files.map((file) => `\t\t\t\t${buildID(target, file)} /* ${path.basename(file)} in ${phaseName} */,`).join('\n')}\n\t\t\t); runOnlyForDeploymentPostprocessing = 0; };`;
const appFrameworkBuilds = products.map(([product]) => `\t\t\t\t${id(`build:package:${product}`)} /* ${product} in Frameworks */,`).join('\n');

const targetDependencyLines = [];
for (const target of ['tests', 'uitests']) {
  targetDependencyLines.push(`\t\t${id(`proxy:${target}`)} = {isa = PBXContainerItemProxy; containerPortal = ${projectID} /* Project object */; proxyType = 1; remoteGlobalIDString = ${appTargetID}; remoteInfo = MORT; };`);
}

const configObject = (identifier, name, settings, baseFile) => {
  const base = baseFile ? `baseConfigurationReference = ${fileID(path.join(root, 'Config', baseFile))} /* ${baseFile} */; ` : '';
  return `\t\t${identifier} /* ${name} */ = {isa = XCBuildConfiguration; ${base}buildSettings = {${settings}}; name = ${name}; };`;
};
const projectDebug = id('config:project:debug');
const projectRelease = id('config:project:release');
const appDebug = id('config:app:debug');
const appRelease = id('config:app:release');
const testsDebug = id('config:tests:debug');
const testsRelease = id('config:tests:release');
const uiDebug = id('config:uitests:debug');
const uiRelease = id('config:uitests:release');

lines.push('// !$*UTF8*$!', '{', '\tarchiveVersion = 1;', '\tclasses = {};', '\tobjectVersion = 60;', '\tobjects = {', '');
section('PBXBuildFile', buildFiles);
section('PBXContainerItemProxy', targetDependencyLines);
section('PBXFileReference', fileReferences);
section('PBXFrameworksBuildPhase', [
  `\t\t${id('phase:app:Frameworks')} /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (\n${appFrameworkBuilds}\n\t\t\t); runOnlyForDeploymentPostprocessing = 0; };`,
  `\t\t${id('phase:tests:Frameworks')} /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };`,
  `\t\t${id('phase:uitests:Frameworks')} /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };`,
]);
section('PBXGroup', groupLines);
section('PBXNativeTarget', [
  `\t\t${appTargetID} /* MORT */ = {isa = PBXNativeTarget; buildConfigurationList = ${id('config-list:app')}; buildPhases = (${id('phase:app:Sources')}, ${id('phase:app:Frameworks')}, ${id('phase:app:Resources')}); buildRules = (); dependencies = (); name = MORT; packageProductDependencies = (${products.map(([product]) => id(`package-product:${product}`)).join(', ')}); productName = MORT; productReference = ${appProductID}; productType = "com.apple.product-type.application"; };`,
  `\t\t${testsTargetID} /* MORTTests */ = {isa = PBXNativeTarget; buildConfigurationList = ${id('config-list:tests')}; buildPhases = (${id('phase:tests:Sources')}, ${id('phase:tests:Frameworks')}, ${id('phase:tests:Resources')}); buildRules = (); dependencies = (${id('dependency:tests')}); name = MORTTests; productName = MORTTests; productReference = ${testsProductID}; productType = "com.apple.product-type.bundle.unit-test"; };`,
  `\t\t${uiTestsTargetID} /* MORTUITests */ = {isa = PBXNativeTarget; buildConfigurationList = ${id('config-list:uitests')}; buildPhases = (${id('phase:uitests:Sources')}, ${id('phase:uitests:Frameworks')}, ${id('phase:uitests:Resources')}); buildRules = (); dependencies = (${id('dependency:uitests')}); name = MORTUITests; productName = MORTUITests; productReference = ${uiTestsProductID}; productType = "com.apple.product-type.bundle.ui-testing"; };`,
]);
section('PBXProject', [
  `\t\t${projectID} /* Project object */ = {isa = PBXProject; attributes = {BuildIndependentTargetsInParallel = 1; LastSwiftUpdateCheck = 1600; LastUpgradeCheck = 1600; TargetAttributes = {${appTargetID} = {CreatedOnToolsVersion = 16.0;}; ${testsTargetID} = {CreatedOnToolsVersion = 16.0; TestTargetID = ${appTargetID};}; ${uiTestsTargetID} = {CreatedOnToolsVersion = 16.0; TestTargetID = ${appTargetID};};};}; buildConfigurationList = ${id('config-list:project')}; compatibilityVersion = "Xcode 15.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = ${rootGroupID}; packageReferences = (${packageDefinitions.map(([name]) => id(`package:${name}`)).join(', ')}); productRefGroup = ${productsGroupID}; projectDirPath = ""; projectRoot = ""; targets = (${appTargetID}, ${testsTargetID}, ${uiTestsTargetID}); };`,
]);
section('PBXResourcesBuildPhase', [
  phase('Resources', 'app', appResources, 'PBXResourcesBuildPhase'),
  `\t\t${id('phase:tests:Resources')} /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };`,
  `\t\t${id('phase:uitests:Resources')} /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };`,
]);
section('PBXSourcesBuildPhase', [
  phase('Sources', 'app', appSources, 'PBXSourcesBuildPhase'),
  phase('Sources', 'tests', testSources, 'PBXSourcesBuildPhase'),
  phase('Sources', 'uitests', uiTestSources, 'PBXSourcesBuildPhase'),
]);
section('PBXTargetDependency', [
  `\t\t${id('dependency:tests')} = {isa = PBXTargetDependency; target = ${appTargetID}; targetProxy = ${id('proxy:tests')}; };`,
  `\t\t${id('dependency:uitests')} = {isa = PBXTargetDependency; target = ${appTargetID}; targetProxy = ${id('proxy:uitests')}; };`,
]);
section('XCBuildConfiguration', [
  configObject(projectDebug, 'Debug', 'CLANG_ENABLE_MODULES = YES; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SDKROOT = iphoneos; SWIFT_VERSION = 5.9;', null),
  configObject(projectRelease, 'Release', 'CLANG_ENABLE_MODULES = YES; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SDKROOT = iphoneos; SWIFT_COMPILATION_MODE = wholemodule; SWIFT_VERSION = 5.9;', null),
  configObject(appDebug, 'Debug', 'CODE_SIGN_ENTITLEMENTS = MORT/MORT.entitlements; CODE_SIGN_STYLE = Automatic; ENABLE_PREVIEWS = YES; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = MORT/Info.plist; PRODUCT_NAME = MORT; SWIFT_EMIT_LOC_STRINGS = YES;', 'Debug.xcconfig'),
  configObject(appRelease, 'Release', 'CODE_SIGN_ENTITLEMENTS = MORT/MORT.entitlements; CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = MORT/Info.plist; PRODUCT_NAME = MORT; SWIFT_EMIT_LOC_STRINGS = YES;', 'Release.xcconfig'),
  configObject(testsDebug, 'Debug', 'BUNDLE_LOADER = "$(TEST_HOST)"; CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = YES; IPHONEOS_DEPLOYMENT_TARGET = 17.0; PRODUCT_BUNDLE_IDENTIFIER = com.mortapp.mobile.tests; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 5.9; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/MORT.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/MORT";', null),
  configObject(testsRelease, 'Release', 'BUNDLE_LOADER = "$(TEST_HOST)"; CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = YES; IPHONEOS_DEPLOYMENT_TARGET = 17.0; PRODUCT_BUNDLE_IDENTIFIER = com.mortapp.mobile.tests; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 5.9; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/MORT.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/MORT";', null),
  configObject(uiDebug, 'Debug', 'CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = YES; IPHONEOS_DEPLOYMENT_TARGET = 17.0; PRODUCT_BUNDLE_IDENTIFIER = com.mortapp.mobile.uitests; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 5.9; TEST_TARGET_NAME = MORT;', null),
  configObject(uiRelease, 'Release', 'CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = YES; IPHONEOS_DEPLOYMENT_TARGET = 17.0; PRODUCT_BUNDLE_IDENTIFIER = com.mortapp.mobile.uitests; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 5.9; TEST_TARGET_NAME = MORT;', null),
]);
section('XCConfigurationList', [
  `\t\t${id('config-list:project')} = {isa = XCConfigurationList; buildConfigurations = (${projectDebug}, ${projectRelease}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };`,
  `\t\t${id('config-list:app')} = {isa = XCConfigurationList; buildConfigurations = (${appDebug}, ${appRelease}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };`,
  `\t\t${id('config-list:tests')} = {isa = XCConfigurationList; buildConfigurations = (${testsDebug}, ${testsRelease}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };`,
  `\t\t${id('config-list:uitests')} = {isa = XCConfigurationList; buildConfigurations = (${uiDebug}, ${uiRelease}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };`,
]);
section('XCRemoteSwiftPackageReference', packageDefinitions.map(([name, url, version]) => `\t\t${id(`package:${name}`)} /* ${name} */ = {isa = XCRemoteSwiftPackageReference; repositoryURL = ${q(url)}; requirement = {kind = exactVersion; version = ${version};}; };`));
section('XCSwiftPackageProductDependency', products.map(([product, packageName]) => `\t\t${id(`package-product:${product}`)} /* ${product} */ = {isa = XCSwiftPackageProductDependency; package = ${id(`package:${packageName}`)}; productName = ${product}; };`));
lines.push('\t};', `\trootObject = ${projectID} /* Project object */;`, '}', '');

fs.mkdirSync(projectDirectory, { recursive: true });
fs.writeFileSync(projectPath, lines.join('\n'), 'utf8');
console.log(`Generated ${projectPath} with ${appSources.length} app sources, ${testSources.length} unit-test sources, and ${uiTestSources.length} UI-test sources.`);
