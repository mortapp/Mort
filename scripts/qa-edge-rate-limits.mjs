import {
  anonKey,
  assertQa,
  qaLog,
  supabaseUrl,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-edge-rate-limits";

await withQaUsers(
  scope,
  [
    { key: "owner", role: "adult" },
    { key: "outsider", role: "adult" },
  ],
  async ({ owner, outsider }) => {
    const forgedAction = await owner.client.rpc("consume_my_edge_action_limit", {
      p_action: "attacker_chosen_unlimited_action",
    });
    assertQa(
      !forgedAction.error && forgedAction.data === false,
      "An action outside the server allowlist consumed an Edge quota.",
    );

    const concurrent = await Promise.all(
      Array.from({ length: 4 }, () =>
        owner.client.rpc("consume_my_edge_action_limit", {
          p_action: "stripe_connected_account_create",
        })
      ),
    );
    assertQa(
      concurrent.every((result) => !result.error) &&
        concurrent.filter((result) => result.data === true).length === 3 &&
        concurrent.filter((result) => result.data === false).length === 1,
      "Concurrent Edge quota requests did not enforce exactly the server limit.",
    );

    const independent = await outsider.client.rpc(
      "consume_my_edge_action_limit",
      { p_action: "stripe_connected_account_create" },
    );
    assertQa(
      !independent.error && independent.data === true,
      "One user's quota affected an unrelated user's quota.",
    );

    const session = await outsider.client.auth.getSession();
    const token = session.data.session?.access_token;
    assertQa(token, "The Stripe boundary QA session was unavailable.");
    const disabledStripe = await fetch(
      `${supabaseUrl}/functions/v1/stripe-create-connected-account`,
      {
        method: "POST",
        headers: {
          apikey: anonKey,
          authorization: `Bearer ${token}`,
          "content-type": "application/json",
        },
        body: "{}",
      },
    );
    const disabledStripeBody = await disabledStripe.json();
    assertQa(
      disabledStripe.status === 503 &&
        disabledStripeBody?.code === "stripe_disabled",
      "The hosted Stripe function did not pass the quota gate and fail closed at the disabled runtime boundary.",
    );

    const directWrite = await owner.client.from("rate_limit_events").insert({
      user_id: owner.id,
      action: "stripe_connected_account_create",
    });
    assertQa(
      directWrite.error,
      "An authenticated client directly wrote trusted rate-limit state.",
    );
    qaLog(
      scope,
      "server action allowlist, atomic concurrency, isolation, and write ownership passed",
    );
  },
);
