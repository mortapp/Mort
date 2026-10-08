export class InvalidInput extends Error {
  constructor() {
    super("That request is not valid.");
  }
}
const bad = (): never => {
  throw new InvalidInput();
};
type ObjectValue = Record<string, unknown>;
function object(value: unknown): ObjectValue {
  if (!value || typeof value !== "object" || Array.isArray(value)) return bad();
  return value as ObjectValue;
}
/** Bounded JSON grammar walk rejects duplicate keys before native deserialization.
 * String tokens use JSON.parse to apply escape/unicode semantics, so escaped key
 * aliases cannot evade duplicate detection. No regular-expression JSON parsing.
 */
export function parseJson(raw: Uint8Array): ObjectValue {
  if (raw.byteLength === 0 || raw.byteLength > 16_384) return bad();
  let text: string;
  try {
    text = new TextDecoder("utf-8", { fatal: true }).decode(raw);
  } catch {
    return bad();
  }
  let pos = 0;
  const ws = () => {
    while (/[\t\n\r ]/.test(text[pos] ?? "\u0000")) pos++;
  };
  const string = (): string => {
    const start = pos++;
    if (text[start] !== '"') return bad();
    while (pos < text.length) {
      const c = text[pos++];
      if (c === "\\") {
        pos++;
        continue;
      }
      if (c === '"') {
        try {
          return JSON.parse(text.slice(start, pos));
        } catch {
          return bad();
        }
      }
    }
    return bad();
  };
  const value = (depth: number): void => {
    if (depth > 16) return bad();
    ws();
    const c = text[pos];
    if (c === '"') {
      string();
      return;
    }
    if (c === "{") {
      pos++;
      ws();
      const keys = new Set<string>();
      if (text[pos] === "}") {
        pos++;
        return;
      }
      for (;;) {
        ws();
        if (text[pos] !== '"') return bad();
        const key = string();
        if (
          keys.has(key) ||
          ["__proto__", "constructor", "prototype"].includes(key)
        ) return bad();
        keys.add(key);
        ws();
        if (text[pos++] !== ":") return bad();
        value(depth + 1);
        ws();
        const end = text[pos++];
        if (end === "}") return;
        if (end !== ",") return bad();
      }
    }
    if (c === "[") {
      pos++;
      ws();
      if (text[pos] === "]") {
        pos++;
        return;
      }
      for (;;) {
        value(depth + 1);
        ws();
        const end = text[pos++];
        if (end === "]") return;
        if (end !== ",") return bad();
      }
    }
    const token =
      /^(?:true|false|null|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)/.exec(
        text.slice(pos),
      );
    if (!token) return bad();
    pos += token[0].length;
  };
  value(0);
  ws();
  if (pos !== text.length) return bad();
  try {
    return object(JSON.parse(text));
  } catch {
    return bad();
  }
}
export const canonicalId = (value: unknown): string => {
  if (
    typeof value !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
      .test(value)
  ) return bad();
  return value;
};
export function canonicalSecret(value: unknown): string {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{43}$/.test(value)) {
    return bad();
  }
  try {
    const raw = atob(value.replaceAll("-", "+").replaceAll("_", "/") + "=");
    if (
      raw.length !== 32 ||
      btoa(raw).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "") !==
        value
    ) return bad();
  } catch {
    return bad();
  }
  return value;
}
function allow(input: ObjectValue, keys: string[]): void {
  if (Object.keys(input).some((key) => !keys.includes(key))) bad();
}
function digest(value: unknown): string {
  if (typeof value !== "string" || !/^[0-9a-f]{64}$/.test(value)) return bad();
  return value;
}
export type ContinueInput = {
  itemId: string;
  kind: "code" | "link";
  credential: string;
  verifierHash: string;
};
export function parseContinue(raw: Uint8Array): ContinueInput {
  const input = parseJson(raw);
  allow(input, ["itemId", "code", "linkSecret", "verifierHash"]);
  const itemId = canonicalId(input.itemId),
    verifierHash = digest(input.verifierHash);
  if (("code" in input) === ("linkSecret" in input)) return bad();
  if ("code" in input) {
    if (typeof input.code !== "string" || !/^\d{8}$/.test(input.code)) {
      return bad();
    }
    return { itemId, kind: "code", credential: input.code, verifierHash };
  }
  return {
    itemId,
    kind: "link",
    credential: canonicalSecret(input.linkSecret),
    verifierHash,
  };
}
export function validPassword(value: unknown): value is string {
  return typeof value === "string" && value.length >= 12 &&
    value.length <= 128 && /[A-Z]/.test(value) && /[a-z]/.test(value) &&
    /[0-9]/.test(value) && /[^A-Za-z0-9]/.test(value);
}
export type PasswordInput = {
  capability: string;
  verifier: string;
  password: string;
};
export function parsePassword(raw: Uint8Array): PasswordInput {
  const input = parseJson(raw);
  allow(input, ["capability", "verifier", "password"]);
  if (!validPassword(input.password)) return bad();
  return {
    capability: canonicalSecret(input.capability),
    verifier: canonicalSecret(input.verifier),
    password: input.password,
  };
}
export function validateMailbox(value: unknown): string {
  if (
    typeof value !== "string" || value.length > 254 || value.length === 0 ||
    !/^[\x21-\x7e]+$/.test(value)
  ) return bad();
  const parts = value.split("@");
  if (parts.length !== 2) return bad();
  const [local, domain] = parts;
  if (
    local.length > 64 || !local || local.startsWith(".") ||
    local.endsWith(".") || local.includes("..") ||
    !/^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+$/.test(local)
  ) return bad();
  if (
    domain.length > 253 || !domain.includes(".") ||
    !domain.split(".").every((label) =>
      /^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$/.test(label)
    )
  ) return bad();
  return value;
}
export type BoundEvent = {
  accountId: string;
  recipient: string;
  purpose: "confirmation" | "recovery";
};
export function parseHook(raw: Uint8Array): BoundEvent {
  const input = parseJson(raw);
  allow(input, ["user", "email_data"]);
  const user = object(input.user), data = object(input.email_data);
  const accountId = canonicalId(user.id),
    recipient = validateMailbox(user.email);
  if (
    data.email_action_type !== "signup" && data.email_action_type !== "recovery"
  ) return bad();
  // Provider tokens and caller-controlled metadata deliberately do not escape.
  return {
    accountId,
    recipient,
    purpose: data.email_action_type === "signup" ? "confirmation" : "recovery",
  };
}
