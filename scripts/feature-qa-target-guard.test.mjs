import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import { assertFeatureQaTarget, isLoopbackHost } from "./feature-qa-target-guard.mjs";

const QA_REF = "ckcxakhxqlkhppsxxjhv";

test("hosted QA accepts only the QA API and QA database hosts", () => {
  assert.equal(assertFeatureQaTarget({
    projectRef: QA_REF,
    supabaseUrl: `https://${QA_REF}.supabase.co`,
    dbUrl: `postgresql://postgres:placeholder@db.${QA_REF}.supabase.co:5432/postgres`,
    localQa: false,
  }), "hosted_qa");
});

test("hosted QA rejects a production database URL even with a QA API URL", () => {
  assert.throws(() => assertFeatureQaTarget({
    projectRef: QA_REF,
    supabaseUrl: `https://${QA_REF}.supabase.co`,
    dbUrl: "postgresql://postgres:placeholder@db.jxbnrkasktbhtiujkhay.supabase.co:5432/postgres",
    localQa: false,
  }), /database host must match the isolated QA project/);
});

test("hosted QA rejects a database URL query parameter that overrides the QA hostname", () => {
  assert.throws(() => assertFeatureQaTarget({
    projectRef: QA_REF,
    supabaseUrl: `https://${QA_REF}.supabase.co`,
    dbUrl: `postgresql://postgres:placeholder@db.${QA_REF}.supabase.co:5432/postgres?host=db.jxbnrkasktbhtiujkhay.supabase.co`,
    localQa: false,
  }), /database connection URL cannot override its host/);
});

test("hosted QA rejects a loopback DB URL because it would mix environments", () => {
  assert.throws(() => assertFeatureQaTarget({
    projectRef: QA_REF,
    supabaseUrl: `https://${QA_REF}.supabase.co`,
    dbUrl: "postgresql://postgres:placeholder@127.0.0.1:54322/postgres",
    localQa: false,
  }), /database host must match the isolated QA project/);
});

test("hosted QA rejects a mismatched API project reference", () => {
  assert.throws(() => assertFeatureQaTarget({
    projectRef: "jxbnrkasktbhtiujkhay",
    supabaseUrl: `https://${QA_REF}.supabase.co`,
    dbUrl: null,
    localQa: false,
  }), /hosted feature QA requires the isolated QA project/);
});

test("a QA ref override cannot authorize a production API URL", () => {
  assert.throws(() => assertFeatureQaTarget({
    projectRef: QA_REF,
    supabaseUrl: "https://jxbnrkasktbhtiujkhay.supabase.co",
    dbUrl: null,
    localQa: false,
  }), /hosted feature QA requires the isolated QA project/);
});

test("explicit local QA requires both API and database endpoints to be loopback", () => {
  assert.equal(assertFeatureQaTarget({
    projectRef: "127",
    supabaseUrl: "http://127.0.0.1:54321",
    dbUrl: "postgresql://postgres:placeholder@127.0.0.1:54322/postgres",
    localQa: true,
  }), "local_qa");
});

test("explicit local QA accepts IPv6 loopback endpoints", () => {
  assert.equal(assertFeatureQaTarget({
    projectRef: "::1",
    supabaseUrl: "http://[::1]:54321",
    dbUrl: "postgresql://postgres:placeholder@[::1]:54322/postgres",
    localQa: true,
  }), "local_qa");
});

test("database TLS detection treats bracketed IPv6 loopback as local", () => {
  assert.equal(isLoopbackHost(new URL("postgresql://user:pass@[::1]:54322/postgres").hostname), true);
  assert.equal(isLoopbackHost("db.ckcxakhxqlkhppsxxjhv.supabase.co"), false);
});

test("the local override rejects a hosted production API endpoint", () => {
  assert.throws(() => assertFeatureQaTarget({
    projectRef: "jxbnrkasktbhtiujkhay",
    supabaseUrl: "https://jxbnrkasktbhtiujkhay.supabase.co",
    dbUrl: "postgresql://postgres:placeholder@127.0.0.1:54322/postgres",
    localQa: true,
  }), /local QA requires loopback API and database endpoints/);
});

test("the local override rejects a hosted database endpoint", () => {
  assert.throws(() => assertFeatureQaTarget({
    projectRef: "127",
    supabaseUrl: "http://127.0.0.1:54321",
    dbUrl: `postgresql://postgres:placeholder@db.${QA_REF}.supabase.co:5432/postgres`,
    localQa: true,
  }), /local QA requires loopback API and database endpoints/);
});

test("the local override rejects an implicit remote database fallback", () => {
  assert.throws(() => assertFeatureQaTarget({
    projectRef: "127",
    supabaseUrl: "http://127.0.0.1:54321",
    dbUrl: "",
    localQa: true,
  }), /local QA requires loopback API and database endpoints/);
});

test("account-deletion database QA entrypoints enforce the shared target guard", () => {
  for (const file of ["qa-account-deletion-fk-contract.mjs", "qa-account-deletion-functional.mjs"]) {
    const source = readFileSync(new URL(`./${file}`, import.meta.url), "utf8");
    assert.match(source, /assertFeatureQaTarget/);
  }
});

test("retired remote-target utilities fail closed before running legacy code", () => {
  for (const file of [
    "audit-historical-qa-accounts-0.9.4.mjs",
    "build-play-policy-package.mjs",
    "create-old-project-test-users.mjs",
    "create-play-review-fixtures.mjs",
    "generate-security-warning-reconciliation.mjs",
    "qa-account-deletion-processor.mjs",
    "qa-old-project-smoke.mjs",
    "qa-old-project-rls.mjs",
  ]) {
    const source = readFileSync(new URL(`./${file}`, import.meta.url), "utf8");
    assert.match(source, /^throw new Error\("Disabled:/);
  }
  const packageScript = readFileSync(new URL("./package-final-play-production-pilot.ps1", import.meta.url), "utf8");
  assert.match(packageScript, /^throw "Disabled:/);
  const playReviewJs = readFileSync(new URL("./create-play-review-tenant.mjs", import.meta.url), "utf8");
  const playReviewPs = readFileSync(new URL("./run-play-review-fixtures.ps1", import.meta.url), "utf8");
  assert.match(playReviewJs, /^throw new Error\("Disabled:/);
  assert.match(playReviewPs, /^throw "Disabled:/);
  const regressionRunner = readFileSync(new URL("./run-final-supabase-regression.ps1", import.meta.url), "utf8");
  assert.doesNotMatch(regressionRunner, /qa-old-project-smoke\.mjs/);
  const packageJson = readFileSync(new URL("../package.json", import.meta.url), "utf8");
  assert.doesNotMatch(packageJson, /qa:old-project-(?:smoke|rls)/);
});
