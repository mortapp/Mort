import type Stripe from "npm:stripe@22.1.1";

export const webhookRoutes = {
  platform: {
    "payment_intent.succeeded": "payment",
    "payment_intent.processing": "payment",
    "payment_intent.requires_action": "payment",
    "payment_intent.payment_failed": "payment",
    "payment_intent.canceled": "payment",
    "charge.dispute.created": "dispute",
    "charge.dispute.updated": "dispute",
    "charge.dispute.closed": "dispute",
    "transfer.created": "transfer",
    "transfer.updated": "transfer",
    "transfer.reversed": "transfer",
    "transfer.canceled": "transfer",
    "refund.created": "refund",
    "refund.updated": "refund",
    "refund.failed": "refund",
    "charge.refunded": "charge",
  },
  connect: {
    "account.updated": "account",
    "payout.created": "payout",
    "payout.updated": "payout",
    "payout.paid": "payout",
    "payout.failed": "payout",
    "payout.canceled": "payout",
  },
} as const;

export type Source = keyof typeof webhookRoutes;
type Kind =
  | "payment"
  | "dispute"
  | "transfer"
  | "refund"
  | "charge"
  | "account"
  | "payout";
type Environment = "live" | "test";
type Observation = Record<string, string | number | null | boolean>;
type Provider = Pick<
  Stripe,
  | "paymentIntents"
  | "charges"
  | "disputes"
  | "transfers"
  | "refunds"
  | "payouts"
  | "v2"
>;

export function targetFor(event: Stripe.Event, source: Source) {
  const routes: Readonly<Record<string, Kind>> = webhookRoutes[source];
  const kind = Object.hasOwn(routes, event.type) ? routes[event.type] : null;
  const id = ref(event.data?.object);
  const prefix = kind && ({
    payment: "pi",
    dispute: "dp",
    transfer: "tr",
    refund: "re",
    charge: "ch",
    account: "acct",
    payout: "po",
  } as const)[kind];
  if (
    !kind || !id || !prefix || !new RegExp(`^${prefix}_[A-Za-z0-9]+$`).test(id)
  ) return null;
  if (
    source === "connect" &&
    (!event.account || !/^acct_[A-Za-z0-9]+$/.test(event.account))
  ) return null;
  if (source === "platform" && event.account) return null;
  if (kind === "account" && id !== event.account) return null;
  return {
    kind,
    id,
    account: event.account ?? null,
    key: `${kind}:${event.account ?? "platform"}:${id}`,
  };
}

