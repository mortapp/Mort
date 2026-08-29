import { readFile, readdir, stat } from "node:fs/promises";
import { relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));

const scannedRoots = [
  "flutter_mort/lib/features",
  "flutter_mort/lib/core/routing",
  "flutter_mort/assets",
  "app",
  "components",
  "web/public",
  "assets",
];

const scannedFiles = [
  "docs/play/MORT_PLAY_FULL_DESCRIPTION.txt",
  "docs/play/MORT_PLAY_RELEASE_NOTES.txt",
  "docs/play/MORT_PLAY_SHORT_DESCRIPTION.txt",
  "flutter_mort/lib/data/repositories/profile_repository.dart",
  "scripts/build-public-legal-site.mjs",
  "app.config.ts",
];

const extensions = new Set([
  ".arb",
  ".css",
  ".dart",
  ".html",
  ".js",
  ".json",
  ".md",
  ".mjs",
  ".svg",
  ".ts",
  ".tsx",
  ".txt",
  ".yaml",
  ".yml",
]);

const forbidden = [
  ["closed pilot", /closed[-_ ]?pilot/giu],
  ["closed test", /closed[-_ ]?test(?:ing)?/giu],
  ["closed beta", /closed[-_ ]?beta/giu],
  ["MORT beta", /\bmort\s+beta\b/giu],
  ["MORT alpha", /\bmort\s+alpha\b/giu],
  ["beta tester", /\bbeta\s+(?:tester|user)\b/giu],
  ["alpha program", /\balpha\s+program\b/giu],
  ["free pilot", /\bfree\s+pilot\b/giu],
  ["pilot identity", /\bpilot\s+(?:job|user|marketplace|participant|guardian|notification|safety|rules?|release|access|review)\b/giu],
  ["pilot route/policy", /\bpilot\s+(?:route|policy|approval|eligibility|enrollment|workflow)\b/giu],
  ["during/after pilot", /\b(?:during|after)\s+the\s+pilot\b/giu],
  ["approved participants", /\bapproved\s+participants(?:\s+only)?\b/giu],
  ["test participant", /\btest\s+participant\b/giu],
  ["tester-only", /\btester[- ]only\b/giu],
  ["test build/application/version", /\btest(?:ing)?\s+(?:build|application|version)\b/giu],
  ["server-controlled access", /\bserver[- ]controlled\s+access\b/giu],
  ["public-release approved", /\bpublic[- ]release\s+approved\b/giu],
  ["public marketplace closed", /\bpublic\s+marketplace(?:\s+access\s+remains)?\s+closed\b/giu],
  ["real ID collection disabled", /\breal\s+id\s+collection\s+disabled\b/giu],
  ["payments disabled", /\bpayments\s+disabled\b/giu],
];

async function exists(path) {
  try {
    await stat(path);
    return true;
  } catch {
    return false;
  }
}

function extensionOf(path) {
  const match = path.match(/\.[^.\\/]+$/u);
  return match?.[0]?.toLowerCase() ?? "";
}

async function collect(path, output) {
  if (!(await exists(path))) return;
  const info = await stat(path);
  if (info.isFile()) {
    if (extensions.has(extensionOf(path))) output.push(path);
    return;
  }
  for (const entry of await readdir(path, { withFileTypes: true })) {
    if ([".dart_tool", ".expo", "build", "generated", "node_modules"].includes(entry.name)) continue;
    await collect(resolve(path, entry.name), output);
  }
}

const files = [];
for (const path of [...scannedRoots, ...scannedFiles]) {
  await collect(resolve(root, path), files);
}

const findings = [];
for (const path of [...new Set(files)].sort()) {
  const source = await readFile(path, "utf8");
  const lines = source.split(/\r?\n/u);
  for (let index = 0; index < lines.length; index += 1) {
    for (const [label, pattern] of forbidden) {
      pattern.lastIndex = 0;
      if (pattern.test(lines[index])) {
        findings.push({
          file: relative(root, path).replaceAll("\\", "/"),
          line: index + 1,
          label,
        });
      }
    }
  }
}

const appConfigSource = await readFile(
  resolve(root, "flutter_mort/lib/core/config/app_config.dart"),
  "utf8",
);
if (/['"]Closed Pilot['"]/u.test(appConfigSource)) {
  findings.push({
    file: "flutter_mort/lib/core/config/app_config.dart",
    line: appConfigSource.slice(0, appConfigSource.search(/['"]Closed Pilot['"]/u)).split(/\r?\n/u).length,
    label: "user-facing release label",
  });
}

const playPackageSource = await readFile(
  resolve(root, "scripts/build-play-policy-package.mjs"),
  "utf8",
);
for (const outputPath of [
  "docs/play/MORT_PLAY_SHORT_DESCRIPTION.txt",
  "docs/play/MORT_PLAY_FULL_DESCRIPTION.txt",
  "docs/play/MORT_PLAY_RELEASE_NOTES.txt",
]) {
  const marker = `write('${outputPath}',`;
  const start = playPackageSource.indexOf(marker);
  if (start < 0) throw new Error(`Missing public metadata source block for ${outputPath}`);
  const end = playPackageSource.indexOf("\nwrite(", start + marker.length);
  const sourceBlock = playPackageSource.slice(start, end < 0 ? undefined : end);
  const sourceLine = playPackageSource.slice(0, start).split(/\r?\n/u).length;
  for (const [offset, line] of sourceBlock.split(/\r?\n/u).entries()) {
    for (const [label, pattern] of forbidden) {
      pattern.lastIndex = 0;
      if (pattern.test(line)) {
        findings.push({
          file: "scripts/build-play-policy-package.mjs",
          line: sourceLine + offset,
          label: `public metadata: ${label}`,
        });
      }
    }
  }
}

if (findings.length > 0) {
  console.error(`Production identity copy contract found ${findings.length} forbidden shipping occurrence(s):`);
  for (const finding of findings) {
    console.error(`- ${finding.file}:${finding.line} [${finding.label}]`);
  }
  process.exitCode = 1;
} else {
  console.log(`PASS: ${files.length} shipping user-facing source files contain no closed-test product identity.`);
}
