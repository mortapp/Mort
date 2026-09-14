function isAlreadyMissingUser(error) {
  return error?.code === "user_not_found" || error?.message === "User not found";
}

export async function withQaCleanup(run, cleanup) {
  let scenarioFailed = false;
  let scenarioError;
  let result;

  try {
    result = await run();
  } catch (error) {
    scenarioFailed = true;
    scenarioError = error;
  }

  let cleanupFailed = false;
  let cleanupError;
  try {
    await cleanup();
  } catch (error) {
    cleanupFailed = true;
    cleanupError = error;
  }

  if (scenarioFailed && cleanupFailed) {
    throw new AggregateError([scenarioError, cleanupError], "QA scenario and cleanup both failed");
  }
  if (scenarioFailed) throw scenarioError;
  if (cleanupFailed) throw cleanupError;
  return result;
}

export async function cleanupQaUsers({ users, cleanupRestrictedData, deleteUser, onSuccess }) {
  if (!Array.isArray(users) || users.length === 0) return;

  const cleanupFailures = [];
  try {
    const restrictedResult = await cleanupRestrictedData(users.map((user) => user.id));
    if (restrictedResult?.error) cleanupFailures.push(restrictedResult.error);
  } catch (error) {
    cleanupFailures.push(error);
  }

  const priority = { teen: 0, guardian: 1, adult: 2, admin: 3 };
  const cleanupOrder = [...users].sort(
    (left, right) => (priority[left.role] ?? 9) - (priority[right.role] ?? 9),
  );
  for (const user of cleanupOrder) {
    try {
      const { error } = await deleteUser(user.id);
      if (error && !isAlreadyMissingUser(error)) cleanupFailures.push(error);
    } catch (error) {
      if (!isAlreadyMissingUser(error)) cleanupFailures.push(error);
    }
  }

  if (cleanupFailures.length > 0) {
    throw new AggregateError(cleanupFailures, "QA cleanup failed");
  }
  onSuccess();
}

export async function cleanupQaStorageObject({ objectPath, remove }) {
  const { error } = await remove([objectPath]);
  if (error) throw error;
}
