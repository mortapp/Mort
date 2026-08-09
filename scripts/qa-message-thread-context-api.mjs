import { createClient } from "@supabase/supabase-js";

import {
  anonKey,
  assertQa,
  qaLog,
  saveJob,
  sendSafeMessage,
  supabaseUrl,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-message-thread-context-api";

function expectOk(result, action) {
  assertQa(!result.error, `${action} failed: ${result.error?.message}`);
  return result.data;
}

await withQaUsers(
  scope,
  [
    { key: "teen", role: "teen" },
    { key: "adult", role: "adult" },
    { key: "outsider", role: "adult" },
  ],
  async ({ teen, adult, outsider }) => {
    const title = "QA Hosted Message Context";
    const created = await saveJob(adult.client, { title });
    assertQa(created.result?.ok === true, "could not publish the QA job");

    const submitted = expectOk(
      await teen.client.rpc("submit_job_application", {
        p_job_id: created.result.job.id,
        p_note: "I can complete this in the staffed public work area.",
        p_availability_confirmed: true,
        p_portfolio_ids: [],
      }),
      "submit application",
    );
    const applicationId = submitted.application.id;
    const thread = expectOk(
      await teen.client
        .from("message_threads")
        .select("id")
        .eq("application_id", applicationId)
        .single(),
      "load server-created thread",
    );

    const sent = expectOk(
      await sendSafeMessage(
        adult.client,
        thread.id,
        "The staffed public desk is ready for our scheduled check-in.",
      ),
      "send safe message",
    );
    assertQa(sent.scanner_status !== "blocked", "safe QA message was blocked");

    const teenPage = expectOk(
      await teen.client.rpc("list_my_message_threads_page", {
        p_query: title,
        p_limit: 1,
      }),
      "list teen message threads",
    );
    assertQa(teenPage.items.length === 1, "teen search did not return its thread");
    const teenThread = teenPage.items[0];
    assertQa(teenThread.id === thread.id, "teen received the wrong thread");
    assertQa(teenThread.job_title === title, "job context did not match");
    assertQa(
      teenThread.counterparty_id === adult.id &&
        teenThread.counterparty_role === "adult",
      "teen did not receive safe adult context",
    );
    assertQa(teenThread.unread_count === 1, "teen unread count did not update");
    assertQa(
      teenThread.last_message_preview ===
        "The staffed public desk is ready for our scheduled check-in.",
      "safe message preview did not match",
    );
    const serializedThread = JSON.stringify(teenThread);
    assertQa(!serializedThread.includes("raw_body"), "raw scanner evidence leaked");
    assertQa(!serializedThread.includes("exact_address"), "exact location leaked");
    qaLog(scope, "hosted teen RPC returns safe searchable thread context");

    const messagePage = expectOk(
      await teen.client.rpc("list_thread_messages_page", {
        p_thread_id: thread.id,
        p_limit: 1,
      }),
      "list thread messages",
    );
    assertQa(
      messagePage.thread?.id === thread.id && messagePage.items.length === 1,
      "hosted message page omitted its authorized summary or message",
    );
    assertQa(
      messagePage.thread.counterparty_id === adult.id,
      "message page returned the wrong counterparty",
    );
    qaLog(scope, "hosted message page includes authorized thread context");

    const adultPage = expectOk(
      await adult.client.rpc("list_my_message_threads_page", {
        p_query: "QA Hosted",
        p_limit: 20,
      }),
      "list adult message threads",
    );
    const adultThread = adultPage.items.find((item) => item.id === thread.id);
    assertQa(
      adultThread?.counterparty_id === teen.id &&
        adultThread?.counterparty_role === "teen",
      "adult did not receive safe teen context",
    );
    qaLog(scope, "hosted adult RPC returns only the opposing participant context");

    const outsiderPage = expectOk(
      await outsider.client.rpc("list_my_message_threads_page", {
        p_query: title,
        p_limit: 20,
      }),
      "list outsider message threads",
    );
    assertQa(outsiderPage.items.length === 0, "outsider discovered another thread");
    const outsiderMessages = await outsider.client.rpc("list_thread_messages_page", {
      p_thread_id: thread.id,
      p_limit: 1,
    });
    assertQa(
      outsiderMessages.error?.message.includes("thread_participant_required"),
      "outsider read another thread through the hosted API",
    );
    qaLog(scope, "hosted API denies non-participant thread access");

    const anonymous = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const anonymousPage = await anonymous.rpc("list_my_message_threads_page", {
      p_limit: 1,
    });
    assertQa(anonymousPage.error, "anonymous caller listed message threads");
    qaLog(scope, "hosted API denies anonymous thread listing");
  },
);
