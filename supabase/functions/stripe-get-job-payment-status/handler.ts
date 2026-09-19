export type PaymentStatusContext = {
  userId: string;
  rawContext: unknown;
};

export type PaymentStatusDependencies = {
  authenticate(request: Request): Promise<PaymentStatusContext | null>;
  enforceRateLimit(context: PaymentStatusContext): Promise<void>;
  loadAuthorizedState(
    context: PaymentStatusContext,
    providerPaymentIntentId: string,
  ): Promise<Record<string, unknown> | null>;
  reconcile(
    context: PaymentStatusContext,
    providerPaymentIntentId: string,
  ): Promise<void>;
};

export class PaymentStatusHttpError extends Error {
  constructor(public readonly code: string, public readonly status: number) {
    super(code);
  }
}

const maximumBodyBytes = 32 * 1024;
const paymentIntentPattern = /^pi_[A-Za-z0-9]+$/;
const responseKeys = [
  "state",
  "legacy_status",
  "provider_confirmed_at",
  "last_reconciled_at",
] as const;

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    },
  });
}

async function readPayload(request: Request) {
  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > maximumBodyBytes) {
    throw new PaymentStatusHttpError("payload_too_large", 413);
  }
  const rawBody = await request.text();
  if (new TextEncoder().encode(rawBody).byteLength > maximumBodyBytes) {
    throw new PaymentStatusHttpError("payload_too_large", 413);
  }
  try {
    return (rawBody.trim() ? JSON.parse(rawBody) : {}) as Record<string, unknown>;
  } catch {
    throw new PaymentStatusHttpError("invalid_json", 400);
  }
}

function minimizeStatus(source: Record<string, unknown>) {
  const result: Record<string, unknown> = {};
  for (const key of responseKeys) {
    if (Object.hasOwn(source, key)) result[key] = source[key];
  }
  return result;
}

export function createPaymentStatusHandler(
  dependencies: PaymentStatusDependencies,
) {
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return new Response("ok");
    if (request.method !== "POST") {
      return json({ ok: false, code: "post_required" }, 405);
    }

    try {
      const context = await dependencies.authenticate(request);
      if (!context) {
        throw new PaymentStatusHttpError("authentication_required", 401);
      }
      await dependencies.enforceRateLimit(context);
      const payload = await readPayload(request);
      const providerPaymentIntentId = payload.provider_payment_intent_id;
      if (
        typeof providerPaymentIntentId !== "string" ||
        !paymentIntentPattern.test(providerPaymentIntentId)
      ) {
        throw new PaymentStatusHttpError(
          "invalid_provider_payment_intent_id",
          400,
        );
      }

      const before = await dependencies.loadAuthorizedState(
        context,
        providerPaymentIntentId,
      );
      if (!before) {
        throw new PaymentStatusHttpError("payment_status_not_found", 404);
      }

      await dependencies.reconcile(context, providerPaymentIntentId);

      const after = await dependencies.loadAuthorizedState(
        context,
        providerPaymentIntentId,
      );
      if (!after) {
        throw new PaymentStatusHttpError("payment_status_not_found", 404);
      }

      return json({ ok: true, ...minimizeStatus(after) });
    } catch (error) {
      if (error instanceof PaymentStatusHttpError) {
        return json({ ok: false, code: error.code }, error.status);
      }
      return json({ ok: false, code: "payment_status_failed" }, 500);
    }
  };
}
