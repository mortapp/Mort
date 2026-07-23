import {
  cleanupQaRestrictedData,
  serviceClient,
  withDatabase,
} from "./feature-qa-helpers.mjs";

if (process.env.MORT_QA_CLEANUP !== "REMOVE_STALE_FEATURE_QA_ONLY") {
  throw new Error("Set MORT_QA_CLEANUP=REMOVE_STALE_FEATURE_QA_ONLY to run guarded QA cleanup.");
}

const staleUsers = [];
for (let page = 1; ; page += 1) {
  const result = await serviceClient.auth.admin.listUsers({ page, perPage: 1000 });
  if (result.error) throw result.error;
  const matches = result.data.users.filter((user) =>
    /^qa-feature-[a-z0-9_-]+-[a-z0-9-]+@mort\.test$/i.test(user.email ?? ""),
  );
  staleUsers.push(...matches);
  if (result.data.users.length < 1000) break;
}

if (staleUsers.length === 0) {
  console.log("Stale feature-QA users found: 0");
} else {
  await cleanupQaRestrictedData(staleUsers.map((user) => user.id));
  let removed = 0;
  for (const user of staleUsers) {
    const result = await serviceClient.auth.admin.deleteUser(user.id, false);
    if (result.error) {
      await withDatabase(async (database) => {
        const deletion = await database.query(
          `delete from auth.users
           where id = $1
             and email ~* '^qa-feature-[a-z0-9_-]+-[a-z0-9-]+@mort\\.test$'`,
          [user.id],
        );
        if (deletion.rowCount !== 1) {
          throw new Error("Guarded fallback did not remove exactly one synthetic feature-QA user.");
        }
      });
    }
    removed += 1;
  }
  console.log(`Stale feature-QA users removed: ${removed}`);
}
