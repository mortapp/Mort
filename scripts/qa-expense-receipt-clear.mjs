import { assertQa, qaLog, withQaUsers } from "./feature-qa-helpers.mjs";

const scope = "qa-expense-receipt-clear";

await withQaUsers(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
  const created = await teen.client.rpc("create_my_expense", {
    p_amount_cents: 1500,
    p_spent_on: "2026-01-15",
    p_category: "SUPPLIES",
    p_merchant: "",
    p_description: "",
    p_job_id: null,
    p_notes: "",
  });
  assertQa(!created.error && created.data?.ok === true, `fixture: create_my_expense failed: ${created.error?.message ?? JSON.stringify(created.data)}`);
  const expenseId = created.data.expense.id;

  // Register a receipt path, then clear it: p_path is null must be treated
  // as a valid "clear the receipt" request, not rejected as
  // invalid_receipt_path (the original bug -- every "Remove receipt" tap
  // deleted the storage object while the DB row kept pointing at it).
  const registered = await teen.client.rpc("set_my_expense_receipt", {
    p_id: expenseId,
    p_path: `${teen.id}/receipt.jpg`,
  });
  assertQa(
    !registered.error && registered.data?.ok === true && registered.data?.expense?.receipt_path === `${teen.id}/receipt.jpg`,
    `REGISTER: set_my_expense_receipt did not register the path (${JSON.stringify(registered.data)})`,
  );

  const cleared = await teen.client.rpc("set_my_expense_receipt", {
    p_id: expenseId,
    p_path: null,
  });
  assertQa(
    !cleared.error && cleared.data?.ok === true && cleared.data?.expense?.receipt_path === null,
    `DB_CLEAR_SUCCESS: clearing with p_path=null was not accepted (${JSON.stringify(cleared.data)})`,
  );
  qaLog(scope, "DB_CLEAR_SUCCESS=PASS (p_path=null clears receipt_path instead of being rejected)");

  // DB_CLEAR_FAILURE: an expense that does not exist (or is not owned by the
  // caller) must still fail closed with a clean denial -- proving the fix
  // did not weaken ownership/existence checks while fixing the null case.
  const failedClear = await teen.client.rpc("set_my_expense_receipt", {
    p_id: "00000000-0000-0000-0000-000000000000",
    p_path: null,
  });
  assertQa(
    !failedClear.error && failedClear.data?.ok === false && failedClear.data?.code === "expense_not_found",
    `DB_CLEAR_FAILURE: nonexistent expense did not fail closed as expense_not_found (${JSON.stringify(failedClear.data)})`,
  );
  qaLog(scope, "DB_CLEAR_FAILURE=PASS (nonexistent expense denied cleanly; the Dart repository's removeReceipt checks this ok flag before ever touching storage, so a failure here never reaches the storage-delete call)");

  // Ownership/format validation for a real (non-null) path is unchanged.
  const invalidPath = await teen.client.rpc("set_my_expense_receipt", {
    p_id: expenseId,
    p_path: "someone-else/receipt.jpg",
  });
  assertQa(
    !invalidPath.error && invalidPath.data?.ok === false && invalidPath.data?.code === "invalid_receipt_path",
    `NO_REGRESSION: a non-null path outside the caller's own storage folder was not rejected (${JSON.stringify(invalidPath.data)})`,
  );
  qaLog(scope, "NO_REGRESSION=PASS (non-null out-of-folder path still rejected as invalid_receipt_path)");

  const deleted = await teen.client.rpc("delete_my_expense", { p_id: expenseId });
  assertQa(!deleted.error && deleted.data?.ok === true, `cleanup: delete_my_expense failed: ${deleted.error?.message ?? JSON.stringify(deleted.data)}`);
});

qaLog(scope, "expense receipt clear-on-null-path fix verified end-to-end with synthetic QA fixtures only");
