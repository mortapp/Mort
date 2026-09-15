import { assertQa, qaLog, withDatabase, withQaUsers } from "./feature-qa-helpers.mjs";

const scope = "qa-guardian-invite-accept-rate-limit";

await withQaUsers(
  scope,
  [
    { key: "teen", role: "teen" },
    { key: "guardianValid", role: "guardian" },
    { key: "guardianReuse", role: "guardian" },
    { key: "guardianRateLimit", role: "guardian" },
    { key: "guardianExpired", role: "guardian" },
    { key: "guardianTargeted", role: "guardian" },
    { key: "guardianWrong", role: "guardian" },
  ],
  async ({ teen, guardianValid, guardianReuse, guardianRateLimit, guardianExpired, guardianTargeted, guardianWrong }) => {
    // VALID_INVITE_ACCEPT + extensions.digest RESOLUTION: if the digest()
    // call were still unqualified, this call would come back as a raw
    // Postgres error (error != null), not a clean {ok:true} response.
    const invite = await teen.client.rpc("create_guardian_invite_v2", { p_invite_email: null });
    assertQa(!invite.error && invite.data?.ok === true, `fixture: create_guardian_invite_v2 failed: ${invite.error?.message ?? JSON.stringify(invite.data)}`);
    const code = invite.data.invite_code;

    const accepted = await guardianValid.client.rpc("accept_guardian_invite", { p_invite_code: code });
    assertQa(
      !accepted.error && accepted.data?.ok === true && typeof accepted.data?.link_id === "string",
      `VALID_INVITE_ACCEPT: valid invite was not accepted (error=${accepted.error?.message}, data=${JSON.stringify(accepted.data)})`,
    );
    qaLog(scope, "VALID_INVITE_ACCEPT=PASS");
    qaLog(scope, "extensions.digest RESOLUTION=PASS (the hash comparison in the WHERE clause resolved cleanly, not a raw Postgres error)");

    // ALREADY_USED_INVITE_DENIED: the same code, now status='active', must
    // not be acceptable a second time (by anyone).
    const reused = await guardianReuse.client.rpc("accept_guardian_invite", { p_invite_code: code });
    assertQa(
      !reused.error && reused.data?.ok === false && reused.data?.code === "guardian_invite_invalid_or_expired",
      `ALREADY_USED_INVITE_DENIED: an already-accepted invite was not denied (${JSON.stringify(reused.data)})`,
    );
    qaLog(scope, "ALREADY_USED_INVITE_DENIED=PASS");

    // INVALID_INVITE_ATTEMPT_RECORDED + REPEATED_INVALID_INVITES_RATE_LIMITED
    // + RATE_LIMIT_STATE_SURVIVES_FAILURE, all in one loop: the limit is 10
    // per hour (check_rate_limit('guardian_invite_accept', 10, 3600)). Each
    // of the first 10 wrong-code attempts must be denied as
    // invalid_or_expired (proving the attempt was evaluated, not
    // short-circuited), and the 11th must be denied specifically as
    // rate-limited -- which is only possible if every earlier failed
    // attempt's rate-limit event actually persisted (survived) rather than
    // being rolled back by a RAISE EXCEPTION.
    for (let attempt = 1; attempt <= 10; attempt += 1) {
      const wrong = await guardianRateLimit.client.rpc("accept_guardian_invite", {
        p_invite_code: `WRONG${attempt}Z`,
      });
      assertQa(
        !wrong.error && wrong.data?.ok === false && wrong.data?.code === "guardian_invite_invalid_or_expired",
        `INVALID_INVITE_ATTEMPT_RECORDED: attempt ${attempt} was not denied as invalid_or_expired (${JSON.stringify(wrong.data)})`,
      );
    }
    qaLog(scope, "INVALID_INVITE_ATTEMPT_RECORDED=PASS (10/10 wrong-code attempts were each evaluated and denied individually)");

    const eleventh = await guardianRateLimit.client.rpc("accept_guardian_invite", { p_invite_code: "WRONG11Z" });
    assertQa(
      !eleventh.error && eleventh.data?.ok === false && eleventh.data?.code === "guardian_invite_accept_rate_limit_reached",
      `REPEATED_INVALID_INVITES_RATE_LIMITED: the 11th attempt was not rate-limited (${JSON.stringify(eleventh.data)}) -- if this is invalid_or_expired instead, the rate-limit bookkeeping did not survive the earlier failures`,
    );
    qaLog(scope, "REPEATED_INVALID_INVITES_RATE_LIMITED=PASS");
    qaLog(scope, "RATE_LIMIT_STATE_SURVIVES_FAILURE=PASS (all 10 prior failed attempts' rate-limit events persisted through their own RETURN, not RAISE)");

    // EXPIRED_INVITE_DENIED: direct fixture insert (service_role has table
    // INSERT on guardian_connections) with invite_expires_at in the past --
    // there is no RPC to create an already-expired invite.
    const expiredCode = "EXPIRD01";
    await withDatabase(async (database) => {
      await database.query(
        `insert into public.guardian_connections
           (teen_id, status, invite_code, invite_code_hash, invite_expires_at)
         values ($1, 'invited', $2, extensions.digest($2, 'sha256'), now() - interval '1 day')`,
        [teen.id, expiredCode],
      );
    });
    const expiredAttempt = await guardianExpired.client.rpc("accept_guardian_invite", { p_invite_code: expiredCode });
    assertQa(
      !expiredAttempt.error && expiredAttempt.data?.ok === false && expiredAttempt.data?.code === "guardian_invite_invalid_or_expired",
      `EXPIRED_INVITE_DENIED: an expired invite was not denied (${JSON.stringify(expiredAttempt.data)})`,
    );
    qaLog(scope, "EXPIRED_INVITE_DENIED=PASS");

    // WRONG_GUARDIAN_DENIED: invite targeted at guardianTargeted's email;
    // guardianWrong has the correct code but a different email, and must
    // still be denied.
    const targetedCode = "TARGET01";
    await withDatabase(async (database) => {
      await database.query(
        `insert into public.guardian_connections
           (teen_id, status, invite_code, invite_code_hash, invite_expires_at, invited_email)
         values ($1, 'invited', $2, extensions.digest($2, 'sha256'), now() + interval '14 days', lower($3))`,
        [teen.id, targetedCode, guardianTargeted.email],
      );
    });
    const wrongGuardianAttempt = await guardianWrong.client.rpc("accept_guardian_invite", { p_invite_code: targetedCode });
    assertQa(
      !wrongGuardianAttempt.error && wrongGuardianAttempt.data?.ok === false && wrongGuardianAttempt.data?.code === "guardian_invite_invalid_or_expired",
      `WRONG_GUARDIAN_DENIED: a guardian whose email does not match the invite's invited_email was not denied (${JSON.stringify(wrongGuardianAttempt.data)})`,
    );
    const correctGuardianAttempt = await guardianTargeted.client.rpc("accept_guardian_invite", { p_invite_code: targetedCode });
    assertQa(
      !correctGuardianAttempt.error && correctGuardianAttempt.data?.ok === true,
      `WRONG_GUARDIAN_DENIED: the correctly-targeted guardian was unexpectedly denied too (${JSON.stringify(correctGuardianAttempt.data)})`,
    );
    qaLog(scope, "WRONG_GUARDIAN_DENIED=PASS (mismatched email denied; correctly-targeted guardian still succeeds)");
  },
);

qaLog(scope, "accept_guardian_invite rate-limit fix verified end-to-end with synthetic QA fixtures only");
