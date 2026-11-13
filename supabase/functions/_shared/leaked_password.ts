export async function sha1Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-1",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("")
    .toUpperCase();
}

export function parseHibpRangeResponse(
  body: string,
  expectedSuffix: string,
): { valid: boolean; leaked: boolean } {
  if (!/^[0-9A-F]{35}$/i.test(expectedSuffix)) {
    return { valid: false, leaked: false };
  }

  let leaked = false;
  for (const rawLine of body.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line) continue;
    const [candidateSuffix, count, ...extra] = line.split(":");
    if (
      extra.length !== 0 ||
      !/^[0-9A-F]{35}$/i.test(candidateSuffix ?? "") ||
      !/^\d+$/.test(count ?? "")
    ) {
      return { valid: false, leaked: false };
    }
    if (
      candidateSuffix.toUpperCase() === expectedSuffix.toUpperCase() &&
      Number(count) > 0
    ) {
      leaked = true;
    }
  }

  return { valid: true, leaked };
}
