import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');
const flutterRoot = path.join(root, 'flutter_mort');
const dartRoot = path.join(flutterRoot, 'lib');
const testRoot = path.join(flutterRoot, 'test');
const routerPath = path.join(dartRoot, 'core', 'routing', 'app_router.dart');
const outputRoot = path.join(root, 'docs', 'release');

function walk(directory, predicate = () => true) {
  const output = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) output.push(...walk(full, predicate));
    else if (predicate(full)) output.push(full);
  }
  return output;
}

function sourceRelative(file) {
  return path.relative(root, file).replaceAll('\\', '/');
}

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
    if (char === ')') {
      depth -= 1;
      if (depth === 0) return source.slice(start, index + 1);
    }
  }
  throw new Error(`Unbalanced route call at offset ${start}`);
}

function evidence(source, patterns) {
  return patterns.some((pattern) => pattern.test(source)) ? 'detected' : 'not_detected';
}

function unique(values) {
  return [...new Set(values.filter(Boolean))];
}

function csvCell(value) {
  const string = Array.isArray(value) ? value.join('; ') : String(value ?? '');
  return `"${string.replaceAll('"', '""')}"`;
}

const dartFiles = walk(dartRoot, (file) => file.endsWith('.dart'));
const testFiles = walk(testRoot, (file) => file.endsWith('.dart'));
const sources = new Map(dartFiles.map((file) => [file, fs.readFileSync(file, 'utf8')]));
const tests = new Map(testFiles.map((file) => [file, fs.readFileSync(file, 'utf8')]));
const classFiles = new Map();
for (const [file, source] of sources) {
  for (const match of source.matchAll(/class\s+([A-Z][A-Za-z0-9_]*)\b/g)) {
    classFiles.set(match[1], file);
  }
}

const router = fs.readFileSync(routerPath, 'utf8');
const calls = [];
for (const match of router.matchAll(/\b(?:GoRoute|_guarded)\s*\(/g)) {
  const call = extractCall(router, match.index);
  const routeMatch = call.startsWith('_guarded')
    ? call.match(/^_guarded\s*\(\s*'([^']+)'/s)
    : call.match(/\bpath:\s*'([^']+)'/s);
  if (routeMatch) calls.push({ call, route: routeMatch[1] });
}

