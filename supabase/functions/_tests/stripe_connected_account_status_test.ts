import { assertEquals } from "jsr:@std/assert@1";
import { deletedConnectedAccountStatusParams } from "../_shared/stripe_connected_account.ts";

Deno.test("deleted Connect accounts are persisted as disconnected and ineligible", () => {
  assertEquals(deletedConnectedAccountStatusParams("acct_test_123", "test"), {
    p_provider_account_id: "acct_test_123",
    p_environment: "test",
    p_onboarding_status: "disconnected",
    p_details_submitted: false,
    p_charges_enabled: false,
    p_payouts_enabled: false,
    p_transfers_capability_status: "inactive",
    p_requirements_status: "restricted",
    p_guardian_requirement_status: "provider_managed_restricted",
    p_disabled_reason_code: "account_deleted",
    p_country: null,
    p_default_currency: null,
  });
});
