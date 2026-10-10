import nodemailer from "nodemailer";
import { Socket } from "node:net";
import { smtpDiagnostic } from "./smtp-diagnostic.ts";
import { secretDigest } from "./crypto.ts";
import { decryptEnvelope } from "./outbox.ts";
import {
  envelopeBinding,
  type EnvelopeContext,
  fixedMail,
  parseEnvelope,
} from "./mail.ts";
export type DeliveryLease = EnvelopeContext & {
  ok: true;
  attemptId: string;
  generation: number;
  encryptedEnvelope: string;
  familyExpiresAt: string;
  leaseExpiresAt: string;
};
export type DeliveryOutcome = "acknowledged" | "failed" | "ambiguous";
export type FixedMail = ReturnType<typeof fixedMail>;
export type FixtureSmtp = {
  mode: "local_fixture";
  host: "127.0.0.1";
  port: 55425;
  ca: string;
  user: "fixture";
  password: string;
  diagnostic?: (category: string) => void;
};
export async function sendFixedEmail(
  message: FixedMail,
  lease: DeliveryLease,
  config: FixtureSmtp,
): Promise<DeliveryOutcome> {
  if (
    !config || config.mode !== "local_fixture" || config.host !== "127.0.0.1" ||
    config.port !== 55425 || config.user !== "fixture" ||
    typeof config.ca !== "string" || !config.ca.includes("BEGIN CERTIFICATE") ||
    typeof config.password !== "string" || config.password.length === 0
  ) return "failed";
  const remaining = Math.min(
    5000,
    new Date(lease.leaseExpiresAt).getTime() - Date.now() - 250,
  );
  if (!Number.isFinite(remaining) || remaining <= 0) return "failed";
  let socket: Socket | undefined;
  const transport = nodemailer.createTransport({
    getSocket: (
      _options: unknown,
      callback: (error: Error | null, options?: { connection: Socket }) => void,
    ) => {
      socket = new Socket();
      let completed = false;
      const complete = (error: Error | null) => {
        if (!completed) {
          completed = true;
          callback(error, error ? undefined : { connection: socket! });
        }
      };
      socket.once("connect", () => complete(null));
      socket.once("error", () => complete(new Error("MORT SMTP unavailable")));
      socket.connect(config.port, config.host);
    },
    host: config.host,
    port: config.port,
    secure: false,
    requireTLS: true,
    auth: { user: config.user, pass: config.password },
    tls: { ca: config.ca, servername: "localhost", rejectUnauthorized: true },
    connectionTimeout: Math.min(2000, remaining),
    greetingTimeout: Math.min(2000, remaining),
    socketTimeout: Math.min(5000, remaining),
    logger: false,
    debug: false,
    disableFileAccess: true,
    disableUrlAccess: true,
  });
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    const timeout = new Promise<DeliveryOutcome>((resolve) => {
      timer = setTimeout(() => {
        socket?.destroy();
        transport.close();
        resolve("ambiguous");
      }, remaining);
    });
    const delivered = (async () => {
      try {
        const result = await transport.sendMail({
          from: { name: "MORT Accounts", address: "auth@mortapp.org" },
          to: { address: message.recipient },
          envelope: { from: "auth@mortapp.org", to: [message.recipient] },
          replyTo: "support@mortapp.org",
          subject: message.subject,
          text: message.text,
        });
        return result.accepted?.length === 1 &&
            result.accepted[0] === message.recipient &&
            result.rejected?.length === 0
          ? "acknowledged" as const
          : "failed" as const;
      } catch (error) {
        config.diagnostic?.(smtpDiagnostic(error));
        return ["EAUTH", "EENVELOPE"].includes(
            (error as { code?: string }).code ?? "",
          )
          ? "failed" as const
          : "ambiguous" as const;
      }
    })();
    return await Promise.race([delivered, timeout]);
  } finally {
    if (timer !== undefined) clearTimeout(timer);
    socket?.destroy();
    transport.close();
  }
}
export type WorkerDeps = {
  mode: "disabled" | "local_fixture";
  key: CryptoKey;
  store: {
    claim(): Promise<DeliveryLease | { ok: false }>;
    beginDispatch(lease: DeliveryLease): Promise<{ ok: boolean }>;
    finish(lease: DeliveryLease, outcome: DeliveryOutcome): Promise<boolean>;
  };
  send(message: FixedMail, lease: DeliveryLease): Promise<DeliveryOutcome>;
};
export async function runDeliveryBatch(
  deps: WorkerDeps,
): Promise<{ claimed: number; acknowledged: number }> {
  if (deps.mode !== "local_fixture") return { claimed: 0, acknowledged: 0 };
  let claimed = 0, acknowledged = 0;
  const work = async () => {
    const lease = await deps.store.claim();
    if (!lease.ok) return;
    claimed++;
    let outcome: DeliveryOutcome = "failed";
    try {
      const envelope = parseEnvelope(
        await decryptEnvelope(
          lease.encryptedEnvelope,
          envelopeBinding(lease),
          deps.key,
        ),
      );
      if (await secretDigest(envelope.recipient) !== lease.recipientHash) {
        throw new Error("Envelope unavailable");
      }
      const message = fixedMail(envelope, lease);
      if (!(await deps.store.beginDispatch(lease)).ok) {
        await deps.store.finish(lease, "failed");
        return;
      }
      try {
        outcome = await deps.send(message, lease);
      } catch {
        outcome = "ambiguous";
      }
    } catch {
      outcome = "failed";
    }
    if (await deps.store.finish(lease, outcome)) acknowledged++;
  };
  await Promise.all([work(), work()]);
  return { claimed, acknowledged };
}
