import { busy, publicFailure, safeEvent } from "./redaction.ts";
Deno.test("response and log shapes cannot carry supplied secrets", () => {
  const sensitive = crypto.randomUUID();
  const result = safeEvent(sensitive, "denied");
  if (
    JSON.stringify(result).includes(sensitive) ||
    Object.keys(result).join(",") !== "event,outcome"
  ) throw new Error("Unsafe event output");
  if (
    publicFailure().message !== "That request is not valid." ||
    busy().retryAfterSeconds !== 1
  ) throw new Error("Public response contract");
  let rejected = false;
  try {
    safeEvent("secret", "password");
  } catch {
    rejected = true;
  }
  if (!rejected) throw new Error("Unsafe event label accepted");
});
