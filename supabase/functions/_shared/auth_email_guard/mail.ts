import {
  canonicalId,
  canonicalSecret,
  parseJson,
  validateMailbox,
} from "./parser.ts";
export type EnvelopeContext = {
  itemId: string;
  accountId: string;
  purpose: string;
  recipientHash: string;
  sourceHash: string;
  addressGeneration: number;
  credentialGeneration: number;
  activationGeneration: number;
  restoreGeneration: number;
};
export function envelopeBinding(context: EnvelopeContext): string {
  canonicalId(context.itemId);
  canonicalId(context.accountId);
  const values = [
    context.addressGeneration,
    context.credentialGeneration,
    context.activationGeneration,
    context.restoreGeneration,
  ];
  if (
    !["confirmation", "recovery"].includes(context.purpose) ||
    !/^[0-9a-f]{64}$/.test(context.recipientHash) ||
    !/^[0-9a-f]{64}$/.test(context.sourceHash) ||
    !values.every((x) => Number.isSafeInteger(x) && x > 0)
  ) throw new Error("Envelope unavailable");
  return JSON.stringify([
    "mort-email-envelope-v1",
    context.itemId,
    context.accountId,
    context.purpose,
    context.recipientHash,
    context.sourceHash,
    ...values,
  ]);
}
export type Envelope = { recipient: string; code: string; linkSecret: string };
export function parseEnvelope(bytes: Uint8Array): Envelope {
  const value = parseJson(bytes);
  if (
    Object.keys(value).some((x) =>
      !["recipient", "code", "linkSecret"].includes(x)
    ) || typeof value.code !== "string" || !/^\d{8}$/.test(value.code)
  ) throw new Error("Envelope unavailable");
  return {
    recipient: validateMailbox(value.recipient),
    code: value.code,
    linkSecret: canonicalSecret(value.linkSecret),
  };
}
export function fixedMail(
  envelope: Envelope,
  lease: EnvelopeContext & { familyExpiresAt: string },
) {
  envelopeBinding(lease);
  validateMailbox(envelope.recipient);
  canonicalSecret(envelope.linkSecret);
  if (!/^\d{8}$/.test(envelope.code)) throw new Error("Envelope unavailable");
  const expires = new Date(lease.familyExpiresAt);
  if (!Number.isFinite(expires.getTime())) {
    throw new Error("Envelope unavailable");
  }
  const route = lease.purpose === "confirmation" ? "confirmation" : "recovery";
  const link =
    `https://mortapp.org/auth/${route}/#itemId=${lease.itemId}&linkSecret=${envelope.linkSecret}`;
  return {
    recipient: envelope.recipient,
    subject: lease.purpose === "confirmation"
      ? "Confirm your MORT email"
      : "Reset your MORT password",
    text:
      `MORT Accounts\n\nContinue using the link below. MORT never emails your password.\n\n${link}\n\nYour eight-digit code: ${envelope.code}\nExpires at ${expires.toISOString()} (UTC).\n\n${
        lease.purpose === "confirmation"
          ? "You will choose a replacement password for your account."
          : "You will choose a new password, then return to normal sign-in."
      }\nIf you did not request this email, you can ignore it.`,
  };
}
