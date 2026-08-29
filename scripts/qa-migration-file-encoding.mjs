import { readdir, readFile } from "node:fs/promises";
import { resolve } from "node:path";

const migrationsDirectory = resolve(import.meta.dirname, "..", "supabase", "migrations");
const migrationFiles = (await readdir(migrationsDirectory))
  .filter((name) => name.endsWith(".sql"))
  .sort();

const failures = [];
for (const name of migrationFiles) {
  const bytes = await readFile(resolve(migrationsDirectory, name));
  if (bytes.length >= 3 && bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) {
    failures.push(`${name}: UTF-8 byte-order mark is not accepted by local migration replay`);
  }
}

if (failures.length > 0) {
  throw new Error(`Migration encoding contract failed:\n${failures.join("\n")}`);
}

console.log(`[qa-migration-file-encoding] PASS: ${migrationFiles.length} SQL migrations are UTF-8 without BOM.`);
