import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const repositoryPath = new URL(
  "../flutter_mort/lib/data/repositories/notifications_repository.dart",
  import.meta.url,
);
const source = readFileSync(repositoryPath, "utf8");

function methodBody(name, nextMethodName) {
  const signature = source.indexOf(`${name}(`);
  const start = source.indexOf("{", signature);
  const end = source.indexOf(`${nextMethodName}(`, start + 1);
  assert.notEqual(signature, -1, `Missing ${name} repository method.`);
  assert.notEqual(end, -1, `Could not delimit ${name} repository method.`);
  return source.slice(start, end);
}

const listMine = methodBody("listMine", "markRead");
const markAllRead = methodBody("markAllRead", "getPreferences");

assert.match(
  listMine,
  /\.eq\('user_id',\s*requireUserId\(\)\)/,
  "The inbox query must scope rows using the live notifications.user_id owner column.",
);
assert.match(
  markAllRead,
  /\.eq\('user_id',\s*requireUserId\(\)\)/,
  "Mark-all-read must scope updates using the live notifications.user_id owner column.",
);
assert.doesNotMatch(
  `${listMine}\n${markAllRead}`,
  /recipient_id/,
  "The Flutter inbox must not reference the retired notifications.recipient_id column.",
);

console.log("Notification inbox owner-column contract passed.");
