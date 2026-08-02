import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { parse as parseYaml } from "yaml";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const flutterRoot = join(root, "flutter_mort");
const outputDirectory = join(root, "artifacts", "release-0.9.12+102");
mkdirSync(outputDirectory, { recursive: true });

const executable = (name) => {
  if (process.platform !== "win32") return name;
  return name === "pnpm" ? "pnpm.cmd" : `${name}.bat`;
};

const flutterGraph = JSON.parse(
  execFileSync(executable("flutter"), ["pub", "deps", "--json"], {
    cwd: flutterRoot,
    encoding: "utf8",
    maxBuffer: 32 * 1024 * 1024,
    shell: process.platform === "win32",
  }),
);
const pnpmLock = parseYaml(readFileSync(join(root, "pnpm-lock.yaml"), "utf8"));

const components = new Map();
for (const dependency of flutterGraph.packages ?? []) {
  if (!dependency.name || !dependency.version) continue;
  const key = `pub:${dependency.name}@${dependency.version}`;
  components.set(key, {
    type: "library",
    group: "pub.dev",
    name: dependency.name,
    version: dependency.version,
    purl: `pkg:pub/${encodeURIComponent(dependency.name)}@${encodeURIComponent(dependency.version)}`,
    properties: [
      { name: "mort:ecosystem", value: "flutter" },
      { name: "mort:dependencyKind", value: dependency.kind ?? "unknown" },
    ],
  });
}

for (const packageKey of Object.keys(pnpmLock.packages ?? {})) {
  const separator = packageKey.lastIndexOf("@");
  if (separator <= 0) continue;
  const name = packageKey.slice(0, separator);
  const version = packageKey.slice(separator + 1).replace(/\(.+$/, "");
  if (!name || !version) continue;
  const key = `npm:${name}@${version}`;
  components.set(key, {
    type: "library",
    group: name.startsWith("@") ? name.split("/")[0] : "npm",
    name,
    version,
    purl: `pkg:npm/${encodeURIComponent(name)}@${encodeURIComponent(version)}`,
    properties: [
      { name: "mort:ecosystem", value: "pnpm" },
      { name: "mort:inventorySource", value: "pnpm-lock.yaml" },
    ],
  });
}

const pubspec = readFileSync(join(flutterRoot, "pubspec.yaml"), "utf8");
const version = pubspec.match(/^version:\s*([^\s]+)$/m)?.[1] ?? "unknown";
const sbom = {
  bomFormat: "CycloneDX",
  specVersion: "1.5",
  serialNumber: `urn:uuid:${crypto.randomUUID()}`,
  version: 1,
  metadata: {
    timestamp: new Date().toISOString(),
    component: {
      type: "application",
      name: "MORT",
      version,
      properties: [
        { name: "mort:releaseProfile", value: "closed_test" },
        { name: "mort:publicMarketplace", value: "disabled" },
      ],
    },
  },
  components: [...components.values()].sort((left, right) =>
    `${left.group}/${left.name}`.localeCompare(`${right.group}/${right.name}`),
  ),
};

const outputPath = join(outputDirectory, "MORT_SBOM.cdx.json");
writeFileSync(outputPath, `${JSON.stringify(sbom, null, 2)}\n`, "utf8");
console.log(
  `[release-sbom] Wrote ${sbom.components.length} dependency components to ${outputPath}`,
);
