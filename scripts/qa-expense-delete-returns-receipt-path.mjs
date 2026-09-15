import { assertQa, qaLog, withQaUsers } from "./feature-qa-helpers.mjs";

const scope = "qa-expense-delete-returns-receipt-path";

await withQaUsers(
  scope,
  [
    { key: "teen", role: "teen" },
    { key: "otherTeen", role: "teen" },
  ],
  async ({ teen, otherTeen }) => {
    const created = await teen.client.rpc("create_my_expense", {
      p_amount_cents: 2500,
      p_spent_on: "2026-01-15",
      p_category: "SUPPLIES",
      p_merchant: "",
      p_description: "",
      p_job_id: null,
      p_notes: "",
    });
    assertQa(!created.error && created.data?.ok === true, `fixture: create_my_expense failed: ${created.error?.message ?? JSON.stringify(created.data)}`);
    const expenseId = created.data.expense.id;

    const wrongUserAttempt = await otherTeen.client.rpc("delete_my_expense", { p_id: expenseId });
    assertQa(
      !wrongUserAttempt.error && wrongUserAttempt.data?.ok === false && wrongUserAttempt.data?.code === "expense_not_found",
      `WRONG_USER_DENIED: a different real user was able to delete someone else's expense (${JSON.stringify(wrongUserAttempt.data)})`,
    );
    const stillExists = await teen.client.rpc("list_my_expenses", { p_year: 2026 });
    assertQa(
      !stillExists.error && stillExists.data?.ok === true && (stillExists.data.expenses ?? []).some((e) => e.id === expenseId),
      "WRONG_USER_DENIED: the expense was removed even though the delete attempt was denied",
    );
    qaLog(scope, "WRONG_USER_DENIED=PASS (a different real user cannot delete another user's expense; the row is untouched)");

    const receiptPath = `${teen.id}/delete-cleanup-receipt.jpg`;
    const registered = await teen.client.rpc("set_my_expense_receipt", {
      p_id: expenseId,
      p_path: receiptPath,
    });
    assertQa(!registered.error && registered.data?.ok === true, `fixture: set_my_expense_receipt failed: ${registered.error?.message ?? JSON.stringify(registered.data)}`);

    // The bug: delete_my_expense used to return only {ok:true}, giving the
    // Dart repository nothing to clean up in storage even though the
    // confirmation dialog promises attached receipts are also removed.
    const deleted = await teen.client.rpc("delete_my_expense", { p_id: expenseId });
    assertQa(
      !deleted.error && deleted.data?.ok === true && deleted.data?.receipt_path === receiptPath,
      `DELETE_RETURNS_RECEIPT_PATH: delete_my_expense did not return the deleted row's receipt_path (${JSON.stringify(deleted.data)}) -- the Dart repository has nothing to pass to storage.remove()`,
    );
    qaLog(scope, "DELETE_RETURNS_RECEIPT_PATH=PASS (deleting an expense with a receipt returns its receipt_path for client-side storage cleanup)");

    const deletedAgain = await teen.client.rpc("delete_my_expense", { p_id: expenseId });
    assertQa(
      !deletedAgain.error && deletedAgain.data?.ok === false && deletedAgain.data?.code === "expense_not_found",
      `NO_REGRESSION: deleting an already-deleted expense did not fail closed (${JSON.stringify(deletedAgain.data)})`,
    );
    qaLog(scope, "NO_REGRESSION=PASS (deleting a nonexistent/already-deleted expense still fails closed as expense_not_found)");
  },
);

qaLog(scope, "delete_my_expense receipt-path-for-cleanup fix verified end-to-end with synthetic QA fixtures only");
