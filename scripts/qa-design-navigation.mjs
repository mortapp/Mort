import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');
const flutterRoot = path.join(root, 'flutter_mort');
const routerPath = path.join(
  flutterRoot,
  'lib',
  'core',
  'routing',
  'app_router.dart',
);
const router = fs.readFileSync(routerPath, 'utf8');

function extractCall(source, start) {
  const open = source.indexOf('(', start);
  let depth = 0;
  let quote = null;
  let escaped = false;
  for (let index = open; index < source.length; index += 1) {
    const char = source[index];
    if (quote) {
      if (escaped) escaped = false;
      else if (char === '\\') escaped = true;
      else if (char === quote) quote = null;
      continue;
    }
    if (char === "'" || char === '"') {
      quote = char;
      continue;
    }
    if (char === '(') depth += 1;
    if (char === ')' && --depth === 0) return source.slice(start, index + 1);
  }
  throw new Error(`Unbalanced route call at offset ${start}`);
}

function walk(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(full) : [full];
  });
}

const publicRoutes = new Set([
  '/',
  '/splash',
  '/welcome',
  '/auth/sign-in',
  '/auth/sign-up',
  '/auth-callback',
  '/auth/confirm',
  '/auth/recovery',
  '/auth/forgot-password',
  '/support',
  '/legal/terms',
  '/legal/privacy',
  '/legal/community-rules',
  '/legal/payment-disclaimer',
  '/legal/verification-disclaimer',
  '/legal/ad-disclosure',
  '/legal/subscription-disclosure',
  '/legal/teen-safety',
  '/legal/guardian-guide',
]);
const failures = [];
let directRouteCount = 0;
let guardedDirectRouteCount = 0;

for (const match of router.matchAll(/\bGoRoute\s*\(/g)) {
  const call = extractCall(router, match.index);
  const route = call.match(/\bpath:\s*'([^']+)'/s)?.[1];
  if (!route) continue;
  directRouteCount += 1;
  const guarded = call.includes('GuardedRoute(');
  if (guarded) guardedDirectRouteCount += 1;
  if (!publicRoutes.has(route) && !guarded) {
    failures.push(`${route}: direct route is neither public-allowlisted nor guarded`);
  }
  for (const role of ['teen', 'adult', 'guardian', 'admin']) {
    if (route.startsWith(`/${role}/`) && !call.includes(`UserRole.${role}`)) {
      failures.push(`${route}: missing explicit ${role} role guard`);
    }
  }
}

if (!router.includes('if (AppConfig.playReviewModeEnabled)')) {
  failures.push('reviewer routes are not compile-profile gated');
}
if (!router.includes('ReviewerRouteGuard(child: child)')) {
  failures.push('reviewer routes are missing the isolated reviewer guard');
}

const libFiles = walk(path.join(flutterRoot, 'lib')).filter((file) =>
  file.endsWith('.dart'),
);
const oldBrandPattern = /Colors\.(?:green|teal|lime)\b/;
for (const file of libFiles) {
  const source = fs.readFileSync(file, 'utf8');
  if (oldBrandPattern.test(source)) {
    failures.push(
      `${path.relative(root, file).replaceAll('\\', '/')}: old green-family color`,
    );
  }
}

const requiredDesignEvidence = [
  ['metallic rose-gold', 'MortColors.metallicGradient'],
  ['safety blue', 'MortColors.lightBlue'],
  ['selective blur', 'if (blur)'],
  ['safe area', 'SafeArea('],
  ['content width constraint', 'MortSpacing.maxContentWidth'],
  ['reduced motion', 'MediaQuery.disableAnimationsOf(context)'],
  ['loading state', 'class MortLoading'],
  ['empty state', 'class MortEmptyState'],
  ['error state', 'class MortErrorState'],
  ['skeleton state', 'class MortSkeletonCard'],
  ['accessible icon button', 'required this.tooltip'],
];
const designSource = [
  'lib/core/theme/mort_colors.dart',
  'lib/core/theme/mort_tokens.dart',
  'lib/core/theme/mort_theme.dart',
  'lib/core/widgets/mort_brand.dart',
  'lib/core/widgets/mort_widgets.dart',
  'lib/core/widgets/mort_design_components.dart',
]
  .map((relative) => fs.readFileSync(path.join(flutterRoot, relative), 'utf8'))
  .join('\n');
for (const [label, needle] of requiredDesignEvidence) {
  if (!designSource.includes(needle)) failures.push(`missing ${label} evidence`);
}

if (failures.length) {
  console.error(failures.join('\n'));
  process.exitCode = 1;
} else {
  console.log(
    JSON.stringify({
      status: 'PASS',
      direct_routes: directRouteCount,
      guarded_direct_routes: guardedDirectRouteCount,
      public_routes: publicRoutes.size,
      flutter_source_files_scanned: libFiles.length,
    }),
  );
}