const flutterRows = calls.map(({ call, route }) => {
  const constructors = unique(
    [...call.matchAll(/\b([A-Z][A-Za-z0-9_]*)\s*\(/g)].map((match) => match[1]),
  );
  const ignored = new Set([
    'GoRoute',
    'GuardedRoute',
    'SensitiveScreenProtection',
  ]);
  const screen = constructors.find((name) => classFiles.has(name) && !ignored.has(name)) ??
    (call.includes('_adminDetail') ? '_adminDetail' :
      call.includes('_academy') ? '_academy' :
        call.includes('_legalIndex') ? '_legalIndex' : 'unresolved_builder');
  const sourceFile = classFiles.get(screen) ?? routerPath;
  const source = sources.get(sourceFile) ?? router;
  const role = call.match(/(?:requiredRole|role):\s*UserRole\.([a-z]+)/)?.[1] ??
    (route.startsWith('/teen/') ? 'teen' :
      route.startsWith('/adult/') ? 'adult' :
        route.startsWith('/guardian/') ? 'guardian' :
          route.startsWith('/admin/') ? 'admin' : 'authenticated_or_public');
  const repositories = unique(
    [...source.matchAll(/\b([a-z][A-Za-z0-9]+RepositoryProvider)\b/g)].map((match) => match[1]),
  ).slice(0, 12);
  const rpcNames = unique(
    [...source.matchAll(/\.rpc\(\s*'([^']+)'/g)].map((match) => `rpc:${match[1]}`),
  ).slice(0, 12);
  const tables = unique(
    [...source.matchAll(/\.from\(\s*'([^']+)'/g)].map((match) => `table:${match[1]}`),
  ).slice(0, 12);
  const labels = unique(
    [...source.matchAll(/(?:label|title):\s*(?:const\s+)?'([^']+)'/g)].map((match) => match[1]),
  ).slice(0, 12);
  const coverage = [...tests]
    .filter(([, testSource]) => testSource.includes(route) || testSource.includes(screen))
    .map(([file]) => sourceRelative(file));

  return {
    client: 'flutter_android_authoritative',
    route,
    role,
    screen,
    source: sourceRelative(sourceFile),
    backend_dependency: unique([...repositories, ...rpcNames, ...tables]),
    loading_state: evidence(source, [/MortLoading/, /MortSkeleton/, /ConnectionState\.waiting/]),
    populated_state: evidence(source, [/ListView/, /GridView/, /for \(final /, /snapshot\.data/]),
    empty_state: evidence(source, [/MortEmptyState/, /\.isEmpty/]),
    offline_state: evidence(source, [/offline/i, /SocketException/, /network/i]),
    validation_state: evidence(source, [/validate\(/, /validator:/, /MortCodedError/, /\.trim\(\)\.length/]),
    unauthorized_state: call.includes('GuardedRoute') || call.startsWith('_guarded') ? 'route_guard_detected' : 'public_route',
    recoverable_error_state: evidence(source, [/MortErrorState/, /onRetry/, /Retry/, /catch \(/]),
    success_state: evidence(source, [/MortToast\.show/, /success/i, /completed/i]),
    primary_actions: labels,
    current_test_coverage: coverage.length ? coverage : ['no_direct_static_reference'],
  };
});

const expoRoot = path.join(root, 'app');
const expoRows = walk(expoRoot, (file) => /\.(tsx|ts)$/.test(file) && !file.endsWith('_layout.tsx')).map((file) => {
  const relative = path.relative(expoRoot, file).replaceAll('\\', '/');
  const route = `/${relative.replace(/\.(tsx|ts)$/, '').replace(/\/index$/, '').replaceAll('[', ':').replaceAll(']', '')}`;
  const source = fs.readFileSync(file, 'utf8');
  const role = route.split('/')[1];
  return {
    client: 'expo_reference',
    route: route === '/' ? '/' : route,
    role: ['teen', 'adult', 'guardian', 'admin'].includes(role) ? role : 'mixed',
    screen: path.basename(file),
    source: sourceRelative(file),
    backend_dependency: unique([
      ...[...source.matchAll(/\b([a-z][A-Za-z0-9]+Repository)\b/g)].map((match) => match[1]),
      ...(source.includes('supabase') ? ['supabase_client'] : []),
    ]),
    loading_state: evidence(source, [/loading/i, /ActivityIndicator/]),
    populated_state: evidence(source, [/FlatList/, /\.map\(/, /data/]),
    empty_state: evidence(source, [/EmptyState/, /empty/i]),
    offline_state: evidence(source, [/offline/i, /network/i]),
    validation_state: evidence(source, [/valid/i, /schema/i, /trim\(\)/]),
    unauthorized_state: evidence(source, [/GuardedRoute/, /session/, /role/]),
    recoverable_error_state: evidence(source, [/ErrorBanner/, /retry/i, /catch \(/]),
    success_state: evidence(source, [/success/i, /completed/i]),
    primary_actions: unique(
      [...source.matchAll(/(?:title|label)\s*(?:=|:)\s*(?:const\s+)?(?:\{\s*)?['"]([^'"\r\n<{]+)['"]/g)]
        .map((match) => match[1]),
    ).slice(0, 12),
    current_test_coverage: ['reference_client_not_credited_for_android_completion'],
  };
});

const rows = [...flutterRows, ...expoRows].sort((left, right) =>
  left.client.localeCompare(right.client) || left.route.localeCompare(right.route),
);
fs.mkdirSync(outputRoot, { recursive: true });
fs.writeFileSync(
  path.join(outputRoot, 'MORT_ROUTE_ACTION_INVENTORY_0_9_4.json'),
  `${JSON.stringify({ generated_at: new Date().toISOString(), rows }, null, 2)}\n`,
);

const columns = Object.keys(rows[0]);
const csv = [columns.map(csvCell).join(','), ...rows.map((row) => columns.map((column) => csvCell(row[column])).join(','))];
fs.writeFileSync(path.join(outputRoot, 'MORT_ROUTE_ACTION_INVENTORY_0_9_4.csv'), `${csv.join('\n')}\n`);

const flutterCount = flutterRows.length;
const expoCount = expoRows.length;
const unresolved = flutterRows.filter((row) => row.screen === 'unresolved_builder').length;
const noDirectTests = flutterRows.filter((row) => row.current_test_coverage[0] === 'no_direct_static_reference').length;
const markdown = `# MORT Route and Action Inventory 0.9.4

Generated from application source by \`scripts/build-route-action-inventory.mjs\`.

| Metric | Result |
|---|---:|
| Authoritative Flutter routes | ${flutterCount} |
| Expo reference routes | ${expoCount} |
| Unresolved Flutter builders | ${unresolved} |
| Flutter routes without a direct static test reference | ${noDirectTests} |

State values are static evidence signals, not runtime claims. \`detected\` means the
screen source contains a corresponding state pattern; \`not_detected\` identifies
a review or test gap. Expo routes are retained as a reference client and receive
no duplicate Android completion credit.

The complete row-level inventory is in:

- \`docs/release/MORT_ROUTE_ACTION_INVENTORY_0_9_4.csv\`
- \`docs/release/MORT_ROUTE_ACTION_INVENTORY_0_9_4.json\`
`;
fs.writeFileSync(path.join(outputRoot, 'MORT_ROUTE_ACTION_INVENTORY_0_9_4.md'), markdown);

console.log(JSON.stringify({ flutter_routes: flutterCount, expo_routes: expoCount, unresolved_builders: unresolved, no_direct_tests: noDirectTests }));
