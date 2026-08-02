import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(fileURLToPath(new URL("..", import.meta.url)));
const outputPath = resolve(
  root,
  "docs/MORT_PRODUCTION_READINESS_CHANGED_FILES_0_9_7.md",
);
const raw = execFileSync(
  "git",
  ["-C", root, "status", "--porcelain=v1", "-z"],
  { encoding: "utf8" },
);
const entries = raw
  .split("\0")
  .filter(Boolean)
  .map((entry) => ({ status: entry.slice(0, 2), path: entry.slice(3) }));

if (!entries.some((entry) => entry.path === "docs/MORT_PRODUCTION_READINESS_CHANGED_FILES_0_9_7.md")) {
  entries.push({
    status: "??",
    path: "docs/MORT_PRODUCTION_READINESS_CHANGED_FILES_0_9_7.md",
  });
}
entries.sort((left, right) => left.path.localeCompare(right.path));

const lines = [
  "# MORT Production Readiness Changed Files 0.9.7",
  "",
  "Generated: 2026-07-28",
  "",
  "This is the exact final worktree delta relative to commit `f566885453786f1fbdea08291b1b646a5cabe1bc`. The branch began with an intentionally dirty rose-gold redesign/reviewer tree, so this inventory includes those attributed pre-existing changes as well as the production-readiness remediation. No pre-existing change was reset or discarded.",
  "",
  `Total paths: ${entries.length}`,
  "",
  "| Git status | Path |",
  "|---|---|",
  ...entries.map(({ status, path }) => `| \`${status}\` | \`${path.replaceAll("|", "\\|")}\` |`),
  "",
];

writeFileSync(outputPath, `${lines.join("\n")}\n`, "utf8");
console.log(`CHANGED_FILE_REPORT=${outputPath}`);
console.log(`CHANGED_FILE_COUNT=${entries.length}`);