export async function observe(
  stripe: Provider,
  target: NonNullable<ReturnType<typeof targetFor>>,
  environment: Environment,
  eventType: string,
): Promise<Observation> {
  const { kind, id, account } = target;
  const base = { kind, id };
  switch (kind) {
    case "payment": {
      const item = await stripe.paymentIntents.retrieve(id);
      validate(item, id, environment);
      if (!ownsPayment(item, environment)) {
        return ignored("payment_intent_not_owned_by_mort");
      }
      const status = ({
        succeeded: "succeeded",
        processing: "processing",
        requires_action: "requires_action",
        requires_payment_method: "payment_failed",
        canceled: "canceled",
        requires_confirmation: null,
        requires_capture: null,
      } as const)[item.status];
      if (
        !status || (status === "payment_failed" && !item.last_payment_error)
      ) {
        return ignored("payment_intent_no_applicable_transition");
      }
      if (status === "succeeded" && item.amount_received !== item.amount) {
        throw new Error("payment_capture_amount_mismatch");
      }
      return {
        ...base,
        state: `payment_intent.${status}`,
        tip: item.metadata.mort_tip_attempt_ref || null,
        amount: item.amount,
        currency: item.currency.toUpperCase(),
        charge: ref(item.latest_charge),
        failure: item.last_payment_error?.code ?? null,
      };
    }
    case "transfer": {
      const item = await stripe.transfers.retrieve(id);
      validate(item, id, environment);
      const metadata = item.metadata ?? {};
      // MORT tip transfers are a separate ledger; do not misclassify them as unrelated money.
      if (metadata.mort_tip_attempt_ref) {
        throw new Error("tip_transfer_reconciliation_required");
      }
      if (!metadata.mort_payment_ref && !metadata.mort_resolution_ref) {
        return ignored("transfer_not_owned_by_mort");
      }
      if (metadata.mort_environment !== environment) {
        throw new Error("transfer_environment_metadata_mismatch");
      }
      const reversed = item.amount_reversed;
      if (
        !Number.isSafeInteger(reversed) || reversed < 0 ||
        reversed > item.amount ||
        item.reversed !== (reversed === item.amount)
      ) throw new Error("inconsistent_transfer_reversal");
      if (eventType === "transfer.canceled" && !item.reversed) {
        throw new Error("transfer_cancellation_requires_verified_reversal");
      }
      return {
        ...base,
        amount: item.amount,
        currency: item.currency.toUpperCase(),
        destination: ref(item.destination),
        reversed,
        state: item.reversed
          ? "reversed"
          : reversed > 0
          ? "partially_reversed"
          : "paid",
      };
    }
    case "payout": {
      if (!account) throw new Error("payout_account_required");
      const item = await stripe.payouts.retrieve(id, {}, {
        stripeAccount: account,
      });
      validate(item, id, environment);
      if (
        !["pending", "in_transit", "paid", "failed", "canceled"].includes(
          item.status,
        )
      ) {
        throw new Error("unknown_payout_status");
      }
      return {
        ...base,
        account,
        state: item.status,
        amount: item.amount,
        currency: item.currency.toUpperCase(),
        arrival: timestamp(item.arrival_date),
        failure: item.failure_code ?? null,
      };
    }
    case "refund": {
      const item = await stripe.refunds.retrieve(id);
      // Refund objects have no livemode field. Their owning PaymentIntent supplies that check.
      if (item.id !== id) throw new Error("provider_object_identity_mismatch");
      const payment = await relatedPayment(
        stripe,
        ref(item.payment_intent),
        ref(item.charge),
        environment,
      );
      if (!payment) return ignored("refund_not_owned_by_mort");
      if (payment.metadata.mort_tip_attempt_ref) {
        throw new Error("tip_refund_reconciliation_required");
      }
      const state = item.status === "requires_action" ? "pending" : item.status;
      if (
        !state ||
        !["pending", "succeeded", "failed", "canceled"].includes(state)
      ) {
        throw new Error("unknown_refund_status");
      }
      return {
        ...base,
        payment: payment.id,
        state,
        amount: item.amount,
        currency: item.currency.toUpperCase(),
        failure: item.failure_reason ?? null,
      };
    }
    case "charge":
      // This summary has no stable list of refund objects. Dedicated refund events are authoritative.
      return {
        kind: "recorded",
        code: "charge_refund_summary_dedicated_events_authoritative",
      };
    case "dispute": {
      const item = await stripe.disputes.retrieve(id);
      validate(item, id, environment);
      const payment = await relatedPayment(
        stripe,
        ref(item.payment_intent),
        ref(item.charge),
        environment,
      );
      if (!payment) return ignored("dispute_not_owned_by_mort");
      if (payment.metadata.mort_tip_attempt_ref) {
        throw new Error("tip_dispute_reconciliation_required");
      }
      const state = ({
        warning_needs_response: "warning_received",
        warning_under_review: "under_review",
        warning_closed: "closed",
        needs_response: "needs_response",
        under_review: "under_review",
        won: "won",
        lost: "lost",
        prevented: "closed",
      } as const)[item.status];
      if (!state) throw new Error("unknown_dispute_status");
      return {
        ...base,
        payment: payment.id,
        state,
        amount: item.amount,
        currency: item.currency.toUpperCase(),
        reason: item.reason,
        evidenceDue: timestamp(item.evidence_details?.due_by),
      };
    }
    case "account": {
      const item = await stripe.v2.core.accounts.retrieve(id, {
        include: ["configuration.recipient", "identity", "requirements", "defaults"],
      });
      if (item.id !== id || item.livemode !== (environment === "live")) {
        throw new Error("provider_account_mismatch");
      }
      const entries = item.requirements?.entries ?? [];
      const statuses = entries.map((entry) => entry.minimum_deadline?.status);
      const requirements = statuses.includes("past_due")
        ? "past_due"
        : statuses.includes("currently_due")
        ? "currently_due"
        : statuses.includes("pending_verification")
        ? "pending_verification"
        : statuses.includes("eventually_due")
        ? "eventually_due"
        : "satisfied";
      const recipient = item.configuration?.recipient?.capabilities?.stripe_balance;
      const transferStatus = recipient?.stripe_transfers?.status ?? "inactive";
      const payoutStatus = recipient?.payouts?.status ?? "inactive";
      const transfers = ["active", "pending", "inactive"].includes(transferStatus)
        ? transferStatus
        : "restricted";
      const payouts = payoutStatus === "active";
      const statusDetails = [
        ...(recipient?.stripe_transfers?.status_details ?? []),
        ...(recipient?.payouts?.status_details ?? []),
      ];
      const disabled = statusDetails.find((detail) => typeof detail.code === "string")?.code ??
        (transfers === "restricted" || payoutStatus === "restricted" || payoutStatus === "rejected"
          ? "recipient_capability_restricted"
          : requirements === "past_due"
          ? "requirements_past_due"
          : null);
      const ready = payouts && transfers === "active" && requirements === "satisfied";
      const guardianRequired = entries.some((entry) =>
        /guardian/i.test(`${entry.requirement ?? ""} ${entry.description ?? ""}`)
      );
      return {
        ...base,
        state: ready
          ? "complete"
          : disabled || requirements === "past_due"
          ? "restricted"
          : requirements === "currently_due"
          ? "action_required"
          : "in_progress",
        submitted: !["currently_due", "past_due"].includes(requirements),
        charges: false,
        payouts,
        transfers,
        requirements,
        guardian: guardianRequired
          ? "provider_managed_required"
          : "provider_managed_unknown",
        disabled,
        country: item.identity?.country?.toUpperCase() ?? null,
        currency: item.defaults?.currency?.toUpperCase() ?? null,
      };
    }
  }
}

