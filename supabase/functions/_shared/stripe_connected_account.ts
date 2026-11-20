export type StripeEnvironment = "test" | "live";

export function deletedConnectedAccountStatusParams(
  providerAccountId: string,
  environment: StripeEnvironment,
) {
  return {
    p_provider_account_id: providerAccountId,
    p_environment: environment,
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
  };
}
