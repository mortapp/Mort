import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import {
  cleanupQaStorageObject,
  cleanupQaUsers,
  withQaCleanup,
} from "./qa-cleanup.mjs";

test("cleanupQaUsers attempts every owned user and rejects restricted, returned, and thrown cleanup errors", async () => {
  const restrictedFailure = new Error("restricted cleanup failed");
  const returnedFailure = new Error("returned delete failure");
  const thrownFailure = new Error("thrown delete failure");
  const deletedIds = [];
  const successLogs = [];

  await assert.rejects(
    cleanupQaUsers({
      users: [
        { id: "adult-id", role: "adult" },
        { id: "teen-id", role: "teen" },
        { id: "guardian-id", role: "guardian" },
        { id: "admin-id", role: "admin" },
      ],
      cleanupRestrictedData: async () => {
        throw restrictedFailure;
      },
      deleteUser: async (id) => {
        deletedIds.push(id);
        if (id === "teen-id") return { error: { code: "user_not_found", message: "User not found" } };
        if (id === "guardian-id") return { error: returnedFailure };
        if (id === "adult-id") throw thrownFailure;
        return { error: null };
      },
      onSuccess: () => successLogs.push("cleanup succeeded"),
    }),
    (error) => {
      assert.equal(error.constructor, AggregateError);
      assert.deepEqual(error.errors, [restrictedFailure, returnedFailure, thrownFailure]);
      return true;
    },
  );

  assert.deepEqual(deletedIds, ["teen-id", "guardian-id", "adult-id", "admin-id"]);
  assert.deepEqual(successLogs, []);
});

test("cleanupQaUsers reports success only after all owned cleanup succeeds", async () => {
  const deletedIds = [];
  const successLogs = [];

  await cleanupQaUsers({
    users: [{ id: "only-id", role: "adult" }],
    cleanupRestrictedData: async (ids) => assert.deepEqual(ids, ["only-id"]),
    deleteUser: async (id) => {
      deletedIds.push(id);
      return { error: null };
    },
    onSuccess: () => successLogs.push("cleanup succeeded"),
  });

  assert.deepEqual(deletedIds, ["only-id"]);
  assert.deepEqual(successLogs, ["cleanup succeeded"]);
});

test("cleanupQaUsers rejects a returned restricted cleanup error after deleting every owned user", async () => {
  const restrictedFailure = new Error("restricted cleanup returned an error");
  const deletedIds = [];

  await assert.rejects(
    cleanupQaUsers({
      users: [{ id: "only-id", role: "adult" }],
      cleanupRestrictedData: async () => ({ error: restrictedFailure }),
      deleteUser: async (id) => {
        deletedIds.push(id);
        return { error: null };
      },
      onSuccess: () => assert.fail("cleanup success must not be reported"),
    }),
    (error) => {
      assert.equal(error.constructor, AggregateError);
      assert.deepEqual(error.errors, [restrictedFailure]);
      return true;
    },
  );

  assert.deepEqual(deletedIds, ["only-id"]);
});

test("withQaUsers wires the existing restricted cleanup function into the injected helper", async () => {
  const source = await readFile(new URL("./feature-qa-helpers.mjs", import.meta.url), "utf8");

  assert.match(source, /cleanupRestrictedData: cleanupQaRestrictedData,/);
});

test("withQaCleanup retains both scenario and cleanup failures", async () => {
  const scenarioFailure = new Error("scenario failed");
  const cleanupFailure = new Error("cleanup failed");

  await assert.rejects(
    withQaCleanup(
      async () => {
        throw scenarioFailure;
      },
      async () => {
        throw cleanupFailure;
      },
    ),
    (error) => {
      assert.equal(error.constructor, AggregateError);
      assert.deepEqual(error.errors, [scenarioFailure, cleanupFailure]);
      return true;
    },
  );
});

test("withQaCleanup removes the exact manifest object after a scenario failure", async () => {
  const scenarioFailure = new Error("post-upload assertion failed");
  const objectPath = "support/qa-run/opaque-object.jpg";
  const removedPaths = [];

  await assert.rejects(
    withQaCleanup(
      async () => {
        throw scenarioFailure;
      },
      async () => cleanupQaStorageObject({
        objectPath,
        remove: async (paths) => {
          removedPaths.push(paths);
          return { error: null };
        },
      }),
    ),
    scenarioFailure,
  );

  assert.deepEqual(removedPaths, [["support/qa-run/opaque-object.jpg"]]);
});

test("cleanupQaStorageObject rejects a returned storage cleanup error", async () => {
  const cleanupFailure = new Error("storage remove failed");

  await assert.rejects(
    cleanupQaStorageObject({
      objectPath: "support/qa-run/opaque-object.jpg",
      remove: async () => ({ error: cleanupFailure }),
    }),
    cleanupFailure,
  );
});
