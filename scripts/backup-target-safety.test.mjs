import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { resolveBackupTarget } from "./backup-target-guard.mjs";

const dataExporter = readFileSync(new URL("./backup-feature-data.mjs", import.meta.url), "utf8");
const schemaExporter = readFileSync(new URL("./backup-feature-schema.mjs", import.meta.url), "utf8");
const deletedProjectRef = "rakjydmgwwgtdislanbt";
const backupTargetGuard = readFileSync(new URL("./backup-target-guard.mjs", import.meta.url), "utf8");

test("legacy plaintext data exporter is retired before any database import or connection", () => {
  assert.match(dataExporter, /retired/i);
  assert.doesNotMatch(dataExporter, /from ["']pg["']/);
  assert.doesNotMatch(dataExporter, /\.connect\s*\(/);
  assert.doesNotMatch(dataExporter, new RegExp(deletedProjectRef));
});

test("metadata exporter resolves the guarded production ref before constructing a client", () => {
  assert.doesNotMatch(schemaExporter, new RegExp(deletedProjectRef));
  const targetGuard = schemaExporter.indexOf("MORT_BACKUP_PROJECT_REF");
  const databaseClient = schemaExporter.indexOf("new pg.Client");
  assert.ok(targetGuard >= 0, "metadata exporter must validate MORT_BACKUP_PROJECT_REF");
  assert.ok(databaseClient > targetGuard, "target validation must happen before the network client is constructed");
  assert.match(backupTargetGuard, /jxbnrkasktbhtiujkhay/);
});

test("metadata row-count query references relations present in the active production schema", () => {
  const countsQuery = schemaExporter.match(/featureRowCounts:\s*`([\s\S]*?)`/i)?.[1];
  assert.ok(countsQuery, "expected the metadata snapshot to include row-count evidence");
  for (const relation of ["profiles", "guardian_links", "jobs", "job_applications", "notifications"]) {
    assert.match(countsQuery, new RegExp(`public\\.${relation}\\b`));
  }
  for (const removedRelation of ["teen_profiles", "guardian_connections", "applications"]) {
    assert.doesNotMatch(countsQuery, new RegExp(`public\\.${removedRelation}\\b`));
  }
});

test("backup target defaults to and accepts only the authoritative production reference", () => {
  assert.equal(resolveBackupTarget("jxbnrkasktbhtiujkhay"), "jxbnrkasktbhtiujkhay");
  assert.equal(resolveBackupTarget(undefined), "jxbnrkasktbhtiujkhay");
  assert.equal(resolveBackupTarget("  "), "jxbnrkasktbhtiujkhay");
  assert.throws(() => resolveBackupTarget("some-other-project"), /authoritative production project/);
  assert.throws(() => resolveBackupTarget(deletedProjectRef), /authoritative production project/);
});
