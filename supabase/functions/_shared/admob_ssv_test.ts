import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { verifyAdMobCallback } from "./admob_ssv.ts";

const userId = "716677ec-d9cf-4d71-9ef6-491ce5d47fe9";
const transactionId = "18fa792de1bca816048293fc71035638";
const allowedAdUnit = "ca-app-pub-1234567890123456/2747237135";

function derInteger(raw: Uint8Array): Uint8Array {
  let first = 0;
  while (first < raw.length - 1 && raw[first] === 0) first++;
  const value = raw.subarray(first);
  const leadingZero = (value[0] & 0x80) !== 0 ? 1 : 0;
  return new Uint8Array([0x02, value.length + leadingZero, ...(
    leadingZero ? [0] : []
  ), ...value]);
}

function rawToDer(raw: Uint8Array): Uint8Array {
  const r = derInteger(raw.subarray(0, 32));
  const s = derInteger(raw.subarray(32, 64));
  return new Uint8Array([0x30, r.length + s.length, ...r, ...s]);
}

async function signedQuery(content: string, privateKey: CryptoKey): Promise<string> {
  const raw = new Uint8Array(await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    privateKey,
    new TextEncoder().encode(content),
  ));
  const signature = btoa(String.fromCharCode(...rawToDer(raw)))
    .replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
  return `${content}&signature=${signature}&key_id=42`;
}

Deno.test("AdMob SSV accepts signed reward and rejects tampering", async () => {
  const pair = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"],
  );
  const now = Date.now();
  const content = new URLSearchParams({
    ad_unit: "2747237135",
    custom_data: "mort_spark",
    reward_amount: "1",
    reward_item: "Spark",
    timestamp: String(now),
    transaction_id: transactionId,
    user_id: userId,
  }).toString();
  const keys = new Map([["42", pair.publicKey]]);
  const query = await signedQuery(content, pair.privateKey);
  const result = await verifyAdMobCallback(query, [allowedAdUnit], keys, now);
  assertEquals(result.userId, userId);
  assertEquals(result.transactionId, transactionId);
  await assertRejects(() => verifyAdMobCallback(
    query.replace("mort_spark", "mort_bonus"), [allowedAdUnit], keys, now,
  ));
  await assertRejects(() => verifyAdMobCallback(query, [], keys, now));
  await assertRejects(() => verifyAdMobCallback(query, [allowedAdUnit], new Map(), now));
  const duplicate = await signedQuery(`${content}&user_id=${userId}`, pair.privateKey);
  await assertRejects(() => verifyAdMobCallback(duplicate, [allowedAdUnit], keys, now));
  const expired = await signedQuery(
    content.replace(String(now), String(now - 25 * 60 * 60 * 1000)),
    pair.privateKey,
  );
  await assertRejects(() => verifyAdMobCallback(expired, [allowedAdUnit], keys, now));
});