function ref(value: unknown): string | null {
  if (typeof value === "string") return value;
  if (
    value && typeof value === "object" && "id" in value &&
    typeof value.id === "string"
  ) return value.id;
  return null;
}

function timestamp(value?: number | null) {
  return value ? new Date(value * 1000).toISOString() : null;
}

function ignored(code: string): Observation {
  return { kind: "ignored", code };
}

function validate(
  item: { id: string; livemode: boolean },
  id: string,
  environment: Environment,
) {
  if (item.id !== id || item.livemode !== (environment === "live")) {
    throw new Error("provider_object_identity_mismatch");
  }
}

function isDeleted(item: object) {
  return "deleted" in item && item.deleted === true;
}

function ownsPayment(item: Stripe.PaymentIntent, environment: Environment) {
  const metadata = item.metadata ?? {};
  return metadata.mort_environment === environment &&
    (!!metadata.mort_tip_attempt_ref ||
      (!!metadata.mort_quote_ref && !!metadata.mort_contract_ref));
}

async function relatedPayment(
  stripe: Provider,
  intentId: string | null,
  chargeId: string | null,
  environment: Environment,
) {
  if (!intentId && chargeId) {
    const charge = await stripe.charges.retrieve(chargeId);
    validate(charge, chargeId, environment);
    intentId = ref(charge.payment_intent);
  }
  if (!intentId) return null;
  const payment = await stripe.paymentIntents.retrieve(intentId);
  validate(payment, intentId, environment);
  return ownsPayment(payment, environment) ? payment : null;
}
