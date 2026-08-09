import fs from "node:fs";
import path from "node:path";

const scope = "qa-route-actions";
const root = path.resolve(import.meta.dirname, "..");
const libRoot = path.join(root, "flutter_mort", "lib");
const routerPath = path.join(libRoot, "core", "routing", "app_router.dart");

function walk(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(full) : [full];
  });
}

function extractCall(source, start) {
  const open = source.indexOf("(", start);
  let depth = 0;
  let quote = null;
  let escaped = false;
  for (let index = open; index < source.length; index += 1) {
    const char = source[index];
    if (quote) {
      if (escaped) escaped = false;
      else if (char === "\\") escaped = true;
      else if (char === quote) quote = null;
      continue;
    }
    if (char === "'" || char === '"') {
      quote = char;
      continue;
    }
    if (char === "(") depth += 1;
    if (char === ")" && --depth === 0) return source.slice(start, index + 1);
  }
  throw new Error(`Unbalanced call at source offset ${start}.`);
}

function lineNumber(source, offset) {
  return source.slice(0, offset).split("\n").length;
}

function normalizeTarget(value) {
  return value
    .split(/[?#]/, 1)[0]
    .replaceAll(/\$\{[^}]+\}/g, ":value")
    .replaceAll(/\$[A-Za-z_][A-Za-z0-9_]*/g, ":value")
    .replaceAll(/\/+$/g, "") || "/";
}

function routeMatches(pattern, target) {
  const patternParts = pattern.split("/").filter(Boolean);
  const targetParts = target.split("/").filter(Boolean);
  if (patternParts.length !== targetParts.length) return false;
  return patternParts.every(
    (part, index) =>
      part.startsWith(":") ||
      targetParts[index].startsWith(":") ||
      part === targetParts[index],
  );
}

const router = fs.readFileSync(routerPath, "utf8");
const routePatterns = new Set();

for (const match of router.matchAll(/\b(?:GoRoute|_guarded|_reviewer)\s*\(/g)) {
  const call = extractCall(router, match.index);
  const direct = call.startsWith("GoRoute")
    ? call.match(/\bpath:\s*'([^']+)'/s)?.[1]
    : call.match(/^\w+\s*\(\s*'([^']+)'/s)?.[1];
  if (!direct) continue;
  if (direct.startsWith("/")) routePatterns.add(direct);

  if (direct.startsWith("/") && call.startsWith("GoRoute")) {
    for (const child of call.matchAll(/\bpath:\s*'([^']+)'/g)) {
      const childPath = child[1];
      if (childPath !== direct && !childPath.startsWith("/")) {
        routePatterns.add(`${direct}/${childPath}`.replaceAll("//", "/"));
      }
    }
  }
}

const failures = [];
const navigationTargets = new Map();
const dartFiles = walk(libRoot).filter((file) => file.endsWith(".dart"));
const actionTypes = [
  ["MortButton", "onPressed"],
  ["MortGlassButton", "onPressed"],
  ["MortIconButton", "onPressed"],
  ["MortAction", "route_or_onPressed"],
  ["IconButton", "onPressed"],
  ["TextButton", "onPressed"],
  ["ElevatedButton", "onPressed"],
  ["OutlinedButton", "onPressed"],
  ["FilledButton", "onPressed"],
];

for (const file of dartFiles) {
  const source = fs.readFileSync(file, "utf8");
  const relative = path.relative(root, file).replaceAll("\\", "/");

  for (const [type, handler] of actionTypes) {
    const pattern = new RegExp(`\\b${type}\\s*\\(`, "g");
    for (const match of source.matchAll(pattern)) {
      const call = extractCall(source, match.index);
      if (call.startsWith(`${type}({`)) continue;
      const intentionalDisabled =
        call.includes("style: MortButtonStyle.disabled") ||
        /\benabled\s*:\s*false\b/.test(call);
      const hasHandler =
        handler === "route_or_onPressed"
          ? /\b(?:route|onPressed)\s*:/.test(call)
          : new RegExp(`\\b${handler}\\s*:`).test(call);
      if (!hasHandler && !intentionalDisabled) {
        failures.push(
          `${relative}:${lineNumber(source, match.index)} ${type} has no action handler`,
        );
      }
      if (/\b(?:onPressed|onTap)\s*:\s*\([^)]*\)\s*=>?\s*\{\s*\}/s.test(call)) {
        failures.push(
          `${relative}:${lineNumber(source, match.index)} ${type} has a no-op handler`,
        );
      }
      if (/\bonPressed\s*:\s*null\b/.test(call)) {
        if (!intentionalDisabled) {
          failures.push(
            `${relative}:${lineNumber(source, match.index)} ${type} is permanently inert`,
          );
        }
      }
    }
  }

  for (const match of source.matchAll(
    /\b(?:route|navigationRoute)\s*:\s*'((?:\$\{[^}]*\}|\\'|[^'])+)'/g,
  )) {
    if (!match[1].startsWith("/")) continue;
    const target = normalizeTarget(match[1]);
    navigationTargets.set(`${relative}:${lineNumber(source, match.index)}`, target);
  }
  for (const match of source.matchAll(
    /\bcontext\.(?:go|push|pushReplacement)\s*\(\s*'((?:\$\{[^}]*\}|\\'|[^'])+)'/g,
  )) {
    if (!match[1].startsWith("/")) continue;
    const target = normalizeTarget(match[1]);
    navigationTargets.set(`${relative}:${lineNumber(source, match.index)}`, target);
  }
}

for (const [location, target] of navigationTargets) {
  if (![...routePatterns].some((pattern) => routeMatches(pattern, target))) {
    failures.push(`${location} targets unregistered route ${target}`);
  }
}

if (failures.length > 0) {
  console.error(failures.join("\n"));
  process.exitCode = 1;
} else {
  console.log(
    JSON.stringify({
      status: "PASS",
      flutter_files_scanned: dartFiles.length,
      registered_route_patterns: routePatterns.size,
      static_navigation_targets: navigationTargets.size,
      action_widget_types: actionTypes.length,
    }),
  );
}
